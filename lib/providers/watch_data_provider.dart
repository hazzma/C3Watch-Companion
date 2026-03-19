import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/ble_constants.dart';
import '../core/utils/time_sync.dart';
import 'ble_provider.dart';

final lastSyncTimeProvider = StateProvider<DateTime?>((ref) => null);

class WatchDataState {
  final int? hrBpm;
  final int? hrSpo2;
  final DateTime? hrTimestamp;
  
  final int? steps;
  final DateTime? stepsTimestamp;
  
  final int? batteryPercent;
  final bool? batteryIsCharging;
  final DateTime? batteryTimestamp;

  WatchDataState({
    this.hrBpm, this.hrSpo2, this.hrTimestamp,
    this.steps, this.stepsTimestamp,
    this.batteryPercent, this.batteryIsCharging, this.batteryTimestamp,
  });

  WatchDataState copyWith({
    int? hrBpm, int? hrSpo2, DateTime? hrTimestamp,
    int? steps, DateTime? stepsTimestamp,
    int? batteryPercent, bool? batteryIsCharging, DateTime? batteryTimestamp,
  }) {
    return WatchDataState(
      hrBpm: hrBpm ?? this.hrBpm,
      hrSpo2: hrSpo2 ?? this.hrSpo2,
      hrTimestamp: hrTimestamp ?? this.hrTimestamp,
      steps: steps ?? this.steps,
      stepsTimestamp: stepsTimestamp ?? this.stepsTimestamp,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      batteryIsCharging: batteryIsCharging ?? this.batteryIsCharging,
      batteryTimestamp: batteryTimestamp ?? this.batteryTimestamp,
    );
  }
}

class WatchDataNotifier extends StateNotifier<WatchDataState> {
  final Ref ref;
  
  StreamSubscription? _hrSub;
  StreamSubscription? _stepsSub;
  StreamSubscription? _battSub;

  WatchDataNotifier(this.ref) : super(WatchDataState()) {
    _loadCachedData();
    _listenToConnection();
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    int? hrBpm = prefs.getInt('hr_bpm');
    int? hrSpo2 = prefs.getInt('hr_spo2');
    String? hrTime = prefs.getString('hr_time');
    
    int? steps = prefs.getInt('steps');
    String? stepsTime = prefs.getString('steps_time');
    
    int? battPct = prefs.getInt('batt_pct');
    bool? battChg = prefs.getBool('batt_chg');
    String? battTime = prefs.getString('batt_time');

    state = state.copyWith(
      hrBpm: hrBpm, hrSpo2: hrSpo2, hrTimestamp: hrTime != null ? DateTime.parse(hrTime) : null,
      steps: steps, stepsTimestamp: stepsTime != null ? DateTime.parse(stepsTime) : null,
      batteryPercent: battPct, batteryIsCharging: battChg, batteryTimestamp: battTime != null ? DateTime.parse(battTime) : null,
    );
  }

  void _listenToConnection() {
    ref.listen<BleConnectionState>(bleConnectionStateProvider, (prev, next) {
      if (next == BleConnectionState.connected && prev != BleConnectionState.connected) {
        _subscribeToData();
      } else if (next == BleConnectionState.disconnected) {
        _cancelSubscriptions();
      }
    });
  }

  Future<void> _subscribeToData() async {
    final service = ref.read(bleServiceProvider);
    
    final hrStream = await service.subscribeToCharacteristic(BleConstants.charHrDataUuid);
    _hrSub = hrStream?.listen((data) async {
      if (data.length >= 4) {
        final bpm = data[0];
        final spo2 = data[1];
        final now = DateTime.now();
        
        state = state.copyWith(hrBpm: bpm, hrSpo2: spo2, hrTimestamp: now);
        
        final prefs = await SharedPreferences.getInstance();
        prefs.setInt('hr_bpm', bpm);
        prefs.setInt('hr_spo2', spo2);
        prefs.setString('hr_time', now.toIso8601String());
      }
    });

    final stepsStream = await service.subscribeToCharacteristic(BleConstants.charStepsUuid);
    _stepsSub = stepsStream?.listen((data) async {
      if (data.length >= 4) {
        final steps = data[0] | (data[1] << 8) | (data[2] << 16) | (data[3] << 24);
        final now = DateTime.now();
        
        state = state.copyWith(steps: steps, stepsTimestamp: now);
        
        final prefs = await SharedPreferences.getInstance();
        prefs.setInt('steps', steps);
        prefs.setString('steps_time', now.toIso8601String());
      }
    });

    final battStream = await service.subscribeToCharacteristic(BleConstants.charBatteryUuid);
    _battSub = battStream?.listen((data) async {
      if (data.length >= 2) {
        final pct = data[0];
        final isChg = data[1] == 1;
        final now = DateTime.now();
        
        state = state.copyWith(batteryPercent: pct, batteryIsCharging: isChg, batteryTimestamp: now);
        
        final prefs = await SharedPreferences.getInstance();
        prefs.setInt('batt_pct', pct);
        prefs.setBool('batt_chg', isChg);
        prefs.setString('batt_time', now.toIso8601String());
      }
    });
  }

  void _cancelSubscriptions() {
    _hrSub?.cancel();
    _stepsSub?.cancel();
    _battSub?.cancel();
  }

  Future<void> requestAllData() async {
    final service = ref.read(bleServiceProvider);
    await service.sendCommand(BleConstants.cmdRequestHr);
    await Future.delayed(const Duration(milliseconds: 200));
    await service.sendCommand(BleConstants.cmdRequestSteps);
    await Future.delayed(const Duration(milliseconds: 200));
    await service.sendCommand(BleConstants.cmdRequestBattery);
  }

  Future<void> requestHr() async {
    await ref.read(bleServiceProvider).sendCommand(BleConstants.cmdRequestHr);
  }

  Future<void> requestSteps() async {
    await ref.read(bleServiceProvider).sendCommand(BleConstants.cmdRequestSteps);
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}

final watchDataProvider = StateNotifierProvider<WatchDataNotifier, WatchDataState>((ref) {
  return WatchDataNotifier(ref);
});

// Time Sync Logic from Step 4
class TimeSyncNotifier {
  final Ref ref;
  TimeSyncNotifier(this.ref);

  Future<bool> syncTime() async {
    final service = ref.read(bleServiceProvider);
    final packet = TimeSyncUtil.buildPacket(DateTime.now());

    bool success = await service.writeCharacteristic(
      BleConstants.charTimeSyncUuid,
      packet,
    );
    
    if (success) {
      ref.read(lastSyncTimeProvider.notifier).state = DateTime.now();
    }
    
    return success;
  }
}

final timeSyncProvider = Provider<TimeSyncNotifier>((ref) {
  return TimeSyncNotifier(ref);
});
