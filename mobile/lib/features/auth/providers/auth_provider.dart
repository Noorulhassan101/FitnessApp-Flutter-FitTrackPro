import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:drift/drift.dart' as drift;
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/database/local_database.dart';

enum AuthStatus { initial, unauthenticated, authenticated, onboardingRequired, loading }

class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? email;
  final String? name;
  final String? errorMessage;

  AuthState({
    required this.status,
    this.userId,
    this.email,
    this.name,
    this.errorMessage,
  });

  factory AuthState.initial() => AuthState(status: AuthStatus.initial);
  factory AuthState.unauthenticated({String? error}) => AuthState(status: AuthStatus.unauthenticated, errorMessage: error);
  factory AuthState.authenticated({String? id, String? email, String? name}) => AuthState(status: AuthStatus.authenticated, userId: id, email: email, name: name);
  factory AuthState.onboardingRequired({String? id, String? email, String? name}) => AuthState(status: AuthStatus.onboardingRequired, userId: id, email: email, name: name);
  factory AuthState.loading() => AuthState(status: AuthStatus.loading);
}

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn.instance;
});

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Session check is run asynchronously on construction
    Future.microtask(() => checkSession());
    return AuthState.initial();
  }

  Future<void> checkSession() async {
    final storage = ref.read(secureStorageProvider);
    final dio = ref.read(dioProvider);
    final db = ref.read(databaseProvider);

    final accessToken = await storage.read(key: 'accessToken');
    if (accessToken == null) {
      state = AuthState.unauthenticated();
      return;
    }

    try {
      final response = await dio.get<Map<String, dynamic>>('/user/profile');
      final userData = response.data!;
      final userId = userData['id'] as String;
      final email = userData['email'] as String;
      final name = userData['name'] as String?;

      // Check if onboarding is completed
      final age = userData['age'] as int?;
      final height = (userData['heightCm'] as num?)?.toDouble();
      final weight = (userData['weightKg'] as num?)?.toDouble();
      final fitnessGoal = userData['fitnessGoal'] as String?;

      // Sync into Drift database
      await db.into(db.users).insertOnConflictUpdate(
        UsersCompanion(
          id: drift.Value(userId),
          email: drift.Value(email),
          name: drift.Value(name),
          age: drift.Value(age),
          gender: drift.Value(userData['gender'] as String?),
          heightCm: drift.Value(height),
          weightKg: drift.Value(weight),
          fitnessGoal: drift.Value(fitnessGoal),
          unitPreference: drift.Value(userData['unitPreference'] as String? ?? 'metric'),
        ),
      );

      if (age == null || height == null || weight == null || fitnessGoal == null) {
        state = AuthState.onboardingRequired(id: userId, email: email, name: name);
      } else {
        state = AuthState.authenticated(id: userId, email: email, name: name);
      }
    } catch (e) {
      state = AuthState.unauthenticated();
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = AuthState.loading();
    final dio = ref.read(dioProvider);
    final storage = ref.read(secureStorageProvider);

    try {
      final response = await dio.post<Map<String, dynamic>>('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
      });

      final data = response.data!;
      final accessToken = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String;
      final userId = (data['user'] as Map<String, dynamic>)['id'] as String;

      await storage.write(key: 'accessToken', value: accessToken);
      await storage.write(key: 'refreshToken', value: refreshToken);

      state = AuthState.onboardingRequired(id: userId, email: email, name: name);
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data['message'] as String? ?? 'Registration failed';
      state = AuthState.unauthenticated(error: msg);
      return false;
    } catch (e) {
      state = AuthState.unauthenticated(error: 'An unexpected error occurred');
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = AuthState.loading();
    final dio = ref.read(dioProvider);
    final storage = ref.read(secureStorageProvider);

    try {
      final response = await dio.post<Map<String, dynamic>>('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final data = response.data!;
      final accessToken = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String;
      final user = data['user'] as Map<String, dynamic>;
      final userId = user['id'] as String;
      final name = user['name'] as String?;

      await storage.write(key: 'accessToken', value: accessToken);
      await storage.write(key: 'refreshToken', value: refreshToken);

      // Check if onboarding is completed
      final age = user['age'] as int?;
      final height = (user['heightCm'] as num?)?.toDouble();
      final weight = (user['weightKg'] as num?)?.toDouble();
      final fitnessGoal = user['fitnessGoal'] as String?;

      if (age == null || height == null || weight == null || fitnessGoal == null) {
        state = AuthState.onboardingRequired(id: userId, email: email, name: name);
      } else {
        state = AuthState.authenticated(id: userId, email: email, name: name);
      }
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data['message'] as String? ?? 'Login failed';
      state = AuthState.unauthenticated(error: msg);
      return false;
    } catch (e) {
      state = AuthState.unauthenticated(error: 'An unexpected error occurred');
      return false;
    }
  }

  bool _googleSignInInitialized = false;

  Future<bool> googleSignIn() async {
    state = AuthState.loading();
    final GoogleSignIn googleSignIn = ref.read(googleSignInProvider);
    final dio = ref.read(dioProvider);
    final storage = ref.read(secureStorageProvider);

    if (!_googleSignInInitialized) {
      await googleSignIn.initialize(
        serverClientId: '156107535041-8eqlpfkv02ttf5lvkoeg599uq2ceabbj.apps.googleusercontent.com',
      );
      _googleSignInInitialized = true;
    }

    try {
      final GoogleSignInAccount? account = await googleSignIn.authenticate();
      if (account == null) {
        // User cancelled the sign-in dialog
        state = AuthState.unauthenticated(error: 'Google Sign-In was cancelled.');
        return false;
      }

      // IMPORTANT: authentication must be awaited to get the idToken
      final GoogleSignInAuthentication authentication = await account.authentication;
      final idToken = authentication.idToken;

      if (idToken == null) {
        state = AuthState.unauthenticated(
          error: 'Google Sign-In failed: could not retrieve ID token. '
              'Ensure Google Sign-In is enabled in Firebase Console.',
        );
        return false;
      }

      final response = await dio.post<Map<String, dynamic>>('/auth/google', data: {
        'idToken': idToken,
        'email': account.email,
        'name': account.displayName,
      });

      final data = response.data!;
      final accessToken = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String;
      final user = data['user'] as Map<String, dynamic>;
      final userId = user['id'] as String;
      final name = user['name'] as String?;
      final email = user['email'] as String;

      await storage.write(key: 'accessToken', value: accessToken);
      await storage.write(key: 'refreshToken', value: refreshToken);

      final age = user['age'] as int?;
      final height = (user['heightCm'] as num?)?.toDouble();
      final weight = (user['weightKg'] as num?)?.toDouble();
      final fitnessGoal = user['fitnessGoal'] as String?;

      if (age == null || height == null || weight == null || fitnessGoal == null) {
        state = AuthState.onboardingRequired(id: userId, email: email, name: name);
      } else {
        state = AuthState.authenticated(id: userId, email: email, name: name);
      }
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data['message'] as String? ?? 'Google Sign-In failed';
      state = AuthState.unauthenticated(error: msg);
      return false;
    } catch (e) {
      state = AuthState.unauthenticated(error: 'Google Sign-In error: $e');
      return false;
    }
  }


  Future<bool> submitOnboarding({
    required String gender,
    required int age,
    required double heightCm,
    required double weightKg,
    required String unitPreference,
    required String activityLevel,
    required String fitnessGoal,
  }) async {
    if (state.userId == null) return false;
    
    final dio = ref.read(dioProvider);
    final db = ref.read(databaseProvider);
    final userId = state.userId!;
    final email = state.email ?? '';
    final name = state.name;

    try {
      await dio.patch<Map<String, dynamic>>('/user/profile', data: {
        'gender': gender,
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'unitPreference': unitPreference,
        'activityLevel': activityLevel,
        'fitnessGoal': fitnessGoal,
      });

      // Save to Drift database locally
      await db.into(db.users).insertOnConflictUpdate(
        UsersCompanion(
          id: drift.Value(userId),
          email: drift.Value(email),
          name: drift.Value(name),
          age: drift.Value(age),
          gender: drift.Value(gender),
          heightCm: drift.Value(heightCm),
          weightKg: drift.Value(weightKg),
          fitnessGoal: drift.Value(fitnessGoal),
          unitPreference: drift.Value(unitPreference),
        ),
      );

      state = AuthState.authenticated(id: userId, email: email, name: name);
      return true;
    } catch (e) {
      state = AuthState.onboardingRequired(
        id: state.userId,
        email: state.email,
        name: state.name,
      );
      return false;
    }
  }

  Future<void> logout() async {
    final storage = ref.read(secureStorageProvider);
    final GoogleSignIn googleSignIn = ref.read(googleSignInProvider);
    
    try {
      await googleSignIn.signOut();
    } catch (_) {}

    await storage.delete(key: 'accessToken');
    await storage.delete(key: 'refreshToken');
    state = AuthState.unauthenticated();
  }
}
