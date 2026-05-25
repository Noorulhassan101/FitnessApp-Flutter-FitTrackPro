import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/database/local_database.dart';
import 'package:mobile/features/stats/providers/stats_provider.dart';

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  @override
  void initState() {
    super.initState();
    // Synchronize latest summaries from backend on page load
    Future.microtask(() {
      ref.read(statsNotifierProvider.notifier).syncWeeklySummaries();
    });
  }

  @override
  Widget build(BuildContext context) {
    final weeklyStatsAsync = ref.watch(weeklyStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Progress Stats',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(statsNotifierProvider.notifier).syncWeeklySummaries(),
          color: const Color(0xFF1A36A8),
          child: weeklyStatsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text('Failed to load stats: $err'),
                ],
              ),
            ),
            data: (summaries) {
              if (summaries.isEmpty) {
                return _buildEmptyState();
              }

              // Extract streak from the latest summary record if available
              final currentStreak = summaries.isNotEmpty ? summaries.last.streakDay : 0;

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Streak Card
                    _buildStreakCard(currentStreak),
                    const SizedBox(height: 24),

                    // Weekly Calorie Trend Section
                    const Text(
                      'Weekly Calorie Trend',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    _buildCalorieTrendChart(summaries),
                    const SizedBox(height: 28),

                    // Averages Breakdown Card
                    const Text(
                      'Weekly Summary',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    _buildAveragesCard(summaries),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.insert_chart_outlined_rounded, size: 72, color: Colors.black12),
            const SizedBox(height: 16),
            const Text(
              'No stats logs recorded yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start logging your workouts and meals today. Your progress metrics and trends will show up here.',
              style: TextStyle(color: Colors.black38, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard(int streak) {
    final disableAnimations = MediaQuery.of(context).disableAnimations || Platform.environment.containsKey('FLUTTER_TEST');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8C00), Color(0xFFFF4500)], // Orange-red gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4500).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Glowing Animated Flame Icon
          disableAnimations
              ? const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 48,
                )
              : const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 48,
                )
                  .animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  )
                  .scale(
                    begin: const Offset(1.0, 1.0),
                    end: const Offset(1.15, 1.15),
                    duration: 900.ms,
                    curve: Curves.easeInOut,
                  )
                  .boxShadow(
                    begin: const BoxShadow(color: Colors.transparent),
                    end: const BoxShadow(color: Colors.white30, blurRadius: 10),
                  ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$streak Day${streak == 1 ? "" : "s"} Streak',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Keep logging your meals and workouts daily to maintain your streak!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieTrendChart(List<DailySummary> summaries) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _getMaxCalorieValue(summaries) * 1.15,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.black87,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final category = rodIndex == 0 ? 'Consumed' : 'Burned';
                return BarTooltipItem(
                  '$category: ${rod.toY.round()} kcal',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < summaries.length) {
                    final date = summaries[index].date;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('E').format(date),
                        style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(summaries.length, (index) {
            final summary = summaries[index];
            return BarChartGroupData(
              x: index,
              barRods: [
                // Consumed Calories (Red/Coral)
                BarChartRodData(
                  toY: summary.totalCaloriesConsumed,
                  color: const Color(0xFFD9383A),
                  width: 8,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                // Burned Calories (Green)
                BarChartRodData(
                  toY: summary.totalCaloriesBurned,
                  color: const Color(0xFF1D976C),
                  width: 8,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  double _getMaxCalorieValue(List<DailySummary> summaries) {
    double maxVal = 1000.0;
    for (final s in summaries) {
      if (s.totalCaloriesConsumed > maxVal) maxVal = s.totalCaloriesConsumed;
      if (s.totalCaloriesBurned > maxVal) maxVal = s.totalCaloriesBurned;
    }
    return maxVal;
  }

  Widget _buildAveragesCard(List<DailySummary> summaries) {
    double totalConsumed = 0;
    double totalBurned = 0;
    for (final s in summaries) {
      totalConsumed += s.totalCaloriesConsumed;
      totalBurned += s.totalCaloriesBurned;
    }
    final avgConsumed = totalConsumed / summaries.length;
    final avgBurned = totalBurned / summaries.length;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.black12),
      ),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildAverageRow(
              'Avg. Calories Consumed',
              '${avgConsumed.round()} kcal',
              const Color(0xFFD9383A),
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.black12, height: 1),
            const SizedBox(height: 12),
            _buildAverageRow(
              'Avg. Calories Burned',
              '${avgBurned.round()} kcal',
              const Color(0xFF1D976C),
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.black12, height: 1),
            const SizedBox(height: 12),
            _buildAverageRow(
              'Average Net Remaining',
              '${(avgConsumed - avgBurned).round()} kcal',
              const Color(0xFF1A36A8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAverageRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54, fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
        ),
      ],
    );
  }
}
