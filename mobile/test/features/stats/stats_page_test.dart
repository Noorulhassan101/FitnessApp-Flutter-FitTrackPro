import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/database/local_database.dart';
import 'package:mobile/features/stats/presentation/stats_page.dart';
import 'package:mobile/features/stats/providers/stats_provider.dart';

class FakeStatsNotifier extends StatsNotifier {
  bool syncCalled = false;

  @override
  void build() {}

  @override
  Future<void> syncWeeklySummaries() async {
    syncCalled = true;
  }
}

void main() {
  late FakeStatsNotifier fakeNotifier;

  setUp(() {
    fakeNotifier = FakeStatsNotifier();
  });

  Widget buildTestableWidget(List<DailySummary> summaries) {
    return ProviderScope(
      overrides: [
        statsNotifierProvider.overrideWith(() => fakeNotifier as StatsNotifier),
        weeklyStatsProvider.overrideWith((ref) => Stream.value(summaries)),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const StatsPage(),
      ),
    );
  }

  testWidgets('renders empty state when no summaries are present', (tester) async {
    await tester.pumpWidget(buildTestableWidget([]));
    await tester.pumpAndSettle();

    expect(find.text('No stats logs recorded yet'), findsOneWidget);
    expect(fakeNotifier.syncCalled, true);
  });

  testWidgets('renders streak card and summaries statistics when logs are present', (tester) async {
    final mockSummaries = [
      DailySummary(
        id: 'summary-1',
        userId: 'user-123',
        date: DateTime.now().subtract(const Duration(days: 1)),
        totalCaloriesConsumed: 2000,
        totalCaloriesBurned: 500,
        netCalories: 1500,
        streakDay: 5,
      ),
    ];

    await tester.pumpWidget(buildTestableWidget(mockSummaries));
    await tester.pumpAndSettle();

    // Renders streak card title
    expect(find.text('5 Days Streak'), findsOneWidget);
    
    // Renders average calorie summaries
    expect(find.text('Avg. Calories Consumed'), findsOneWidget);
    expect(find.text('Avg. Calories Burned'), findsOneWidget);
    
    // Checks that the sync trigger was executed on load
    expect(fakeNotifier.syncCalled, true);
  });
}
