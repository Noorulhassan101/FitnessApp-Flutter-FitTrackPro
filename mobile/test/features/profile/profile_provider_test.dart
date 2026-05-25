import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:mobile/core/database/local_database.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/profile/providers/profile_provider.dart';

class MockLocalDatabase extends Mock implements LocalDatabase {}
class MockDio extends Mock implements Dio {}

void main() {
  late MockLocalDatabase mockDatabase;
  late MockDio mockDio;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(DateTime.now());
    registerFallbackValue(
      User(
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
        createdAt: DateTime.now(),
        unitPreference: 'metric',
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

  group('ProfileProvider', () {
    test('profileProvider returns stream from database', () async {
      final mockUser = User(
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
        createdAt: DateTime.now(),
        unitPreference: 'metric',
      );

      when(() => mockDatabase.watchUser(any()))
          .thenAnswer((_) => Stream.value(mockUser));

      final completer = Completer<User?>();
      container.listen<AsyncValue<User?>>(
        profileProvider,
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
      expect(result, mockUser);
    });

    test('syncProfile fetches backend profile logs and saves locally', () async {
      when(() => mockDatabase.upsertUser(any())).thenAnswer((_) async {});

      final mockBackendResponse = {
        'id': 'user-123',
        'email': 'test@example.com',
        'name': 'Synced User',
        'age': 30,
        'gender': 'Male',
        'heightCm': 180.0,
        'weightKg': 75.0,
        'fitnessGoal': 'maintenance',
        'unitPreference': 'metric',
        'createdAt': DateTime.now().toIso8601String(),
      };

      when(() => mockDio.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/user/profile'),
                statusCode: 200,
                data: mockBackendResponse,
              ));

      final notifier = container.read(profileNotifierProvider.notifier);
      await notifier.syncProfile();

      verify(() => mockDio.get<Map<String, dynamic>>('/user/profile')).called(1);
      verify(() => mockDatabase.upsertUser(any())).called(1);
    });

    test('updateProfile patches profile data and updates database cache', () async {
      when(() => mockDatabase.upsertUser(any())).thenAnswer((_) async {});

      final mockBackendResponse = {
        'id': 'user-123',
        'email': 'test@example.com',
        'name': 'Updated Name',
        'age': 28,
        'gender': 'Male',
        'heightCm': 175.0,
        'weightKg': 70.0,
        'fitnessGoal': 'maintenance',
        'unitPreference': 'metric',
        'createdAt': DateTime.now().toIso8601String(),
      };

      when(() => mockDio.patch<Map<String, dynamic>>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/user/profile'),
                statusCode: 200,
                data: mockBackendResponse,
              ));

      final notifier = container.read(profileNotifierProvider.notifier);
      final success = await notifier.updateProfile(
        name: 'Updated Name',
        gender: 'Male',
        age: 28,
        heightCm: 175.0,
        weightKg: 70.0,
        unitPreference: 'metric',
        activityLevel: 'Moderately Active',
        fitnessGoal: 'maintenance',
      );

      expect(success, true);
      verify(() => mockDio.patch<Map<String, dynamic>>('/user/profile', data: any(named: 'data'))).called(1);
      verify(() => mockDatabase.upsertUser(any())).called(1);
    });
  });
}

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return AuthState.authenticated(id: 'user-123', email: 'test@example.com', name: 'Test User');
  }
}
