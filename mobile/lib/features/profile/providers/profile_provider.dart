import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:mobile/core/database/local_database.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/home/providers/home_provider.dart';

final profileProvider = StreamProvider<User?>((ref) {
  final db = ref.watch(databaseProvider);
  final authState = ref.watch(authProvider);
  final userId = authState.userId;
  if (userId == null) return Stream.value(null);
  return db.watchUser(userId);
});

final profileNotifierProvider = NotifierProvider<ProfileNotifier, void>(() {
  return ProfileNotifier();
});

class ProfileNotifier extends Notifier<void> {
  @override
  void build() {
    return;
  }

  Future<void> syncProfile() async {
    final db = ref.read(databaseProvider);
    final dio = ref.read(dioProvider);
    final authState = ref.read(authProvider);
    final userId = authState.userId;

    if (userId == null) return;

    try {
      final response = await dio.get<Map<String, dynamic>>('/user/profile');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final user = User(
          id: data['id'] as String,
          email: data['email'] as String,
          name: data['name'] as String?,
          age: data['age'] as int?,
          gender: data['gender'] as String?,
          heightCm: (data['heightCm'] as num?)?.toDouble(),
          weightKg: (data['weightKg'] as num?)?.toDouble(),
          fitnessGoal: data['fitnessGoal'] as String?,
          unitPreference: data['unitPreference'] as String? ?? 'metric',
          createdAt: data['createdAt'] != null
              ? DateTime.parse(data['createdAt'] as String)
              : DateTime.now(),
        );

        await db.upsertUser(user);
      }
    } on DioException {
      // Fail silently (offline mode)
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String gender,
    required int age,
    required double heightCm,
    required double weightKg,
    required String unitPreference,
    required String activityLevel,
    required String fitnessGoal,
  }) async {
    final db = ref.read(databaseProvider);
    final dio = ref.read(dioProvider);
    final authState = ref.read(authProvider);
    final userId = authState.userId;

    if (userId == null) return false;

    try {
      final response = await dio.patch<Map<String, dynamic>>('/user/profile', data: {
        'name': name,
        'gender': gender,
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'unitPreference': unitPreference,
        'activityLevel': activityLevel,
        'fitnessGoal': fitnessGoal,
      });

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final user = User(
          id: data['id'] as String,
          email: data['email'] as String,
          name: data['name'] as String?,
          age: data['age'] as int?,
          gender: data['gender'] as String?,
          heightCm: (data['heightCm'] as num?)?.toDouble(),
          weightKg: (data['weightKg'] as num?)?.toDouble(),
          fitnessGoal: data['fitnessGoal'] as String?,
          unitPreference: data['unitPreference'] as String? ?? 'metric',
          createdAt: data['createdAt'] != null
              ? DateTime.parse(data['createdAt'] as String)
              : DateTime.now(),
        );

        await db.upsertUser(user);

        // Invalidate homeDataProvider to refresh dashboard state in real-time
        ref.invalidate(homeDataProvider);
        return true;
      }
    } on DioException {
      // Return false if failed (e.g. server error or offline)
    }
    return false;
  }
}
