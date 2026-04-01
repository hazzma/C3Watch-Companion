import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
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
      await ref.read(watchDataProvider.notifier).startHrMonitoring();
    } else {
      await ref.read(watchDataProvider.notifier).requestSteps();
    }
  }

  String _fmtTime(DateTime? t) {
    if (t == null) return "Never";
    return DateFormat('HH:mm:ss').format(t);
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
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // Real-time Chart
                Container(
                  height: 200,
                  padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      minY: 40,
                      maxY: 180,
                      lineBarsData: [
                        LineChartBarData(
                          spots: watchData.hrLogs.asMap().entries.map((e) {
                            return FlSpot(e.key.toDouble(), e.value.bpm.toDouble());
                          }).toList(),
                          isCurved: true,
                          color: AppColors.accentRed,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.accentRed.withAlpha(30),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn().slideY(begin: 0.1),
                
                const SizedBox(height: 24),
                
                // Big Display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatBox("BPM", watchData.hrBpm?.toString() ?? "—", AppColors.accentRed),
                    _buildStatBox("SpO2", watchData.hrSpo2 != null ? "${watchData.hrSpo2}%" : "—", AppColors.accentTeal),
                    _buildStatBox("AVG", watchData.avgBpm.toStringAsFixed(0), AppColors.accentPurple),
                  ],
                ),
                
                const SizedBox(height: 30),
                
                // Controls
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isConnected 
                          ? (watchData.isHrMonitoring 
                              ? () => ref.read(watchDataProvider.notifier).stopHrMonitoring() 
                              : () => ref.read(watchDataProvider.notifier).startHrMonitoring()) 
                          : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: watchData.isHrMonitoring ? AppColors.accentAmber : AppColors.accentRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: Icon(watchData.isHrMonitoring ? Icons.stop : Icons.play_arrow),
                        label: Text(watchData.isHrMonitoring ? "Stop Monitoring" : "Start Monitoring"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      onPressed: watchData.hrLogs.isNotEmpty ? () => ref.read(watchDataProvider.notifier).clearHrLogs() : null,
                      icon: const Icon(Icons.delete_sweep),
                      style: IconButton.styleFrom(backgroundColor: AppColors.bgSurface, foregroundColor: AppColors.textSecond),
                    ),
                  ],
                ),
                
                const SizedBox(height: 30),
                
                // Logs
                const Text("Activity History", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                if (watchData.hrLogs.isEmpty)
                   const Center(child: Padding(
                     padding: EdgeInsets.all(40),
                     child: Text("No data yet", style: TextStyle(color: AppColors.textHint)),
                   ))
                else
                  ...watchData.hrLogs.reversed.take(10).map((log) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmtTime(log.time), style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
                        Text("${log.bpm} BPM", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text("${log.spo2}% SpO2", style: const TextStyle(color: AppColors.accentTeal, fontSize: 13)),
                      ],
                    ),
                  )).toList(),
              ],
            ),
          ),
          
          // Steps Tab (Simplified)
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
                
                const SizedBox(height: 60),
                ElevatedButton.icon(
                  onPressed: isConnected ? () async {
                    await ref.read(watchDataProvider.notifier).requestSteps();
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Refresh Steps"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
      ],
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
