import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:mobile/core/database/local_database.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/stats/providers/stats_provider.dart';

class MockLocalDatabase extends Mock implements LocalDatabase {}
class MockDio extends Mock implements Dio {}

void main() {
  late MockLocalDatabase mockDatabase;
  late MockDio mockDio;
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
      ),
    );
  });

  setUp(() {
    mockDatabase = MockLocalDatabase();
    mockDio = MockDio();

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(mockDatabase),
        dioProvider.overrideWithValue(mockDio),
        authProvider.overrideWith(() => FakeAuthNotifier() as AuthNotifier),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('StatsProvider', () {
    test('weeklyStatsProvider returns stream from database', () async {
      final mockSummaries = [
        DailySummary(
          id: 'summary-1',
          userId: 'user-123',
          date: DateTime.now(),
          totalCaloriesConsumed: 2000,
          totalCaloriesBurned: 400,
          netCalories: 1600,
          streakDay: 3,
        ),
      ];

      when(() => mockDatabase.watchWeeklySummaries(any()))
          .thenAnswer((_) => Stream.value(mockSummaries));

      final completer = Completer<List<DailySummary>>();
      container.listen<AsyncValue<List<DailySummary>>>(
        weeklyStatsProvider,
        (previous, next) {
          next.whenOrNull(
            data: (data) {
              if (!completer.isCompleted) {
                completer.complete(data);
              }
            },
          );
        },
        fireImmediately: true,
      );

      final result = await completer.future.timeout(const Duration(seconds: 5));
      expect(result, mockSummaries);
    });

    test('syncWeeklySummaries fetches backend summary logs and saves locally', () async {
      when(() => mockDatabase.upsertSummary(any())).thenAnswer((_) async {});

      final mockBackendResponse = {
        'streak': 5,
        'history': [
          {
            'date': DateTime.now().toIso8601String(),
            'totalCaloriesConsumed': 1800.0,
            'totalCaloriesBurned': 300.0,
            'netCalories': 1500.0,
          }
        ]
      };

      when(() => mockDio.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/summary/history'),
                statusCode: 200,
                data: mockBackendResponse,
              ));

      final notifier = container.read(statsNotifierProvider.notifier);
      await notifier.syncWeeklySummaries();

      verify(() => mockDio.get<Map<String, dynamic>>('/summary/history')).called(1);
      verify(() => mockDatabase.upsertSummary(any())).called(1);
    });
  });
}

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return AuthState.authenticated(id: 'user-123', email: 'test@example.com', name: 'Test User');
  }
}
