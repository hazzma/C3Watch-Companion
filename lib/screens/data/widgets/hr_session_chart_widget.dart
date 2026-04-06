import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../providers/watch_data_provider.dart';

class HrSessionChartWidget extends StatelessWidget {
  final List<HrLog> session;
  final bool compact;

  const HrSessionChartWidget({
    super.key,
    required this.session,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (session.isEmpty) return const SizedBox.shrink();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: session.map((e) => e.bpm).reduce((a, b) => a < b ? a : b).toDouble() - 10,
        maxY: session.map((e) => e.bpm).reduce((a, b) => a > b ? a : b).toDouble() + 10,
        lineBarsData: [
          LineChartBarData(
            spots: session.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value.bpm.toDouble());
            }).toList(),
            isCurved: true,
            color: AppColors.accentRed,
            barWidth: compact ? 2 : 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.accentRed.withAlpha(compact ? 10 : 30),
            ),
          ),
        ],
      ),
    );
  }
}
