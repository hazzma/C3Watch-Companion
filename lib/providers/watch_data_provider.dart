import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/ble_constants.dart';
import '../core/utils/time_sync.dart';
import 'ble_provider.dart';

final lastSyncTimeProvider = StateProvider<DateTime?>((ref) => null);

class HrLog {
  final DateTime time;
  final int bpm;
  final int spo2;
  HrLog({required this.time, required this.bpm, required this.spo2});

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'bpm': bpm,
    'spo2': spo2,
  };

  factory HrLog.fromJson(Map<String, dynamic> json) => HrLog(
    time: DateTime.parse(json['time']),
    bpm: json['bpm'],
    spo2: json['spo2'],
  );
}

class WatchDataState {
  final int? hrBpm;
  final int? hrSpo2;
  final DateTime? hrTimestamp;
  final List<HrLog> hrLogs;
  final bool isHrMonitoring;
  
  final int? steps;
  final DateTime? stepsTimestamp;
  
  final int? batteryPercent;
  final bool? batteryIsCharging;
  final DateTime? batteryTimestamp;

  WatchDataState({
    this.hrBpm, this.hrSpo2, this.hrTimestamp,
    this.hrLogs = const [],
    this.isHrMonitoring = false,
    this.steps, this.stepsTimestamp,
    this.batteryPercent, this.batteryIsCharging, this.batteryTimestamp,
  });

  double get avgBpm {
    if (hrLogs.isEmpty) return 0;
    return hrLogs.map((l) => l.bpm).reduce((a, b) => a + b) / hrLogs.length;
  }

  WatchDataState copyWith({
    int? hrBpm, int? hrSpo2, DateTime? hrTimestamp,
    List<HrLog>? hrLogs,
    bool? isHrMonitoring,
    int? steps, DateTime? stepsTimestamp,
    int? batteryPercent, bool? batteryIsCharging, DateTime? batteryTimestamp,
  }) {
    return WatchDataState(
      hrBpm: hrBpm ?? this.hrBpm,
      hrSpo2: hrSpo2 ?? this.hrSpo2,
      hrTimestamp: hrTimestamp ?? this.hrTimestamp,
      hrLogs: hrLogs ?? this.hrLogs,
      isHrMonitoring: isHrMonitoring ?? this.isHrMonitoring,
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
    
    final logsJson = prefs.getStringList('hr_logs') ?? [];
    final logs = logsJson.map((l) => HrLog.fromJson(jsonDecode(l))).toList();
    
    int? steps = prefs.getInt('steps');
    String? stepsTime = prefs.getString('steps_time');
    
    int? battPct = prefs.getInt('batt_pct');
    bool? battChg = prefs.getBool('batt_chg');
    String? battTime = prefs.getString('batt_time');

    state = state.copyWith(
      hrBpm: hrBpm, hrSpo2: hrSpo2, hrTimestamp: hrTime != null ? DateTime.parse(hrTime) : null,
      hrLogs: logs,
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
        state = state.copyWith(isHrMonitoring: false);
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
        
        final newLog = HrLog(time: now, bpm: bpm, spo2: spo2);
        final updatedLogs = [...state.hrLogs, newLog];
        if (updatedLogs.length > 50) updatedLogs.removeAt(0); // Keep last 50 for graph

        state = state.copyWith(hrBpm: bpm, hrSpo2: spo2, hrTimestamp: now, hrLogs: updatedLogs);
        
        final prefs = await SharedPreferences.getInstance();
        prefs.setInt('hr_bpm', bpm);
        prefs.setInt('hr_spo2', spo2);
        prefs.setString('hr_time', now.toIso8601String());
        prefs.setStringList('hr_logs', updatedLogs.map((l) => jsonEncode(l.toJson())).toList());
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

  Future<void> startHrMonitoring() async {
    await ref.read(bleServiceProvider).sendCommand(BleConstants.cmdRequestHr);
    state = state.copyWith(isHrMonitoring: true);
  }

  Future<void> stopHrMonitoring() async {
    await ref.read(bleServiceProvider).sendCommand(BleConstants.cmdStopHr);
    state = state.copyWith(isHrMonitoring: false);
  }

  Future<void> clearHrLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('hr_logs');
    state = state.copyWith(hrLogs: []);
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
