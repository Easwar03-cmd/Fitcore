import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revive/core/theme/app_theme.dart';
import 'package:revive/core/widgets/body_figure.dart';
import 'package:revive/core/widgets/muscle_workload_card.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(12), child: child)),
    );

void main() {
  testWidgets('shows sets for the selected muscle and updates on tap',
      (tester) async {
    MuscleKey? trained;
    await tester.pumpWidget(_wrap(MuscleWorkloadCard(
      volume: const {'shoulders': 12, 'back': 4},
      onTrain: (k) => trained = k,
    )));

    // Default selection is shoulders → 12 sets, optimal.
    expect(find.text('12 sets this week'), findsOneWidget);
    expect(find.text('Optimal'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('4 sets this week'), findsOneWidget);
    expect(find.text('Needs more work'), findsOneWidget);

    await tester.tap(find.text('Train'));
    expect(trained, MuscleKey.back);
  });

  testWidgets('is read-only without onTrain', (tester) async {
    await tester.pumpWidget(_wrap(const MuscleWorkloadCard(volume: {})));
    expect(find.text('Train'), findsNothing);
    expect(find.text('No sets yet'), findsOneWidget);
  });

  test('every muscle has a region in the view it is shown from', () {
    for (final k in MuscleKey.values) {
      expect(regionsFor(k.view).containsKey(k), isTrue, reason: k.id);
    }
  });
}
