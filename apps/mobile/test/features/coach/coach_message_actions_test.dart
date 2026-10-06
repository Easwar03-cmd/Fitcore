import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revive/features/coach/widgets/coach_message_actions.dart';

void main() {
  Future<String?> openSheetAndPick(WidgetTester tester, String? reasonLabel) async {
    String? result = 'unset';
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showCoachMessageActions(context, 'Eat more protein.');
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Report response'), findsOneWidget);

    if (reasonLabel != null) {
      await tester.tap(find.text('Report response'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(reasonLabel));
    } else {
      await tester.tap(find.text('Copy'));
    }
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('reporting returns the chosen reason key', (tester) async {
    expect(await openSheetAndPick(tester, 'Harmful or unsafe advice'), 'harmful');
  });

  testWidgets('copy closes the sheet without reporting', (tester) async {
    expect(await openSheetAndPick(tester, null), isNull);
  });

  testWidgets('disclaimer tells users replies are not medical advice', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CoachDisclaimer())));
    expect(find.textContaining('not medical advice'), findsOneWidget);
    expect(find.textContaining('Long-press a reply to report it'), findsOneWidget);
  });
}
