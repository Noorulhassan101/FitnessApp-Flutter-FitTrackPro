import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/features/auth/presentation/landing_page.dart';

void main() {
  group('App', () {
    testWidgets('renders LandingPage initially', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: App(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LandingPage), findsOneWidget);
    });
  });
}
