import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/widgets/ble_status_pill.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/watch_data_provider.dart';
import '../../providers/ble_provider.dart';
import '../../core/constants/ble_constants.dart';
import 'dart:ui';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
           _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatNumber(int number) => number.toString().padLeft(2, '0');

  String _fmtTime(DateTime? t) {
    if (t == null) return "Never";
    return '${_formatNumber(t.hour)}:${_formatNumber(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final watchData = ref.watch(watchDataProvider);
    final lastSync = ref.watch(lastSyncTimeProvider);
    final connectionState = ref.watch(bleConnectionStateProvider);
    final isConnected = connectionState == BleConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: const [
          BleStatusPill(),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Big Clock
              Text(
                '${_formatNumber(_currentTime.hour)}:${_formatNumber(_currentTime.minute)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 72,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 40),
              
              // Grid
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildMetricCard(
                      title: "Heart Rate",
                      value: watchData.hrBpm != null ? '${watchData.hrBpm}' : '—',
                      unit: "BPM",
                      icon: Icons.favorite,
                      iconColor: AppColors.accentRed,
                      pulseIcon: isConnected,
                      subtitle: watchData.hrSpo2 != null ? 'SpO2: ${watchData.hrSpo2}%' : 'Last known: ${_fmtTime(watchData.hrTimestamp)}',
                    ).animate(delay: 0.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
                    
                    _buildMetricCard(
                      title: "Steps",
                      value: watchData.steps != null ? '${watchData.steps}' : '—',
                      unit: "steps",
                      icon: Icons.directions_walk,
                      iconColor: AppColors.accentTeal,
                      pulseIcon: false,
                      subtitle: 'Goal: 10,000',
                    ).animate(delay: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
                    
                    _buildMetricCard(
                      title: "Battery",
                      value: watchData.batteryPercent != null ? '${watchData.batteryPercent}' : '—',
                      unit: "%",
                      icon: watchData.batteryIsCharging == true ? Icons.bolt : Icons.battery_full,
                      iconColor: watchData.batteryIsCharging == true ? AppColors.accentAmber : AppColors.accentTeal,
                      pulseIcon: false,
                      subtitle: watchData.batteryIsCharging == true ? "Charging" : 'Last known: ${_fmtTime(watchData.batteryTimestamp)}',
                    ).animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
                    
                    _buildMetricCard(
                      title: "Last Sync",
                      value: lastSync != null ? "${_formatNumber(lastSync.hour)}:${_formatNumber(lastSync.minute)}" : '—',
                      unit: "",
                      icon: Icons.sync,
                      iconColor: AppColors.accentPurple,
                      pulseIcon: false,
                      subtitle: lastSync != null ? "Today" : "Never synced",
                    ).animate(delay: 300.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isConnected ? () async {
          await ref.read(timeSyncProvider).syncTime();
          // Request non-intrusive data only to avoid watch HR monitoring mode
          final notifier = ref.read(watchDataProvider.notifier);
          await notifier.requestSteps();
          await Future.delayed(const Duration(milliseconds: 200));
          await ref.read(bleServiceProvider).sendCommand(BleConstants.cmdRequestBattery);
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Syncing...'), backgroundColor: AppColors.accentTeal));
          }
        } : null,
        backgroundColor: isConnected ? AppColors.accentPurple : AppColors.bgElevated,
        foregroundColor: isConnected ? Colors.white : AppColors.textHint,
        elevation: 0,
        icon: const Icon(Icons.sync),
        label: const Text("Sync Now"),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color iconColor,
    required bool pulseIcon,
    required String subtitle,
  }) {
    Widget iconWidget = Icon(icon, color: iconColor, size: 28);
    if (pulseIcon) {
      iconWidget = iconWidget.animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1,1), end: const Offset(1.2, 1.2), duration: 800.ms);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              iconWidget,
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AppColors.textSecond, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.bold)),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(unit, style: const TextStyle(color: AppColors.textHint, fontSize: 14)),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: AppColors.textHint, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}
