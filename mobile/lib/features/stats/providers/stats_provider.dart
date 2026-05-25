import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/database/local_database.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';

final weeklyStatsProvider = StreamProvider<List<DailySummary>>((ref) {
  final db = ref.watch(databaseProvider);
  final authState = ref.watch(authProvider);
  final userId = authState.userId;
  if (userId == null) return Stream.value([]);
  return db.watchWeeklySummaries(userId);
});

final statsNotifierProvider = NotifierProvider<StatsNotifier, void>(() {
  return StatsNotifier();
});

class StatsNotifier extends Notifier<void> {
  @override
  void build() {
    return;
  }

  Future<void> syncWeeklySummaries() async {
    final db = ref.read(databaseProvider);
    final dio = ref.read(dioProvider);
    final authState = ref.read(authProvider);
    final userId = authState.userId;

    if (userId == null) return;

    try {
      final response = await dio.get<Map<String, dynamic>>('/summary/history');
      if (response.statusCode == 200 && response.data != null) {
        final streak = response.data!['streak'] as int? ?? 0;
        final history = response.data!['history'] as List<dynamic>? ?? [];

        for (final item in history) {
          final map = item as Map<String, dynamic>;
          final parsedDate = DateTime.parse(map['date'] as String);
          
          final summary = DailySummary(
            id: '$userId-${map['date'] as String}',
            userId: userId,
            date: parsedDate,
            totalCaloriesConsumed: (map['totalCaloriesConsumed'] as num).toDouble(),
            totalCaloriesBurned: (map['totalCaloriesBurned'] as num).toDouble(),
            netCalories: (map['netCalories'] as num).toDouble(),
            streakDay: streak,
          );

          await db.upsertSummary(summary);
        }
      }
    } catch (_) {
      // Fail silently on sync fail (offline mode)
    }
  }
}
