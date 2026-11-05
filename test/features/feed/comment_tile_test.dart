import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/features/feed/domain/entities/comment.dart';
import 'package:sholovvo_app/features/feed/presentation/widgets/comment_tile.dart';

import '../../support/test_app.dart';

final DateTime _stamp = DateTime.utc(2026, 11, 3, 9);

Comment _comment({
  String text = 'Great work!',
  String? parentId,
  String? replyToName,
}) {
  return Comment(
    id: 'c-1',
    authorUid: 'uid-1',
    authorName: 'Ayesha Rahman',
    text: text,
    createdAt: _stamp.subtract(const Duration(hours: 2)),
    parentId: parentId,
    replyToName: replyToName,
  );
}

Future<void> _pump(WidgetTester tester, Widget tile) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    testApp(
      home: Scaffold(
        body: SizedBox(width: 360, child: tile),
      ),
    ),
  );
}

void main() {
  group('CommentTile', () {
    testWidgets('shows author name and text', (WidgetTester tester) async {
      await _pump(tester, CommentTile(comment: _comment(), now: _stamp));
      expect(find.text('Ayesha Rahman'), findsOneWidget);
      expect(find.text('Great work!'), findsOneWidget);
    });

    testWidgets('reply shows "Reply to" prefix', (WidgetTester tester) async {
      await _pump(
        tester,
        CommentTile(
          comment: _comment(parentId: 'c-0', replyToName: 'Kabir'),
          now: _stamp,
        ),
      );
      expect(find.textContaining('Reply to'), findsOneWidget);
    });

    testWidgets('onReply callback fires when Reply tapped', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await _pump(
        tester,
        CommentTile(
          comment: _comment(),
          now: _stamp,
          onReply: () => taps++,
        ),
      );
      await tester.tap(find.text('Reply'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('no Reply label when onReply is null', (
      WidgetTester tester,
    ) async {
      await _pump(tester, CommentTile(comment: _comment(), now: _stamp));
      expect(find.text('Reply'), findsNothing);
    });
  });
}
