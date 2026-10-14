import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revive/features/community/models/community_models.dart';
import 'package:revive/features/community/widgets/message_bubble.dart';

CommunityMessage _msg(String id, String author, String body) => CommunityMessage(
      id: id,
      kind: 'text',
      author: ChatAuthor(id: author, name: author == 'me' ? 'Me' : 'Alex'),
      createdAt: DateTime(2026, 10, 12, 9, 30),
      deleted: false,
      body: body,
    );

void main() {
  testWidgets('own messages sit right, others left, with sender names',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 600));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            MessageBubble(
              message: _msg('1', 'me', 'Hi'),
              isMine: true,
              onLongPress: () {},
            ),
            MessageBubble(
              message: _msg('2', 'alex', 'Hello there'),
              isMine: false,
              onLongPress: () {},
            ),
          ],
        ),
      ),
    ));

    final mine = tester.getRect(find.text('Hi'));
    final theirs = tester.getRect(find.text('Hello there'));
    expect(mine.center.dx, greaterThan(200)); // right half
    expect(theirs.center.dx, lessThan(200)); // left half

    // Names on top of every message.
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
  });

  testWidgets('bubble width follows the text length', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 600));
    Future<double> widthFor(String body) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: _msg('1', 'alex', body),
            isMine: false,
            onLongPress: () {},
          ),
        ),
      ));
      return tester.getSize(find.byType(IntrinsicWidth).first).width;
    }

    final short = await widthFor('Hi');
    final long = await widthFor('This is a much longer message that should '
        'make the bubble noticeably wider than a two letter one');
    expect(short, lessThan(120));
    expect(long, greaterThan(short));
  });
}
