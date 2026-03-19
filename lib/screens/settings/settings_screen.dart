import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/ble_constants.dart';
import '../../providers/ble_provider.dart';
import '../../services/wallpaper_service.dart';

final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _stepGoalController = TextEditingController();

  Future<void> _updatePrefBool(String key, bool val) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, val);
  }
  
  Future<void> _updatePrefInt(String key, int val) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(key, val);
  }

  Future<void> _updatePrefDouble(String key, double val) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(key, val);
  }

  void _confirmReboot() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('Reboot Watch?', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to restart the ESP32Watch?', style: TextStyle(color: AppColors.textSecond)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textHint)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(bleServiceProvider).sendCommand(BleConstants.cmdRebootWatch);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reboot command sent'), backgroundColor: AppColors.accentRed));
            },
            child: const Text('Reboot', style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );
  }

  void _confirmClearPresets() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('Clear Presets?', style: TextStyle(color: Colors.white)),
        content: const Text('Remove all saved wallpaper presets?', style: TextStyle(color: AppColors.textSecond)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textHint)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed),
            onPressed: () async {
              Navigator.pop(ctx);
              await WallpaperService.clearPresets();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Presets cleared'), backgroundColor: AppColors.accentTeal));
            },
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(sharedPrefsProvider);
    final connectionState = ref.watch(bleConnectionStateProvider);
    final isConnected = connectionState == BleConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: prefsAsync.when(
        data: (prefs) {
          bool autoSync = prefs.getBool('auto_sync_time') ?? true;
          int stepGoal = prefs.getInt('step_goal') ?? 10000;
          double bleTimeout = prefs.getDouble('ble_timeout') ?? 10.0;
          bool defaultDither = prefs.getBool('default_dither') ?? false;

          _stepGoalController.text = stepGoal.toString();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // DEVICE
              const Text("DEVICE", style: TextStyle(color: AppColors.accentPurple, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              _buildCard([
                const ListTile(
                  title: Text("Device Name", style: TextStyle(color: Colors.white)),
                  trailing: Text("ESP32Watch", style: TextStyle(color: AppColors.textSecond)),
                ),
                if (isConnected) const Divider(color: AppColors.bgPrimary, height: 1),
                if (isConnected) const ListTile(
                  title: Text("Firmware", style: TextStyle(color: Colors.white)),
                  trailing: Text("v2.1", style: TextStyle(color: AppColors.textSecond)),
                ),
                const Divider(color: AppColors.bgPrimary, height: 1),
                ListTile(
                  title: const Text("Reboot Watch", style: TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.power_settings_new, color: AppColors.accentRed),
                  onTap: isConnected ? _confirmReboot : null,
                  enabled: isConnected,
                ),
                if (isConnected) const Divider(color: AppColors.bgPrimary, height: 1),
                if (isConnected) ListTile(
                  title: const Text("Disconnect", style: TextStyle(color: AppColors.accentAmber, fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.bluetooth_disabled, color: AppColors.accentAmber),
                  onTap: () async {
                    await ref.read(bleServiceProvider).disconnect();
                    ref.read(bleConnectionStateProvider.notifier).state = BleConnectionState.disconnected;
                  },
                ),
              ]),

              const SizedBox(height: 24),
              // PREFERENCES
              const Text("PREFERENCES", style: TextStyle(color: AppColors.accentPurple, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              _buildCard([
                SwitchListTile(
                  title: const Text("Auto time sync on connect", style: TextStyle(color: Colors.white)),
                  activeTrackColor: AppColors.accentPurple,
                  value: autoSync,
                  onChanged: (val) {
                    _updatePrefBool('auto_sync_time', val);
                    ref.invalidate(sharedPrefsProvider);
                  },
                ),
                const Divider(color: AppColors.bgPrimary, height: 1),
                ListTile(
                  title: const Text("Step Goal", style: TextStyle(color: Colors.white)),
                  trailing: SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _stepGoalController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.end,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: "10000",
                        hintStyle: TextStyle(color: AppColors.textHint),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (val) {
                        int? g = int.tryParse(val);
                        if (g != null && g > 0) {
                          _updatePrefInt('step_goal', g);
                          ref.invalidate(sharedPrefsProvider);
                        }
                      },
                    ),
                  ),
                ),
                const Divider(color: AppColors.bgPrimary, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("BLE Timeout", style: TextStyle(color: Colors.white, fontSize: 16)),
                          Text("${bleTimeout.toInt()}s", style: const TextStyle(color: AppColors.textSecond)),
                        ],
                      ),
                      Slider(
                        value: bleTimeout,
                        min: 5,
                        max: 30,
                        divisions: 25,
                        activeColor: AppColors.accentPurple,
                        onChanged: (val) { 
                           _updatePrefDouble('ble_timeout', val);
                           ref.invalidate(sharedPrefsProvider);
                        },
                      )
                    ],
                  ),
                ),
              ]),

              const SizedBox(height: 24),
              // WALLPAPER
              const Text("WALLPAPER", style: TextStyle(color: AppColors.accentPurple, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              _buildCard([
                SwitchListTile(
                  title: const Text("Default Dither", style: TextStyle(color: Colors.white)),
                  activeTrackColor: AppColors.accentPurple,
                  value: defaultDither,
                  onChanged: (val) {
                    _updatePrefBool('default_dither', val);
                    ref.invalidate(sharedPrefsProvider);
                  },
                ),
                const Divider(color: AppColors.bgPrimary, height: 1),
                ListTile(
                  title: const Text("Clear Presets", style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.delete_outline, color: AppColors.textSecond),
                  onTap: _confirmClearPresets,
                ),
              ]),

              const SizedBox(height: 24),
              // ABOUT
              const Text("ABOUT", style: TextStyle(color: AppColors.accentPurple, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              _buildCard([
                const ListTile(
                  title: Text("App Version", style: TextStyle(color: Colors.white)),
                  trailing: Text("1.0.0", style: TextStyle(color: AppColors.textSecond)),
                ),
                const Divider(color: AppColors.bgPrimary, height: 1),
                const ListTile(
                  title: Text("Target", style: TextStyle(color: Colors.white)),
                  trailing: Text("Compatible with Firmware FSD v2.1", style: TextStyle(color: AppColors.textSecond, fontSize: 12)),
                ),
              ]),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => const Center(child: Text("Error loading settings", style: TextStyle(color: Colors.white))),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16)
      ),
      child: Column(
        children: children,
      ),
    );
  }
}
