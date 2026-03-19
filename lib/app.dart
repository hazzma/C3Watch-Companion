import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'screens/home/home_screen.dart';
import 'screens/wallpaper/wallpaper_screen.dart';
import 'screens/connect/connect_screen.dart';
import 'screens/data/data_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'providers/ble_provider.dart';
import 'providers/watch_data_provider.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen for connection to auto-sync time
    ref.listen<BleConnectionState>(bleConnectionStateProvider, (prev, next) async {
      if (next == BleConnectionState.connected && prev != BleConnectionState.connected) {
        bool success = await ref.read(timeSyncProvider).syncTime();
        if (success) {
          scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('Time synced'),
              backgroundColor: Color(0xFF1D9E75),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });

    final currentIndex = ref.watch(bottomNavIndexProvider);
    final notifier = ref.read(bottomNavIndexProvider.notifier);

    final List<Widget> screens = const [
      HomeScreen(),
      WallpaperScreen(),
      ConnectScreen(),
      DataScreen(),
      SettingsScreen(),
    ];

    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'ESP32-C3 Smartwatch',
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: screens[currentIndex],

        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) => notifier.state = index,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.wallpaper),
              label: 'Wallpaper',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bluetooth_connected),
              label: 'Connect',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Data',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
