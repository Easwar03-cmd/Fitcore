// Smoke test — verifies the app boots without crashing.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitcore/app.dart';

void main() {
  testWidgets('App boots without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FitCoreApp()));
    // App shell renders — no assertion needed beyond not throwing.
    expect(find.byType(ProviderScope), findsOneWidget);
  });
}
