import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart';

enum BleConnectionState {
  disconnected,
  scanning,
  connected,
}

// Global bottom nav access to return to Home dynamically
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

final bleConnectionStateProvider = StateProvider<BleConnectionState>((ref) {
  return BleConnectionState.disconnected;
});

final bleServiceProvider = Provider<BleService>((ref) {
  return BleService();
});

final bleScanResultsProvider = StreamProvider<List<ScanResult>>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.scanResults;
});
