import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/database/local_database.dart';
import 'package:mobile/features/profile/presentation/profile_page.dart';
import 'package:mobile/features/profile/providers/profile_provider.dart';
import 'package:mobile/features/notifications/providers/notification_provider.dart';

class FakeProfileNotifier extends ProfileNotifier {
  @override
  void build() {}
  @override
  Future<void> syncProfile() async {}
}

class FakeNotificationSettingsNotifier extends NotificationSettingsNotifier {
  final NotificationSettingsState initialState;

  FakeNotificationSettingsNotifier(this.initialState);

  bool breakfastReminderToggled = false;
  bool requestPermissionsCalled = false;
  bool breakfastTimeUpdated = false;

  @override
  NotificationSettingsState build() {
    return initialState;
  }

  @override
  Future<void> _loadSettings() async {}

  @override
  Future<void> _saveSettings() async {}

  @override
  Future<void> updateBreakfastReminder(bool enabled) async {
    breakfastReminderToggled = true;
    state = state.copyWith(breakfastReminder: enabled);
  }

  @override
  Future<void> updateBreakfastTime(int hour, int minute) async {
    breakfastTimeUpdated = true;
    state = state.copyWith(breakfastHour: hour, breakfastMinute: minute);
  }

  @override
  Future<void> requestPermissions() async {
    requestPermissionsCalled = true;
    state = state.copyWith(permissionGranted: true);
  }
}

void main() {
  late FakeProfileNotifier fakeProfileNotifier;
  late FakeNotificationSettingsNotifier fakeNotificationSettingsNotifier;

  setUp(() {
    fakeProfileNotifier = FakeProfileNotifier();
  });

  Widget buildTestableWidget({
    required User user,
    required NotificationSettingsState settingsState,
  }) {
    fakeNotificationSettingsNotifier = FakeNotificationSettingsNotifier(settingsState);

    return ProviderScope(
      overrides: [
        profileNotifierProvider.overrideWith(() => fakeProfileNotifier),
        profileProvider.overrideWith((ref) => Stream.value(user)),
        notificationSettingsProvider.overrideWith(() => fakeNotificationSettingsNotifier),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const ProfilePage(),
      ),
    );
  }

  testWidgets('renders reminders and settings card', (tester) async {
    final mockUser = User(
      id: 'user-123',
      email: 'test@example.com',
      name: 'John Doe',
      age: 30,
      gender: 'Male',
      heightCm: 180.0,
      weightKg: 80.0,
      fitnessGoal: 'maintain',
      unitPreference: 'metric',
      createdAt: DateTime.now(),
    );

    const initialSettings = NotificationSettingsState(
      breakfastReminder: true,
      breakfastHour: 8,
      breakfastMinute: 0,
      lunchReminder: true,
      lunchHour: 13,
      lunchMinute: 0,
      dinnerReminder: true,
      dinnerHour: 19,
      dinnerMinute: 0,
      dailySummaryReminder: true,
      dailySummaryHour: 21,
      dailySummaryMinute: 0,
      permissionGranted: false,
    );

    await tester.pumpWidget(buildTestableWidget(
      user: mockUser,
      settingsState: initialSettings,
    ));
    await tester.pumpAndSettle();

    // Verify Reminders & Settings header is visible
    expect(find.text('Reminders & Settings'), findsOneWidget);

    // Verify reminder rows are visible
    expect(find.text('Breakfast Reminder'), findsOneWidget);
    expect(find.text('Lunch Reminder'), findsOneWidget);
    expect(find.text('Dinner Reminder'), findsOneWidget);
    expect(find.text('Daily Summary'), findsOneWidget);

    // Verify warning banner for disabled permission is visible
    expect(find.text('Notifications are disabled. Enable reminders to stay on track!'), findsOneWidget);

    // Verify time text is formatted correctly (8:00 AM)
    expect(find.text('8:00 AM'), findsOneWidget);
    expect(find.text('1:00 PM'), findsOneWidget);
  });

  testWidgets('toggling switch updates reminder settings', (tester) async {
    final mockUser = User(
      id: 'user-123',
      email: 'test@example.com',
      name: 'John Doe',
      age: 30,
      gender: 'Male',
      heightCm: 180.0,
      weightKg: 80.0,
      fitnessGoal: 'maintain',
      unitPreference: 'metric',
      createdAt: DateTime.now(),
    );

    const initialSettings = NotificationSettingsState(
      breakfastReminder: true,
      breakfastHour: 8,
      breakfastMinute: 0,
      lunchReminder: true,
      lunchHour: 13,
      lunchMinute: 0,
      dinnerReminder: true,
      dinnerHour: 19,
      dinnerMinute: 0,
      dailySummaryReminder: true,
      dailySummaryHour: 21,
      dailySummaryMinute: 0,
      permissionGranted: true,
    );

    await tester.pumpWidget(buildTestableWidget(
      user: mockUser,
      settingsState: initialSettings,
    ));
    await tester.pumpAndSettle();

    // Find the breakfast switch
    final switchFinder = find.descendant(
      of: find.ancestor(
        of: find.text('Breakfast Reminder'),
        matching: find.byType(Row),
      ),
      matching: find.byType(Switch),
    );

    expect(switchFinder, findsOneWidget);
    await tester.ensureVisible(switchFinder);
    await tester.pumpAndSettle();
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(fakeNotificationSettingsNotifier.breakfastReminderToggled, true);
  });

  testWidgets('tapping permission enable button requests permission', (tester) async {
    final mockUser = User(
      id: 'user-123',
      email: 'test@example.com',
      name: 'John Doe',
      age: 30,
      gender: 'Male',
      heightCm: 180.0,
      weightKg: 80.0,
      fitnessGoal: 'maintain',
      unitPreference: 'metric',
      createdAt: DateTime.now(),
    );

    const initialSettings = NotificationSettingsState(
      breakfastReminder: true,
      breakfastHour: 8,
      breakfastMinute: 0,
      lunchReminder: true,
      lunchHour: 13,
      lunchMinute: 0,
      dinnerReminder: true,
      dinnerHour: 19,
      dinnerMinute: 0,
      dailySummaryReminder: true,
      dailySummaryHour: 21,
      dailySummaryMinute: 0,
      permissionGranted: false,
    );

    await tester.pumpWidget(buildTestableWidget(
      user: mockUser,
      settingsState: initialSettings,
    ));
    await tester.pumpAndSettle();

    final enableButton = find.text('Enable');
    expect(enableButton, findsOneWidget);
    await tester.ensureVisible(enableButton);
    await tester.pumpAndSettle();
    await tester.tap(enableButton);
    await tester.pumpAndSettle();

    expect(fakeNotificationSettingsNotifier.requestPermissionsCalled, true);
  });
}
