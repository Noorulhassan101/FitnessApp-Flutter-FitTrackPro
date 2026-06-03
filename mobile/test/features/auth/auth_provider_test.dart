import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:drift/native.dart';

import 'package:mobile/core/database/local_database.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';

class MockDio extends Mock implements Dio {}
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}
class MockGoogleSignIn extends Mock implements GoogleSignIn {}

void main() {
  late MockDio mockDio;
  late MockFlutterSecureStorage mockStorage;
  late MockGoogleSignIn mockGoogleSignIn;
  late LocalDatabase db;
  late ProviderContainer container;

  setUp(() {
    mockDio = MockDio();
    mockStorage = MockFlutterSecureStorage();
    mockGoogleSignIn = MockGoogleSignIn();
    db = LocalDatabase(NativeDatabase.memory());

    container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(mockDio),
        secureStorageProvider.overrideWithValue(mockStorage),
        googleSignInProvider.overrideWithValue(mockGoogleSignIn),
        databaseProvider.overrideWithValue(db),
      ],
    );

    // Stub secure storage defaults
    when(() => mockStorage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
    when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});
    when(() => mockStorage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
  });

  tearDown(() async {
    await db.close();
    container.dispose();
  });

  group('AuthNotifier', () {
    test('checkSession when no access token defaults to unauthenticated', () async {
      final notifier = container.read(authProvider.notifier);
      await notifier.checkSession();

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
    });

    test('checkSession when profile fetch fails defaults to unauthenticated', () async {
      when(() => mockStorage.read(key: 'accessToken')).thenAnswer((_) async => 'token-123');
      when(() => mockDio.get<Map<String, dynamic>>('/user/profile'))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '/user/profile')));

      final notifier = container.read(authProvider.notifier);
      await notifier.checkSession();

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
    });

    test('checkSession when onboarding incomplete sets onboardingRequired', () async {
      when(() => mockStorage.read(key: 'accessToken')).thenAnswer((_) async => 'token-123');
      when(() => mockDio.get<Map<String, dynamic>>('/user/profile'))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/user/profile'),
                statusCode: 200,
                data: {
                  'id': 'user-123',
                  'email': 'test@example.com',
                  'name': 'Test User',
                  'age': null, // incomplete onboarding
                },
              ));

      final notifier = container.read(authProvider.notifier);
      await notifier.checkSession();

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.onboardingRequired);
      expect(state.userId, 'user-123');
    });

    test('checkSession when onboarding complete sets authenticated', () async {
      when(() => mockStorage.read(key: 'accessToken')).thenAnswer((_) async => 'token-123');
      when(() => mockDio.get<Map<String, dynamic>>('/user/profile'))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/user/profile'),
                statusCode: 200,
                data: {
                  'id': 'user-123',
                  'email': 'test@example.com',
                  'name': 'Test User',
                  'age': 25,
                  'heightCm': 180.0,
                  'weightKg': 75.0,
                  'fitnessGoal': 'maintain',
                },
              ));

      final notifier = container.read(authProvider.notifier);
      await notifier.checkSession();

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.userId, 'user-123');
    });

    test('register success stores tokens and sets onboardingRequired', () async {
      when(() => mockDio.post<Map<String, dynamic>>('/auth/register', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/auth/register'),
                statusCode: 200,
                data: {
                  'accessToken': 'access-token',
                  'refreshToken': 'refresh-token',
                  'user': {'id': 'user-123'},
                },
              ));

      final notifier = container.read(authProvider.notifier);
      final success = await notifier.register(
        name: 'Test',
        email: 'test@example.com',
        password: 'password',
      );

      expect(success, true);
      final state = container.read(authProvider);
      expect(state.status, AuthStatus.onboardingRequired);
      verify(() => mockStorage.write(key: 'accessToken', value: 'access-token')).called(1);
    });

    test('login success sets authenticated when user details complete', () async {
      when(() => mockDio.post<Map<String, dynamic>>('/auth/login', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/auth/login'),
                statusCode: 200,
                data: {
                  'accessToken': 'access-token',
                  'refreshToken': 'refresh-token',
                  'user': {
                    'id': 'user-123',
                    'email': 'test@example.com',
                    'name': 'Test',
                    'age': 25,
                    'heightCm': 180.0,
                    'weightKg': 75.0,
                    'fitnessGoal': 'maintain',
                  },
                },
              ));

      final notifier = container.read(authProvider.notifier);
      final success = await notifier.login(email: 'test@example.com', password: 'password');

      expect(success, true);
      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticated);
    });

    test('logout deletes tokens and sets unauthenticated', () async {
      when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async => null);

      final notifier = container.read(authProvider.notifier);
      await notifier.logout();

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
      verify(() => mockStorage.delete(key: 'accessToken')).called(1);
      verify(() => mockStorage.delete(key: 'refreshToken')).called(1);
    });
  });
}
