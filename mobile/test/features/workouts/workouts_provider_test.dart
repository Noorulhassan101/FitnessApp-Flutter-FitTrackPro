import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';

import 'package:mobile/core/database/local_database.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/workouts/providers/workouts_provider.dart';

class MockDio extends Mock implements Dio {}

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return AuthState.authenticated(id: 'user-123', email: 'test@example.com', name: 'Test User');
  }
}

void main() {
  late MockDio mockDio;
  late LocalDatabase db;
  late ProviderContainer container;

  setUp(() {
    mockDio = MockDio();
    db = LocalDatabase(NativeDatabase.memory());

    container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(mockDio),
        databaseProvider.overrideWithValue(db),
        authProvider.overrideWith(() => FakeAuthNotifier()),
      ],
    );
  });

  tearDown(() async {
    await db.close();
    container.dispose();
  });

  group('WorkoutsNotifier', () {
    test('addWorkout saves locally and posts to API', () async {
      when(() => mockDio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/workouts'),
                statusCode: 201,
                data: {},
              ));

      final notifier = container.read(workoutsNotifierProvider.notifier);
      final loggedAt = DateTime.now();

      final success = await notifier.addWorkout(
        activityType: 'Running',
        durationMin: 30,
        caloriesBurned: 350.0,
        metEstimate: 8.0,
        loggedAt: loggedAt,
        notes: 'Felt good',
      );

      expect(success, true);

      // Verify stored locally
      final workouts = await db.getWorkoutsForDay('user-123', loggedAt);
      expect(workouts.length, 1);
      expect(workouts.first.activityType, 'Running');
      expect(workouts.first.caloriesBurned, 350.0);
      expect(workouts.first.isSynced, true);

      // Verify POST call was made
      verify(() => mockDio.post<Map<String, dynamic>>('/workouts', data: any(named: 'data'))).called(1);
    });

    test('deleteWorkout removes locally and calls delete on API', () async {
      final wId = 'workout-to-delete';
      final workout = Workout(
        id: wId,
        userId: 'user-123',
        activityType: 'Cycling',
        durationMin: 45,
        caloriesBurned: 400,
        metEstimate: 7.5,
        loggedAt: DateTime.now(),
        isSynced: true,
      );

      await db.upsertWorkout(workout);

      when(() => mockDio.delete<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/workouts/$wId'),
                statusCode: 200,
                data: {},
              ));

      final notifier = container.read(workoutsNotifierProvider.notifier);
      await notifier.deleteWorkout(wId);

      // Verify deleted locally
      final workouts = await db.getWorkoutsForDay('user-123', DateTime.now());
      expect(workouts.isEmpty, true);

      // Verify DELETE API call was made
      verify(() => mockDio.delete<Map<String, dynamic>>('/workouts/$wId')).called(1);
    });

    test('syncUnsyncedWorkouts pushes unsynced logs and pulls online logs', () async {
      final loggedAt = DateTime.now();
      final workoutUnsynced = Workout(
        id: 'unsynced-1',
        userId: 'user-123',
        activityType: 'Yoga',
        durationMin: 20,
        caloriesBurned: 80,
        metEstimate: 2.5,
        loggedAt: loggedAt,
        isSynced: false,
      );

      await db.upsertWorkout(workoutUnsynced);

      // Mock post response for pushing
      when(() => mockDio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/workouts'),
                statusCode: 200,
                data: {},
              ));

      // Mock get response for pulling
      final onlineWorkout = {
        'id': 'online-1',
        'userId': 'user-123',
        'activityType': 'Swimming',
        'durationMin': 60,
        'caloriesBurned': 500,
        'metEstimate': 9.0,
        'loggedAt': loggedAt.toIso8601String(),
      };

      when(() => mockDio.get<List<dynamic>>(any()))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/workouts'),
                statusCode: 200,
                data: [onlineWorkout],
              ));

      final notifier = container.read(workoutsNotifierProvider.notifier);
      await notifier.syncUnsyncedWorkouts();

      // Verify unsynced workout is now synced
      final localUnsynced = await db.getWorkoutsForDay('user-123', loggedAt);
      final unsyncedResult = localUnsynced.firstWhere((w) => w.id == 'unsynced-1');
      expect(unsyncedResult.isSynced, true);

      // Verify online workout was fetched and saved locally
      final onlineResult = localUnsynced.firstWhere((w) => w.id == 'online-1');
      expect(onlineResult.activityType, 'Swimming');
      expect(onlineResult.caloriesBurned, 500.0);
      expect(onlineResult.isSynced, true);
    });
  });
}
