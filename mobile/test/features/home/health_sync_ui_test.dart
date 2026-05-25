import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/home/presentation/home_page.dart';
import 'package:mobile/features/home/providers/home_provider.dart';
import 'package:mobile/features/home/providers/health_provider.dart';
import 'package:mobile/features/workouts/providers/workouts_provider.dart';
import 'package:mobile/features/meals/providers/meals_provider.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';

class FakeHealthSyncNotifier extends HealthSyncNotifier {
  final HealthSyncState _initialState;
  bool syncCalled = false;

  FakeHealthSyncNotifier(this._initialState);

  @override
  HealthSyncState build() => _initialState;

  @override
  Future<void> syncHealthData() async {
    syncCalled = true;
  }
}

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return AuthState.authenticated(id: 'user-123', email: 'test@example.com', name: 'Test User');
  }
}

void main() {
  testWidgets('renders steps count, active energy and sync button correctly', (tester) async {
    final homeData = HomeData(
      userName: 'Test User',
      dailyCalorieTarget: 2000,
      bmr: 1500,
      tdee: 2000,
      proteinTarget: 150,
      carbsTarget: 200,
      fatTarget: 67,
      caloriesConsumed: 500,
      caloriesBurned: 300,
      steps: 8000,
      activeCalories: 300.0,
    );

    final fakeNotifier = FakeHealthSyncNotifier(
      const HealthSyncState(
        todaySteps: 8000,
        todayActiveCalories: 300.0,
        hasPermissions: true,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeDataProvider.overrideWith((ref) => Future.value(homeData)),
          healthSyncProvider.overrideWith(() => fakeNotifier),
          todayWorkoutsProvider.overrideWith((ref) => Stream.value([])),
          todayMealsProvider.overrideWith((ref) => Stream.value([])),
          authProvider.overrideWith(() => FakeAuthNotifier() as AuthNotifier),
        ],
        child: const MaterialApp(
          home: HomePage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Steps and Active Calories are displayed
    expect(find.text('8000'), findsOneWidget);
    expect(find.text('300 kcal'), findsOneWidget);
    expect(find.text('Steps Today'), findsOneWidget);
    expect(find.text('Active Energy'), findsOneWidget);

    // Verify Sync button is present
    final syncBtn = find.byTooltip('Sync health data');
    expect(syncBtn, findsOneWidget);

    // Tap sync button and verify notifier call
    await tester.tap(syncBtn);
    await tester.pump();

    expect(fakeNotifier.syncCalled, true);
  });
}
