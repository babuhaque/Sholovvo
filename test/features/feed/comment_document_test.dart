import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/data/models/comment_document.dart';
import 'package:sholovvo_app/features/feed/domain/entities/comment.dart';

void main() {
  group('CommentDocument.toMap', () {
    test('writes the required fields plus postId when optionals are absent',
        () {
      final Map<String, Object?> map = CommentDocument.toMap(
        postId: 'post-1',
        authorUid: 'uid-1',
        authorName: 'Rahim',
        text: 'Great post!',
      );
      expect(map.keys.toSet(), {
        'postId',
        'authorUid',
        'authorName',
        'text',
        'createdAt',
      });
      expect(map['postId'], 'post-1');
      expect(map['authorUid'], 'uid-1');
      expect(map['authorName'], 'Rahim');
      expect(map['text'], 'Great post!');
      expect(map['createdAt'], isA<FieldValue>());
    });

    test('includes optional fields only when they have values', () {
      final Map<String, Object?> map = CommentDocument.toMap(
        postId: 'post-1',
        authorUid: 'uid-1',
        authorName: 'Rahim',
        authorPhotoUrl: 'https://x.com/p.jpg',
        text: 'Hi',
        parentId: 'comment-1',
        replyToName: 'Ayesha',
      );
      expect(map['authorPhotoUrl'], 'https://x.com/p.jpg');
      expect(map['parentId'], 'comment-1');
      expect(map['replyToName'], 'Ayesha');
    });

    test('omits blank optional fields', () {
      final Map<String, Object?> map = CommentDocument.toMap(
        postId: 'post-1',
        authorUid: 'uid-1',
        authorName: 'Rahim',
        authorPhotoUrl: '   ',
        text: 'Hi',
        parentId: '',
      );
      expect(map.containsKey('authorPhotoUrl'), isFalse);
      expect(map.containsKey('parentId'), isFalse);
      expect(map.containsKey('replyToName'), isFalse);
    });
  });

  group('CommentDocument.fromMap', () {
    final Timestamp ts = Timestamp.fromDate(DateTime.utc(2026, 10, 20, 12));

    Map<String, Object?> makeValid({Map<String, Object?>? override}) {
      return <String, Object?>{
        'authorUid': 'uid-1',
        'authorName': 'Rahim',
        'text': 'Nice!',
        'createdAt': ts,
        ...?override,
      };
    }

    test('reads a valid comment', () {
      final Result<Comment> r = CommentDocument.fromMap('c-1', makeValid());
      expect(r, isA<Success<Comment>>());
      final Comment c = (r as Success<Comment>).value;
      expect(c.id, 'c-1');
      expect(c.authorUid, 'uid-1');
      expect(c.authorName, 'Rahim');
      expect(c.text, 'Nice!');
      expect(c.createdAt, ts.toDate().toUtc());
      expect(c.parentId, isNull);
    });

    test('reads optional fields', () {
      final Result<Comment> r = CommentDocument.fromMap('c-2', makeValid(
        override: {
          'authorPhotoUrl': 'https://x.com/p.jpg',
          'parentId': 'c-1',
          'replyToName': 'Ayesha',
        },
      ));
      final Comment c = (r as Success<Comment>).value;
      expect(c.authorPhotoUrl, 'https://x.com/p.jpg');
      expect(c.parentId, 'c-1');
      expect(c.replyToName, 'Ayesha');
      expect(c.isReply, isTrue);
    });

    test('refuses missing authorUid', () {
      final Result<Comment> r = CommentDocument.fromMap(
        'c-1',
        makeValid(override: {'authorUid': null}),
      );
      expect(r, isA<FailureResult<Comment>>());
    });

    test('refuses missing createdAt', () {
      final Result<Comment> r = CommentDocument.fromMap(
        'c-1',
        makeValid(override: {'createdAt': 'not-a-timestamp'}),
      );
      expect(r, isA<FailureResult<Comment>>());
    });

    test('refuses empty text', () {
      final Result<Comment> r = CommentDocument.fromMap(
        'c-1',
        makeValid(override: {'text': ''}),
      );
      expect(r, isA<FailureResult<Comment>>());
    });
  });
}
