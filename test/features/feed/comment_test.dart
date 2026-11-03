import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/features/feed/domain/entities/comment.dart';

Comment _comment({
  String text = 'Is O- still needed after 6pm?',
  String? parentId,
  String? replyToName,
}) {
  return Comment(
    id: 'comment-1',
    authorUid: 'uid-verified',
    authorName: 'Ayesha Rahman',
    text: text,
    parentId: parentId,
    replyToName: replyToName,
    createdAt: DateTime.utc(2026, 10, 20, 10),
  );
}

void main() {
  group('CommentValidator: text', () {
    test('an empty comment is refused', () {
      expect(CommentValidator.validate(text: ''), CommentIssue.textRequired);
      expect(CommentValidator.validate(text: '   '), CommentIssue.textRequired);
    });

    test('the limit itself is allowed and one character more is not', () {
      expect(CommentValidator.maxTextLength, 500);
      expect(
        CommentValidator.validate(text: 'a' * CommentValidator.maxTextLength),
        isNull,
      );
      expect(
        CommentValidator.validate(
          text: 'a' * (CommentValidator.maxTextLength + 1),
        ),
        CommentIssue.textTooLong,
      );
    });
  });

  group('CommentValidator: replies', () {
    test('a top-level comment needs no parent', () {
      expect(CommentValidator.validate(text: 'Still needed?'), isNull);
    });

    test('a reply names the comment it answers', () {
      expect(
        CommentValidator.validate(
          text: 'Yes until 8pm.',
          parentId: 'comment-0',
          replyToName: 'Rafiq Hasan',
        ),
        isNull,
      );
    });

    test('naming somebody without naming the comment is refused', () {
      // The name is what the reader sees; the id is what puts the reply in the
      // right thread. A name on its own would render an answer to nobody.
      expect(
        CommentValidator.validate(text: 'Yes until 8pm.', replyToName: 'Rafiq'),
        CommentIssue.replyWithoutParent,
      );
      expect(
        CommentValidator.validate(
          text: 'Yes until 8pm.',
          parentId: '  ',
          replyToName: 'Rafiq',
        ),
        CommentIssue.replyWithoutParent,
      );
    });

    test('a blank reply name is the same as no name', () {
      expect(
        CommentValidator.validate(text: 'Yes until 8pm.', replyToName: '   '),
        isNull,
      );
    });
  });

  group('Comment', () {
    test('knows whether it is a reply', () {
      expect(_comment().isReply, isFalse);
      expect(_comment(parentId: 'comment-0').isReply, isTrue);
    });

    test('compares by value', () {
      expect(_comment(), _comment());
      expect(_comment().hashCode, _comment().hashCode);
      expect(_comment(), isNot(_comment(parentId: 'comment-0')));
    });

    test('describes itself without quoting the comment', () {
      final Comment comment = _comment(
        text: 'A detail that should stay out of logs',
      );

      expect(comment.toString(), contains('comment-1'));
      expect(comment.toString(), isNot(contains('stay out of logs')));
    });
  });
}
