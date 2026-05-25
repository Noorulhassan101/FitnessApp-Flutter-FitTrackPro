import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:mobile/core/database/local_database.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/health/health_service.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/home/providers/health_provider.dart';

class MockLocalDatabase extends Mock implements LocalDatabase {}
class MockDio extends Mock implements Dio {}
class MockHealthService extends Mock implements HealthService {}

void main() {
  late MockLocalDatabase mockDatabase;
  late MockDio mockDio;
  late MockHealthService mockHealthService;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(DateTime.now());
    registerFallbackValue(
      DailySummary(
        id: '',
        userId: '',
        date: DateTime.now(),
        totalCaloriesConsumed: 0.0,
        totalCaloriesBurned: 0.0,
        netCalories: 0.0,
        streakDay: 0,
        steps: 0,
        activeCalories: 0.0,
      ),
    );
  });

  setUp(() {
    mockDatabase = MockLocalDatabase();
    mockDio = MockDio();
    mockHealthService = MockHealthService();

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(mockDatabase),
        dioProvider.overrideWithValue(mockDio),
        healthServiceProvider.overrideWithValue(mockHealthService),
        authProvider.overrideWith(() => FakeAuthNotifier() as AuthNotifier),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('HealthSyncProvider', () {
    test('initial state is correct', () {
      final state = container.read(healthSyncProvider);
      expect(state.isSyncing, false);
      expect(state.todaySteps, 0);
      expect(state.todayActiveCalories, 0.0);
      expect(state.hasPermissions, false);
      expect(state.errorMessage, null);
    });

    test('checkPermissions updates permission state', () async {
      when(() => mockHealthService.hasPermissions()).thenAnswer((_) async => true);

      final notifier = container.read(healthSyncProvider.notifier);
      await notifier.checkPermissions();

      final state = container.read(healthSyncProvider);
      expect(state.hasPermissions, true);
    });

    test('syncHealthData updates state, saves to database and backend', () async {
      // Stub HealthService
      when(() => mockHealthService.hasPermissions()).thenAnswer((_) async => true);
      when(() => mockHealthService.fetchStepsForDay(any())).thenAnswer((_) async => 5000);
      when(() => mockHealthService.fetchActiveCaloriesForDay(any())).thenAnswer((_) async => 250.0);

      // Stub Database
      when(() => mockDatabase.getDailySummary(any(), any())).thenAnswer((_) async => null);
      when(() => mockDatabase.getMealsForDay(any(), any())).thenAnswer((_) async => []);
      when(() => mockDatabase.getWorkoutsForDay(any(), any())).thenAnswer((_) async => []);
      when(() => mockDatabase.getUser(any())).thenAnswer((_) async => null);
      when(() => mockDatabase.upsertSummary(any())).thenAnswer((_) async {});

      // Stub Dio
      when(() => mockDio.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/user/profile'),
                statusCode: 200,
                data: {
                  'id': 'user-123',
                  'email': 'test@example.com',
                  'tdee': 2000.0,
                  'fitnessGoal': 'maintain',
                },
              ));

      when(() => mockDio.patch<dynamic>(
        any(),
        data: any(named: 'data'),
      )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/summary/sync'),
            statusCode: 200,
            data: {},
          ));

      final notifier = container.read(healthSyncProvider.notifier);
      await notifier.syncHealthData();

      final state = container.read(healthSyncProvider);
      expect(state.isSyncing, false);
      expect(state.todaySteps, 5000);
      expect(state.todayActiveCalories, 250.0);
      expect(state.hasPermissions, true);
      expect(state.errorMessage, null);

      verify(() => mockDatabase.upsertSummary(any())).called(1);
      verify(() => mockDio.patch<dynamic>(
            '/summary/sync',
            data: any(named: 'data'),
          )).called(1);
    });

    test('syncHealthData sets error if health permissions not granted', () async {
      when(() => mockHealthService.hasPermissions()).thenAnswer((_) async => false);

      final notifier = container.read(healthSyncProvider.notifier);
      await notifier.syncHealthData();

      final state = container.read(healthSyncProvider);
      expect(state.isSyncing, false);
      expect(state.hasPermissions, false);
      expect(state.errorMessage, 'Health permissions not granted.');
    });
  });
}

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return AuthState.authenticated(id: 'user-123', email: 'test@example.com', name: 'Test User');
  }
}
