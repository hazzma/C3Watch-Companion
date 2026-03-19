import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/widgets/ble_status_pill.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/watch_data_provider.dart';
import '../../providers/ble_provider.dart';

class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});

  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (ref.read(bleConnectionStateProvider) != BleConnectionState.connected) return;
    
    if (_tabController.index == 0) {
      await ref.read(watchDataProvider.notifier).requestHr();
    } else {
      await ref.read(watchDataProvider.notifier).requestSteps();
    }
  }

  String _fmtTime(DateTime? t) {
    if (t == null) return "Never";
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final watchData = ref.watch(watchDataProvider);
    final isConnected = ref.watch(bleConnectionStateProvider) == BleConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch Data'),
        actions: const [BleStatusPill()],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentPurple,
          labelColor: AppColors.accentPurple,
          unselectedLabelColor: AppColors.textHint,
          tabs: const [
            Tab(text: "Heart Rate"),
            Tab(text: "Steps"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // HR Tab
          RefreshIndicator(
            onRefresh: _handleRefresh,
            color: AppColors.accentPurple,
            child: ListView(
              padding: const EdgeInsets.all(24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.accentRed.withAlpha(50), width: 2),
                    ),
                    child: Center(
                      child: isConnected 
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (i) => 
                              Container(
                                width: 4,
                                height: 40,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(color: AppColors.accentRed, borderRadius: BorderRadius.circular(2)),
                              ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleY(begin: 0.2, end: 1.5, duration: (300 + i*100).ms, curve: Curves.easeInOut)
                            ),
                          )
                        : const Icon(Icons.monitor_heart, color: AppColors.textHint, size: 48),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text(watchData.hrBpm != null ? '${watchData.hrBpm}' : '—', style: const TextStyle(fontSize: 96, fontWeight: FontWeight.bold, color: AppColors.textPrimary), textAlign: TextAlign.center),
                const Text("BPM", style: TextStyle(color: AppColors.accentRed, fontSize: 24, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.water_drop, color: AppColors.accentTeal, size: 20),
                    const SizedBox(width: 8),
                    Text(watchData.hrSpo2 != null ? 'SpO2: ${watchData.hrSpo2}%' : 'SpO2: —', style: const TextStyle(color: AppColors.textSecond, fontSize: 18)),
                  ],
                ),
                
                const SizedBox(height: 40),
                Center(child: Text(watchData.hrTimestamp != null ? 'Last known: ${_fmtTime(watchData.hrTimestamp)}' : 'No data recorded', style: const TextStyle(color: AppColors.textHint))),
                
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: isConnected ? () async {
                    await ref.read(watchDataProvider.notifier).requestHr();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reading requested...'), backgroundColor: AppColors.accentRed));
                    }
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentRed,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.bgElevated,
                    disabledForegroundColor: AppColors.textHint,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.favorite),
                  label: const Text("Take Reading"),
                ),
              ],
            ),
          ),
          
          // Steps Tab
          RefreshIndicator(
            onRefresh: _handleRefresh,
            color: AppColors.accentPurple,
            child: ListView(
              padding: const EdgeInsets.all(24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: CircularProgressIndicator(
                          value: watchData.steps != null ? (watchData.steps! / 10000).clamp(0.0, 1.0) : 0,
                          strokeWidth: 16,
                          backgroundColor: AppColors.bgSurface,
                          color: AppColors.accentTeal,
                        ),
                      ),
                      Column(
                        children: [
                          const Icon(Icons.directions_walk, color: AppColors.accentTeal, size: 40),
                          const SizedBox(height: 8),
                          Text(watchData.steps != null ? '${watchData.steps}' : '—', style: const TextStyle(color: AppColors.textPrimary, fontSize: 36, fontWeight: FontWeight.bold)),
                          const Text("/ 10,000", style: TextStyle(color: AppColors.textHint, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 50),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCol(Icons.local_fire_department, AppColors.accentAmber, watchData.steps != null ? (watchData.steps! * 0.04).toStringAsFixed(1) : '—', 'kcal'),
                    _buildStatCol(Icons.map, AppColors.accentPurple, watchData.steps != null ? (watchData.steps! * 0.762 / 1000).toStringAsFixed(2) : '—', 'km'),
                  ],
                ),
                
                const SizedBox(height: 40),
                Center(child: Text(watchData.stepsTimestamp != null ? 'Last known: ${_fmtTime(watchData.stepsTimestamp)}' : 'No data recorded', style: const TextStyle(color: AppColors.textHint))),
                
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: isConnected ? () async {
                    await ref.read(watchDataProvider.notifier).requestSteps();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refreshing steps...'), backgroundColor: AppColors.accentTeal));
                    }
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTeal,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.bgElevated,
                    disabledForegroundColor: AppColors.textHint,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Refresh"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(IconData icon, Color color, String val, String unit) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(val, style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(unit, style: const TextStyle(color: AppColors.textHint, fontSize: 14)),
      ],
    );
  }
}
