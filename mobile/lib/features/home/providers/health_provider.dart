import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:mobile/core/database/local_database.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/health/health_service.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/home/providers/home_provider.dart';

class HealthSyncState {
  final bool isSyncing;
  final int todaySteps;
  final double todayActiveCalories;
  final bool hasPermissions;
  final String? errorMessage;

  const HealthSyncState({
    this.isSyncing = false,
    this.todaySteps = 0,
    this.todayActiveCalories = 0.0,
    this.hasPermissions = false,
    this.errorMessage,
  });

  HealthSyncState copyWith({
    bool? isSyncing,
    int? todaySteps,
    double? todayActiveCalories,
    bool? hasPermissions,
    String? errorMessage,
  }) {
    return HealthSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      todaySteps: todaySteps ?? this.todaySteps,
      todayActiveCalories: todayActiveCalories ?? this.todayActiveCalories,
      hasPermissions: hasPermissions ?? this.hasPermissions,
      errorMessage: errorMessage,
    );
  }
}

class HealthSyncNotifier extends Notifier<HealthSyncState> {
  @override
  HealthSyncState build() {
    return const HealthSyncState();
  }

  Future<void> checkPermissions() async {
    final service = ref.read(healthServiceProvider);
    final has = await service.hasPermissions();
    state = state.copyWith(hasPermissions: has);
  }

  Future<void> requestPermissions() async {
    final service = ref.read(healthServiceProvider);
    state = state.copyWith(isSyncing: true);
    final granted = await service.requestPermissions();
    state = state.copyWith(hasPermissions: granted, isSyncing: false);
    if (granted) {
      await syncHealthData();
    }
  }

  Future<void> syncHealthData() async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) {
      state = state.copyWith(errorMessage: 'No authenticated user.');
      return;
    }

    state = state.copyWith(isSyncing: true, errorMessage: null);

    try {
      final service = ref.read(healthServiceProvider);
      final hasPerm = await service.hasPermissions();
      
      if (!hasPerm) {
        state = state.copyWith(
          isSyncing: false,
          hasPermissions: false,
          errorMessage: 'Health permissions not granted.',
        );
        return;
      }

      final today = DateTime.now();
      final todaySteps = await service.fetchStepsForDay(today);
      final todayCalories = await service.fetchActiveCaloriesForDay(today);

      // Cache locally in Drift DB
      final db = ref.read(databaseProvider);
      final todayStart = DateTime(today.year, today.month, today.day);

      final existing = await db.getDailySummary(userId, todayStart);

      // Fetch today's meals to compute totalConsumed
      final meals = await db.getMealsForDay(userId, todayStart);
      final totalMealsCals = meals.fold<double>(0.0, (sum, m) => sum + m.caloriesConsumed);

      // Fetch today's workouts to compute workouts calories burned
      final workouts = await db.getWorkoutsForDay(userId, todayStart);
      final totalWorkoutsCals = workouts.fold<double>(0.0, (sum, w) => sum + w.caloriesBurned);

      // Fetch user profile metrics for target calculations
      double tdee = 2000.0;
      String fitnessGoal = 'maintain';
      try {
        final dio = ref.read(dioProvider);
        final profileResponse = await dio.get<Map<String, dynamic>>('/user/profile');
        if (profileResponse.statusCode == 200 && profileResponse.data != null) {
          tdee = (profileResponse.data!['tdee'] as num?)?.toDouble() ?? 2000.0;
          fitnessGoal = profileResponse.data!['fitnessGoal'] as String? ?? 'maintain';
        }
      } catch (_) {
        final userDb = await db.getUser(userId);
        fitnessGoal = userDb?.fitnessGoal ?? 'maintain';
        if (userDb != null && userDb.age != null && userDb.heightCm != null && userDb.weightKg != null && userDb.gender != null) {
          final isMale = userDb.gender!.toLowerCase() == 'male';
          final bmrVal = 10 * userDb.weightKg! + 6.25 * userDb.heightCm! - 5 * userDb.age! + (isMale ? 5 : -161);
          tdee = bmrVal * 1.55;
        }
      }

      double baseTarget = tdee;
      if (fitnessGoal == 'deficit') {
        baseTarget = tdee - 500.0;
      } else if (fitnessGoal == 'surplus') {
        baseTarget = tdee + 300.0;
      }

      final combinedBurned = totalWorkoutsCals + todayCalories;
      final computedNet = baseTarget - totalMealsCals + combinedBurned;

      final summary = DailySummary(
        id: existing?.id ?? '${userId}_${todayStart.millisecondsSinceEpoch}',
        userId: userId,
        date: todayStart,
        totalCaloriesBurned: combinedBurned,
        totalCaloriesConsumed: totalMealsCals,
        netCalories: computedNet,
        streakDay: existing?.streakDay ?? 0,
        steps: todaySteps,
        activeCalories: todayCalories,
      );

      await db.upsertSummary(summary);

      // Push to remote backend
      final dio = ref.read(dioProvider);
      await dio.patch('/summary/sync', data: {
        'date': todayStart.toIso8601String().split('T')[0],
        'steps': todaySteps,
        'activeCalories': todayCalories,
      });

      state = state.copyWith(
        isSyncing: false,
        todaySteps: todaySteps,
        todayActiveCalories: todayCalories,
        hasPermissions: true,
      );

      // Refresh home dashboard provider
      ref.invalidate(homeDataProvider);
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        errorMessage: 'Sync failed: ${e.toString()}',
      );
    }
  }
}

final healthSyncProvider = NotifierProvider<HealthSyncNotifier, HealthSyncState>(() {
  return HealthSyncNotifier();
});
