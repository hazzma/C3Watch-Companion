import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ble_service.dart';

enum BleConnectionState {
  disconnected,
  scanning,
  connected,
}

final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

final bleConnectionStateProvider = StateProvider<BleConnectionState>((ref) {
  return BleConnectionState.disconnected;
});

final bleServiceProvider = Provider<BleService>((ref) {
  final service = BleService();
  
  // Listen to adapter state for safety
  FlutterBluePlus.adapterState.listen((state) {
    if (state == BluetoothAdapterState.off) {
      ref.read(bleConnectionStateProvider.notifier).state = BleConnectionState.disconnected;
    }
  });

  // Background Auto-Connect Handler
  _initAutoConnect(ref, service);

  return service;
});

Future<void> _initAutoConnect(Ref ref, BleService service) async {
  final prefs = await SharedPreferences.getInstance();
  final lastId = prefs.getString('last_device_id');
  
  if (lastId != null) {
    // Start background scan to see if device is around
    if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on) {
       FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
       FlutterBluePlus.scanResults.listen((results) async {
         for (var r in results) {
           if (r.device.remoteId.str == lastId && ref.read(bleConnectionStateProvider) == BleConnectionState.disconnected) {
             FlutterBluePlus.stopScan();
             bool success = await service.connectToDevice(r.device);
             if (success) {
               ref.read(bleConnectionStateProvider.notifier).state = BleConnectionState.connected;
             }
           }
         }
       });
    }
  }
}

final bleScanResultsProvider = StreamProvider<List<ScanResult>>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.scanResults;
});
