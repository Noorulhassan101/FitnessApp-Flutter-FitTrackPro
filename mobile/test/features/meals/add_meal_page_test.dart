import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/meals/presentation/add_meal_page.dart';
import 'package:mobile/features/meals/providers/meals_provider.dart';

class FakeMealsNotifier extends MealsNotifier {
  bool addMealCalled = false;
  String? lastMealCategory;
  String? lastFoodName;
  double? lastCaloriesConsumed;

  @override
  void build() {}

  @override
  Future<bool> addMeal({
    required String mealCategory,
    required String foodName,
    required double caloriesConsumed,
    required DateTime loggedAt,
  }) async {
    addMealCalled = true;
    lastMealCategory = mealCategory;
    lastFoodName = foodName;
    lastCaloriesConsumed = caloriesConsumed;
    return true;
  }
}

void main() {
  late FakeMealsNotifier fakeNotifier;

  setUp(() {
    fakeNotifier = FakeMealsNotifier();
  });

  Widget buildTestableWidget() {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/add-meal',
          builder: (context, state) => const AddMealPage(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        mealsNotifierProvider.overrideWith(() => fakeNotifier as MealsNotifier),
      ],
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  testWidgets('renders all inputs and selectors', (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    tester.element(find.byType(Scaffold)).push('/add-meal');
    await tester.pumpAndSettle();

    expect(find.text('Log Meal'), findsWidgets); // Title and button
    expect(find.text('Select Category'), findsOneWidget);
    expect(find.text('Food Name'), findsOneWidget);
    expect(find.text('Calories (kcal)'), findsOneWidget);
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('Snack'), findsOneWidget);
  });

  testWidgets('shows validation error when food name is empty', (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    tester.element(find.byType(Scaffold)).push('/add-meal');
    await tester.pumpAndSettle();

    // Scroll to and click Log Meal button
    final logButton = find.byType(ElevatedButton);
    await tester.ensureVisible(logButton);
    await tester.tap(logButton);
    await tester.pumpAndSettle();

    expect(find.text('Please enter a food name'), findsOneWidget);
  });

  testWidgets('increments and decrements calories correctly', (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    tester.element(find.byType(Scaffold)).push('/add-meal');
    await tester.pumpAndSettle();

    // Check initial calories value is 300
    expect(find.text('300'), findsOneWidget);

    // Tap increment (+) button
    final incrementButton = find.byIcon(Icons.add_circle_outline);
    await tester.tap(incrementButton);
    await tester.pumpAndSettle();
    expect(find.text('350'), findsOneWidget);

    // Tap decrement (-) button
    final decrementButton = find.byIcon(Icons.remove_circle_outline);
    await tester.tap(decrementButton);
    await tester.pumpAndSettle();
    expect(find.text('300'), findsOneWidget);
  });

  testWidgets('submits meal data with valid inputs', (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    tester.element(find.byType(Scaffold)).push('/add-meal');
    await tester.pumpAndSettle();

    // Enter food name
    await tester.enterText(find.byType(TextFormField).first, 'Chicken Rice');
    await tester.pumpAndSettle();

    // Tap Lunch category
    await tester.tap(find.text('Lunch'));
    await tester.pumpAndSettle();

    // Scroll to Log Meal button
    final logButton = find.byType(ElevatedButton);
    await tester.ensureVisible(logButton);
    await tester.tap(logButton);
    await tester.pumpAndSettle();

    expect(fakeNotifier.addMealCalled, true);
    expect(fakeNotifier.lastMealCategory, 'Lunch');
    expect(fakeNotifier.lastFoodName, 'Chicken Rice');
    expect(fakeNotifier.lastCaloriesConsumed, 300);
  });
}
