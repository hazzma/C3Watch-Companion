import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/watch_data_provider.dart';
import 'widgets/hr_session_chart_widget.dart';

class HrHistoryScreen extends ConsumerStatefulWidget {
  const HrHistoryScreen({super.key});

  @override
  ConsumerState<HrHistoryScreen> createState() => _HrHistoryScreenState();
}

class _HrHistoryScreenState extends ConsumerState<HrHistoryScreen> {
  List<List<HrLog>> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('hr_history_v2') ?? [];
    
    List<List<HrLog>> loadedSessions = [];
    for (var sessionStr in historyJson) {
      final List<dynamic> list = jsonDecode(sessionStr);
      loadedSessions.add(list.map((l) => HrLog.fromJson(l)).toList());
    }

    setState(() {
      _sessions = loadedSessions.reversed.toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Heart Rate Journal"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmClear(),
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _sessions.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final session = _sessions[index];
                return _buildSessionCard(session);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 64, color: AppColors.textHint.withAlpha(100)),
          const SizedBox(height: 16),
          const Text("No sessions recorded yet", style: TextStyle(color: AppColors.textSecond)),
        ],
      ),
    );
  }

  Widget _buildSessionCard(List<HrLog> session) {
    if (session.isEmpty) return const SizedBox.shrink();
    
    final startTime = session.first.time;
    final avgBpm = session.map((e) => e.bpm).reduce((a, b) => a + b) / session.length;
    final maxBpm = session.map((e) => e.bpm).reduce((a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _showSessionDetails(session),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, MMM d').format(startTime),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        DateFormat('HH:mm').format(startTime),
                        style: const TextStyle(color: AppColors.textHint, fontSize: 12),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentRed.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${avgBpm.toStringAsFixed(0)} BPM Avg",
                      style: const TextStyle(color: AppColors.accentRed, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 80,
                child: HrSessionChartWidget(session: session, compact: true),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _miniStat("Min", session.map((e) => e.bpm).reduce((a, b) => a < b ? a : b).toString()),
                  _miniStat("Max", maxBpm.toString()),
                  _miniStat("Count", session.length.toString()),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textHint, fontSize: 10)),
        Text(val, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showSessionDetails(List<HrLog> session) {
    // Navigate or show bottom sheet with full chart
  }

  void _confirmClear() {
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text("Clear History?", style: TextStyle(color: Colors.white)),
        content: const Text("This will delete all saved sessions.", style: TextStyle(color: AppColors.textSecond)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('hr_history_v2');
              Navigator.pop(context);
              _loadHistory();
            }, 
            child: const Text("Delete All", style: TextStyle(color: AppColors.accentRed))
          ),
        ],
      )
    );
  }
}
