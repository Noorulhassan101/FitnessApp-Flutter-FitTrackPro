import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/database/local_database.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/workouts/providers/workouts_provider.dart';
import 'package:mobile/features/meals/providers/meals_provider.dart';

class HomeData {
  final String userName;
  final double dailyCalorieTarget;
  final double bmr;
  final double tdee;
  final double proteinTarget; // grams
  final double carbsTarget;   // grams
  final double fatTarget;     // grams
  final double caloriesConsumed;
  final double caloriesBurned;
  final String fitnessGoal;
  final int steps;
  final double activeCalories;

  HomeData({
    required this.userName,
    required this.dailyCalorieTarget,
    required this.bmr,
    required this.tdee,
    required this.proteinTarget,
    required this.carbsTarget,
    required this.fatTarget,
    this.caloriesConsumed = 0,
    this.caloriesBurned = 0,
    this.fitnessGoal = 'maintain',
    this.steps = 0,
    this.activeCalories = 0.0,
  });

  double get caloriesRemaining => dailyCalorieTarget - caloriesConsumed + caloriesBurned;
}

final homeDataProvider = FutureProvider<HomeData>((ref) async {
  final dio = ref.read(dioProvider);
  final auth = ref.watch(authProvider);
  final userId = auth.userId;

  // Watch today's workouts to automatically react to changes
  double workoutsBurned = 0;
  try {
    final workouts = await ref.watch(todayWorkoutsProvider.future);
    workoutsBurned = workouts.fold<double>(0, (sum, w) => sum + w.caloriesBurned);
  } catch (_) {}

  // Watch today's meals to automatically react to changes
  double caloriesConsumed = 0;
  try {
    final meals = await ref.watch(todayMealsProvider.future);
    caloriesConsumed = meals.fold<double>(0, (sum, m) => sum + m.caloriesConsumed);
  } catch (_) {}

  // Watch today's health summary to react to steps & active calories
  double healthActiveCalories = 0.0;
  int todaySteps = 0;
  if (userId != null) {
    final db = ref.watch(databaseProvider);
    try {
      final summary = await ref.watch(StreamProvider<DailySummary?>((ref) {
        return db.watchTodaySummary(userId);
      }).future);
      if (summary != null) {
        healthActiveCalories = summary.activeCalories;
        todaySteps = summary.steps;
      }
    } catch (_) {}
  }

  final totalBurned = workoutsBurned + healthActiveCalories;

  try {
    final response = await dio.get<Map<String, dynamic>>('/user/profile');
    final data = response.data!;

    final name = data['name'] as String? ?? 'User';
    final bmr = (data['bmr'] as num?)?.toDouble() ?? 1500.0;
    final tdee = (data['tdee'] as num?)?.toDouble() ?? 2000.0;
    final fitnessGoal = data['fitnessGoal'] as String? ?? 'maintain';

    // Calculate the user's daily calorie target based on fitness goal
    double dailyTarget = tdee;
    if (fitnessGoal == 'deficit') {
      dailyTarget = tdee - 500; // 500 cal deficit
    } else if (fitnessGoal == 'surplus') {
      dailyTarget = tdee + 300; // 300 cal surplus
    }

    // Calculate macro targets from daily calorie target
    // 30% protein, 40% carbs, 30% fat
    final proteinCals = dailyTarget * 0.30;
    final carbsCals = dailyTarget * 0.40;
    final fatCals = dailyTarget * 0.30;

    return HomeData(
      userName: name,
      dailyCalorieTarget: dailyTarget,
      bmr: bmr,
      tdee: tdee,
      proteinTarget: proteinCals / 4,  // 4 cal per gram protein
      carbsTarget: carbsCals / 4,      // 4 cal per gram carbs
      fatTarget: fatCals / 9,          // 9 cal per gram fat
      caloriesConsumed: caloriesConsumed,
      caloriesBurned: totalBurned,
      fitnessGoal: fitnessGoal,
      steps: todaySteps,
      activeCalories: healthActiveCalories,
    );
  } on DioException {
    // Return defaults if profile fetch fails
    return HomeData(
      userName: 'User',
      dailyCalorieTarget: 2000,
      bmr: 1500,
      tdee: 2000,
      proteinTarget: 150,
      carbsTarget: 200,
      fatTarget: 67,
      caloriesConsumed: caloriesConsumed,
      caloriesBurned: totalBurned,
      steps: todaySteps,
      activeCalories: healthActiveCalories,
    );
  }
});
