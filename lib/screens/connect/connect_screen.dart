import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/widgets/ble_status_pill.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/ble_provider.dart';
import '../../core/constants/ble_constants.dart';

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> with SingleTickerProviderStateMixin {
  bool _permissionGranted = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    bool granted = statuses.values.every((s) => s.isGranted);
    
    if (mounted) {
      setState(() {
        _permissionGranted = granted;
      });

      if (!granted) {
        _showPermissionSheet();
      }
    }
  }

  void _showPermissionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bluetooth_disabled, color: AppColors.textHint, size: 48),
              const SizedBox(height: 16),
              const Text("Bluetooth Required", style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("The app needs Bluetooth permissions to find and connect to your smartwatch.", style: TextStyle(color: AppColors.textSecond), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentPurple),
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text("Open Settings", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        );
      }
    );
  }

  Future<void> _startScan() async {
    if (!_permissionGranted) {
      _checkPermissions();
      return;
    }
    
    try {
      ref.read(bleConnectionStateProvider.notifier).state = BleConnectionState.scanning;
      final service = ref.read(bleServiceProvider);
      await service.startScan();
    } catch (e) {
      ref.read(bleConnectionStateProvider.notifier).state = BleConnectionState.disconnected;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: AppColors.accentRed)
        );
      }
      return;
    }
    
    // APP-003: Automatically reset state if not connected after timeout
    Future.delayed(const Duration(seconds: 11), () {
      if (mounted && ref.read(bleConnectionStateProvider) == BleConnectionState.scanning) {
        ref.read(bleConnectionStateProvider.notifier).state = BleConnectionState.disconnected;
      }
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    final service = ref.read(bleServiceProvider);
    bool success = await service.connectToDevice(device);
    
    if (success && mounted) {
      // Save for Auto-Connect
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_device_id', device.remoteId.str);
      
      ref.read(bleConnectionStateProvider.notifier).state = BleConnectionState.connected;
      // Auto-navigate to Home
      ref.read(bottomNavIndexProvider.notifier).state = 0; 
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection failed. Try again."), backgroundColor: AppColors.accentRed)
      );
    }
  }

  Future<void> _disconnect() async {
    final service = ref.read(bleServiceProvider);
    await service.disconnect();
    
    // Clear last device on manual disconnect
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_device_id');
    
    ref.read(bleConnectionStateProvider.notifier).state = BleConnectionState.disconnected;
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(bleConnectionStateProvider);
    final scanResultsAsync = ref.watch(bleScanResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Watch'),
        actions: const [BleStatusPill()],
      ),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            
            // Watch Illustration with Animating Ring
            Stack(
              alignment: Alignment.center,
              children: [
                if (connectionState == BleConnectionState.scanning)
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accentAmber.withAlpha(80), width: 4),
                      ),
                    ),
                  ),
                  
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: connectionState == BleConnectionState.connected 
                        ? AppColors.accentTeal.withAlpha(50) 
                        : AppColors.bgSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.watch, 
                    size: 48, 
                    color: connectionState == BleConnectionState.connected 
                        ? AppColors.accentTeal 
                        : AppColors.textHint,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Status Text
            Text(
              connectionState == BleConnectionState.connected 
                ? "Connected to ESP32Watch" 
                : connectionState == BleConnectionState.scanning 
                  ? "Looking for watch..." 
                  : "Not found",
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            
            // Action Button
            if (connectionState == BleConnectionState.connected)
              ElevatedButton.icon(
                onPressed: _disconnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bgSurface,
                  foregroundColor: AppColors.accentRed,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: const BorderSide(color: AppColors.accentRed),
                ),
                icon: const Icon(Icons.bluetooth_disabled),
                label: const Text("Disconnect"),
              )
            else
              ElevatedButton.icon(
                onPressed: connectionState == BleConnectionState.scanning ? null : _startScan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: connectionState == BleConnectionState.scanning 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search),
                label: Text(connectionState == BleConnectionState.scanning ? "Scanning..." : "Scan"),
              ),
              
            const SizedBox(height: 40),
            
            // Scan Results List
            if (connectionState != BleConnectionState.connected)
              Expanded(
                child: scanResultsAsync.when(
                  data: (results) {
                    if (results.isEmpty && connectionState != BleConnectionState.scanning) {
                      return const Center(child: Text("No devices found", style: TextStyle(color: AppColors.textHint)));
                    }
                    return ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final result = results[index];
                        String name = result.device.advName;
                        if (name.isEmpty) name = result.device.platformName;
                        if (name.isEmpty) name = "Unknown Device";
                        
                        final bool isSmartwatch = name == BleConstants.deviceName;
                        
                        return ListTile(
                          leading: Icon(
                            isSmartwatch ? Icons.watch : Icons.bluetooth, 
                            color: isSmartwatch ? AppColors.accentTeal : AppColors.accentPurple,
                          ),
                          title: Row(
                            children: [
                              Text(name, style: const TextStyle(color: AppColors.textPrimary)),
                              if (isSmartwatch) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_back, color: AppColors.accentTeal, size: 16),
                                const Text(" It's me!", style: TextStyle(color: AppColors.accentTeal, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ],
                          ),
                          subtitle: Text(result.device.remoteId.str, style: const TextStyle(color: AppColors.textSecond, fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${result.rssi} dBm', style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.bgSurface,
                                  foregroundColor: isSmartwatch ? AppColors.accentTeal : AppColors.textSecond,
                                ),
                                onPressed: () => _connect(result.device),
                                child: const Text("Connect"),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
