import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:mobile/core/database/local_database.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/meals/providers/meals_provider.dart';

class MockLocalDatabase extends Mock implements LocalDatabase {}
class MockDio extends Mock implements Dio {}

void main() {
  late MockLocalDatabase mockDatabase;
  late MockDio mockDio;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(DateTime.now());
    registerFallbackValue(
      Meal(
        id: '',
        userId: '',
        mealCategory: '',
        foodName: '',
        caloriesConsumed: 0.0,
        loggedAt: DateTime.now(),
        isSynced: false,
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

  group('MealsProvider', () {
    test('todayMealsProvider returns stream from database', () async {
      final mockMeals = [
        Meal(
          id: 'meal-1',
          userId: 'user-123',
          mealCategory: 'Breakfast',
          foodName: 'Oatmeal',
          caloriesConsumed: 300,
          loggedAt: DateTime.now(),
          isSynced: false,
        ),
      ];

      when(() => mockDatabase.watchMealsForDay(any(), any()))
          .thenAnswer((_) => Stream.value(mockMeals));

      final completer = Completer<List<Meal>>();
      container.listen<AsyncValue<List<Meal>>>(
        todayMealsProvider,
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
      expect(result, mockMeals);
    });

    test('addMeal saves to local database and syncs to backend', () async {
      when(() => mockDatabase.upsertMeal(any())).thenAnswer((_) async {});
      
      when(() => mockDio.post<Map<String, dynamic>>(
        any(),
        data: any(named: 'data'),
      )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/meals'),
            statusCode: 201,
            data: {'id': 'meal-1'},
          ));

      final notifier = container.read(mealsNotifierProvider.notifier);
      final success = await notifier.addMeal(
        mealCategory: 'Breakfast',
        foodName: 'Oatmeal',
        caloriesConsumed: 300,
        loggedAt: DateTime.now(),
      );

      expect(success, true);
      verify(() => mockDatabase.upsertMeal(any())).called(2);
      verify(() => mockDio.post<Map<String, dynamic>>('/meals', data: any(named: 'data'))).called(1);
    });

    test('deleteMeal deletes from local database and backend', () async {
      when(() => mockDatabase.deleteMealLocal(any())).thenAnswer((_) async => 1);
      when(() => mockDio.delete<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/meals/1'),
                statusCode: 200,
              ));

      final notifier = container.read(mealsNotifierProvider.notifier);
      await notifier.deleteMeal('meal-1');

      verify(() => mockDatabase.deleteMealLocal('meal-1')).called(1);
      verify(() => mockDio.delete<Map<String, dynamic>>('/meals/meal-1')).called(1);
    });

    test('syncUnsyncedMeals posts local unsynced and pulls remote', () async {
      final unsynced = [
        Meal(
          id: 'meal-1',
          userId: 'user-123',
          mealCategory: 'Lunch',
          foodName: 'Salad',
          caloriesConsumed: 400,
          loggedAt: DateTime.now(),
          isSynced: false,
        ),
      ];

      when(() => mockDatabase.getUnsyncedMeals()).thenAnswer((_) async => unsynced);
      when(() => mockDatabase.upsertMeal(any())).thenAnswer((_) async {});

      when(() => mockDio.post<Map<String, dynamic>>(
        any(),
        data: any(named: 'data'),
      )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/meals'),
            statusCode: 201,
          ));

      final remoteMeals = [
        {
          'id': 'meal-2',
          'userId': 'user-123',
          'mealCategory': 'Dinner',
          'foodName': 'Steak',
          'caloriesConsumed': 600.0,
          'loggedAt': DateTime.now().toIso8601String(),
        }
      ];

      when(() => mockDio.get<List<dynamic>>(any()))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/meals'),
                statusCode: 200,
                data: remoteMeals,
              ));

      final notifier = container.read(mealsNotifierProvider.notifier);
      await notifier.syncUnsyncedMeals();

      verify(() => mockDatabase.getUnsyncedMeals()).called(1);
      verify(() => mockDio.post<Map<String, dynamic>>('/meals', data: any(named: 'data'))).called(1);
      verify(() => mockDio.get<List<dynamic>>('/meals')).called(1);
      verify(() => mockDatabase.upsertMeal(any())).called(2); // 1 for marking synced, 1 for saving remote
    });
  });
}

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return AuthState.authenticated(id: 'user-123', email: 'test@example.com', name: 'Test User');
  }
}
