// Smoke test — verifies the app boots without crashing.
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zenfit/app.dart';
import 'package:zenfit/core/db/app_database.dart';

void main() {
  testWidgets('App boots without crashing', (WidgetTester tester) async {
    // Override the real (file-backed) DB with an in-memory instance so the
    // test does not open background isolates or leave pending timers.
    final inMemoryDb = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(inMemoryDb),
        ],
        child: const ZenfitApp(),
      ),
    );

    expect(find.byType(ProviderScope), findsWidgets);

    // Dispose the in-memory database after the test completes.
    addTearDown(inMemoryDb.close);
  });
}
