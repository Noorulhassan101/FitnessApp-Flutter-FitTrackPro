import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/database/local_database.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';

String generateUuid() {
  final random = math.Random();
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final randVal = random.nextInt(1000000);
  return '$timestamp-$randVal';
}

final todayMealsProvider = StreamProvider<List<Meal>>((ref) {
  final db = ref.watch(databaseProvider);
  final authState = ref.watch(authProvider);
  final userId = authState.userId;
  if (userId == null) return Stream.value([]);
  return db.watchMealsForDay(userId, DateTime.now());
});

final mealsNotifierProvider = NotifierProvider<MealsNotifier, void>(() {
  return MealsNotifier();
});

class MealsNotifier extends Notifier<void> {
  @override
  void build() {
    return;
  }

  Future<bool> addMeal({
    required String mealCategory,
    required String foodName,
    required double caloriesConsumed,
    required DateTime loggedAt,
  }) async {
    final db = ref.read(databaseProvider);
    final authState = ref.read(authProvider);
    final dio = ref.read(dioProvider);
    final userId = authState.userId;

    if (userId == null) return false;

    final mealId = generateUuid();

    final localMeal = Meal(
      id: mealId,
      userId: userId,
      mealCategory: mealCategory,
      foodName: foodName,
      caloriesConsumed: caloriesConsumed,
      loggedAt: loggedAt,
      isSynced: false,
    );

    // Save locally first
    await db.upsertMeal(localMeal);

    // Attempt to sync online
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/meals',
        data: {
          'id': mealId,
          'mealCategory': mealCategory,
          'foodName': foodName,
          'caloriesConsumed': caloriesConsumed,
          'loggedAt': loggedAt.toIso8601String(),
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Mark as synced locally
        await db.upsertMeal(localMeal.copyWith(isSynced: true));
      }
    } catch (_) {
      // Silently fail if offline
    }

    return true;
  }

  Future<void> deleteMeal(String mealId) async {
    final db = ref.read(databaseProvider);
    final dio = ref.read(dioProvider);

    // Delete locally
    await db.deleteMealLocal(mealId);

    // Attempt delete online
    try {
      await dio.delete<Map<String, dynamic>>('/meals/$mealId');
    } catch (_) {
      // Silently fail if offline
    }
  }

  Future<void> syncUnsyncedMeals() async {
    final db = ref.read(databaseProvider);
    final dio = ref.read(dioProvider);
    final authState = ref.read(authProvider);
    final userId = authState.userId;

    if (userId == null) return;

    try {
      // 1. Sync unsynced meals to backend
      final unsynced = await db.getUnsyncedMeals();
      for (final m in unsynced) {
        if (m.userId != userId) continue;
        try {
          final response = await dio.post<Map<String, dynamic>>(
            '/meals',
            data: {
              'id': m.id,
              'mealCategory': m.mealCategory,
              'foodName': m.foodName,
              'caloriesConsumed': m.caloriesConsumed,
              'loggedAt': m.loggedAt.toIso8601String(),
            },
          );
          if (response.statusCode == 201 || response.statusCode == 200) {
            await db.upsertMeal(m.copyWith(isSynced: true));
          }
        } catch (_) {
          // Skip if individual post fails
        }
      }

      // 2. Pull latest meals from backend to local DB
      final response = await dio.get<List<dynamic>>('/meals');
      if (response.statusCode == 200 && response.data != null) {
        for (final item in response.data!) {
          final map = item as Map<String, dynamic>;
          final parsedMeal = Meal(
            id: map['id'] as String,
            userId: map['userId'] as String,
            mealCategory: map['mealCategory'] as String,
            foodName: map['foodName'] as String,
            caloriesConsumed: (map['caloriesConsumed'] as num).toDouble(),
            loggedAt: DateTime.parse(map['loggedAt'] as String),
            isSynced: true,
          );
          await db.upsertMeal(parsedMeal);
        }
      }
    } catch (_) {
      // Sync fail (offline)
    }
  }
}
