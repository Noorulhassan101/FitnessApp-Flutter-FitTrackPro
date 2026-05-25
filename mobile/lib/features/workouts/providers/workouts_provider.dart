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

final todayWorkoutsProvider = StreamProvider<List<Workout>>((ref) {
  final db = ref.watch(databaseProvider);
  final authState = ref.watch(authProvider);
  final userId = authState.userId;
  if (userId == null) return Stream.value([]);
  return db.watchWorkoutsForDay(userId, DateTime.now());
});

final workoutsNotifierProvider = NotifierProvider<WorkoutsNotifier, void>(() {
  return WorkoutsNotifier();
});

class WorkoutsNotifier extends Notifier<void> {
  @override
  void build() {
    return;
  }

  Future<bool> addWorkout({
    required String activityType,
    required int durationMin,
    required double caloriesBurned,
    required double metEstimate,
    String? notes,
    required DateTime loggedAt,
  }) async {
    final db = ref.read(databaseProvider);
    final authState = ref.read(authProvider);
    final dio = ref.read(dioProvider);
    final userId = authState.userId;

    if (userId == null) return false;

    final workoutId = generateUuid();

    final localWorkout = Workout(
      id: workoutId,
      userId: userId,
      activityType: activityType,
      durationMin: durationMin,
      caloriesBurned: caloriesBurned,
      metEstimate: metEstimate,
      notes: notes,
      loggedAt: loggedAt,
      isSynced: false,
    );

    // Save locally first
    await db.upsertWorkout(localWorkout);

    // Attempt to sync online
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/workouts',
        data: {
          'id': workoutId,
          'activityType': activityType,
          'durationMin': durationMin,
          'caloriesBurned': caloriesBurned,
          'metEstimate': metEstimate,
          'notes': notes,
          'loggedAt': loggedAt.toIso8601String(),
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Mark as synced locally
        await db.upsertWorkout(localWorkout.copyWith(isSynced: true));
      }
    } catch (_) {
      // Silently fail if offline
    }

    return true;
  }

  Future<void> deleteWorkout(String workoutId) async {
    final db = ref.read(databaseProvider);
    final dio = ref.read(dioProvider);

    // Delete locally
    await db.deleteWorkoutLocal(workoutId);

    // Attempt delete online
    try {
      await dio.delete<Map<String, dynamic>>('/workouts/$workoutId');
    } catch (_) {
      // Silently fail if offline
    }
  }

  Future<void> syncUnsyncedWorkouts() async {
    final db = ref.read(databaseProvider);
    final dio = ref.read(dioProvider);
    final authState = ref.read(authProvider);
    final userId = authState.userId;

    if (userId == null) return;

    try {
      // 1. Sync unsynced workouts to backend
      final unsynced = await db.getUnsyncedWorkouts();
      for (final w in unsynced) {
        if (w.userId != userId) continue;
        try {
          final response = await dio.post<Map<String, dynamic>>(
            '/workouts',
            data: {
              'id': w.id,
              'activityType': w.activityType,
              'durationMin': w.durationMin,
              'caloriesBurned': w.caloriesBurned,
              'metEstimate': w.metEstimate,
              'notes': w.notes,
              'loggedAt': w.loggedAt.toIso8601String(),
            },
          );
          if (response.statusCode == 201 || response.statusCode == 200) {
            await db.upsertWorkout(w.copyWith(isSynced: true));
          }
        } catch (_) {
          // If a single post fails, skip or keep going
        }
      }

      // 2. Pull latest workouts from backend to local DB
      final response = await dio.get<List<dynamic>>('/workouts');
      if (response.statusCode == 200 && response.data != null) {
        for (final item in response.data!) {
          final map = item as Map<String, dynamic>;
          final parsedWorkout = Workout(
            id: map['id'] as String,
            userId: map['userId'] as String,
            activityType: map['activityType'] as String,
            durationMin: map['durationMin'] as int,
            caloriesBurned: (map['caloriesBurned'] as num).toDouble(),
            metEstimate: (map['metEstimate'] as num).toDouble(),
            notes: map['notes'] as String?,
            loggedAt: DateTime.parse(map['loggedAt'] as String),
            isSynced: true,
          );
          await db.upsertWorkout(parsedWorkout);
        }
      }
    } catch (_) {
      // Sync fail (offline)
    }
  }
}
