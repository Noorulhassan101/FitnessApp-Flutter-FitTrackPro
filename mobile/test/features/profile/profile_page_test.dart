import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/database/local_database.dart';
import 'package:mobile/features/profile/presentation/profile_page.dart';
import 'package:mobile/features/profile/providers/profile_provider.dart';

class FakeProfileNotifier extends ProfileNotifier {
  bool syncCalled = false;
  bool updateCalled = false;

  @override
  void build() {}

  @override
  Future<void> syncProfile() async {
    syncCalled = true;
  }

  @override
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
    updateCalled = true;
    return true;
  }
}

void main() {
  late FakeProfileNotifier fakeNotifier;

  setUp(() {
    fakeNotifier = FakeProfileNotifier();
  });

  Widget buildTestableWidget(User? user) {
    return ProviderScope(
      overrides: [
        profileNotifierProvider.overrideWith(() => fakeNotifier as ProfileNotifier),
        profileProvider.overrideWith((ref) => Stream.value(user)),
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

  testWidgets('renders profile fields with metric defaults', (tester) async {
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

    await tester.pumpWidget(buildTestableWidget(mockUser));
    await tester.pumpAndSettle();

    // Verify name and email render
    expect(find.text('John Doe'), findsNWidgets(2));
    expect(find.text('test@example.com'), findsOneWidget);

    // Verify inputs contain values
    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(fields[0].controller?.text, 'John Doe');
    expect(fields[1].controller?.text, '30');
    expect(fields[2].controller?.text, '180.0');
    expect(fields[3].controller?.text, '80.0');

    // BMR & TDEE Live calculations verification
    // Mifflin-St Jeor: 10 * 80 + 6.25 * 180 - 5 * 30 + 5 = 800 + 1125 - 150 + 5 = 1780
    // Moderately active TDEE: 1780 * 1.55 = 2759
    expect(find.text('1780 kcal'), findsOneWidget); // BMR
    expect(find.text('2759 kcal'), findsNWidgets(2)); // TDEE and Daily Goal (maintenance = TDEE)

    expect(fakeNotifier.syncCalled, true);
  });

  testWidgets('toggling unit preference converts values instantly', (tester) async {
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

    await tester.pumpWidget(buildTestableWidget(mockUser));
    await tester.pumpAndSettle();

    // Toggle unit preference to Imperial
    await tester.tap(find.text('Imperial'));
    await tester.pumpAndSettle();

    // Height: 180 cm / 2.54 = 70.9 inches
    // Weight: 80 kg * 2.20462 = 176.4 lbs
    final fieldsImperial = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(fieldsImperial[2].controller?.text, '70.9');
    expect(fieldsImperial[3].controller?.text, '176.4');

    // Toggle back to Metric
    await tester.tap(find.text('Metric'));
    await tester.pumpAndSettle();

    final fieldsMetric = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(double.parse(fieldsMetric[2].controller!.text), closeTo(180.0, 0.2));
    expect(double.parse(fieldsMetric[3].controller!.text), closeTo(80.0, 0.2));
  });

  testWidgets('saving updates dispatches form values', (tester) async {
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

    await tester.pumpWidget(buildTestableWidget(mockUser));
    await tester.pumpAndSettle();

    // Scroll to save button to ensure it is visible before tapping
    await tester.ensureVisible(find.text('Save Profile Settings'));
    await tester.pumpAndSettle();

    // Tap the save button
    await tester.tap(find.text('Save Profile Settings'));
    await tester.pumpAndSettle();

    expect(fakeNotifier.updateCalled, true);
  });
}
