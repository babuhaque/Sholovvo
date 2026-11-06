import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/data/models/post_document.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';

final DateTime _created = DateTime.utc(2026, 10, 20, 9);
final DateTime _edited = DateTime.utc(2026, 10, 21, 8, 30);

/// A post with every field set, so a round trip has something to lose.
Post _post({
  String? authorPhotoUrl = 'https://cdn.test/ayesha.jpg',
  List<String> imageUrls = const <String>[
    'https://cdn.test/post/1.jpg',
    'https://cdn.test/post/2.jpg',
  ],
  List<String> imagePaths = const <String>[
    'uid-author/post-1/0-1730000000000.jpg',
    'uid-author/post-1/1-1730000001000.jpg',
  ],
  DateTime? editedAt,
}) {
  return Post(
    id: 'post-1',
    authorUid: 'uid-author',
    authorName: 'Ayesha Rahman',
    authorPhotoUrl: authorPhotoUrl,
    text: 'O- needed at Dhanmondi this Friday.',
    imageUrls: imageUrls,
    imagePaths: imagePaths,
    likeCount: 3,
    commentCount: 2,
    createdAt: _created,
    updatedAt: _created,
    editedAt: editedAt,
  );
}

/// A document with only the required fields, so a test can remove exactly one
/// thing and see which issue comes back.
Map<String, dynamic> _document() {
  return <String, dynamic>{
    'authorUid': 'uid-author',
    'authorName': 'Ayesha Rahman',
    'text': 'O- needed at Dhanmondi this Friday.',
    'imageUrls': <String>[],
    'imagePaths': <String>[],
    'likeCount': 0,
    'commentCount': 0,
    'createdAt': Timestamp.fromDate(_created),
    'updatedAt': Timestamp.fromDate(_created),
  };
}

/// The issue a refused read carries, or `null` when it was accepted.
PostIssue? _issue(Result<Post> result) {
  final Failure? failure = result.failureOrNull;
  if (failure is! ValidationFailure) {
    return null;
  }
  for (final PostIssue issue in PostIssue.values) {
    if (issue.name == failure.messageKey) {
      return issue;
    }
  }
  return null;
}

void main() {
  group('PostDocument.toMap', () {
    test('writes exactly the required fields when the optionals are absent', () {
      final Map<String, Object?> fields = PostDocument.toMap(
        _post(
          authorPhotoUrl: null,
          imageUrls: const <String>[],
          imagePaths: const <String>[],
        ),
      );

      expect(fields.keys.toSet(), PostDocument.requiredFields.toSet());
      // The id is the document's address; a field repeating it could disagree.
      expect(fields.containsKey('id'), isFalse);
    });

    test('writes the optional fields only when they have a value', () {
      final Map<String, Object?> plain = PostDocument.toMap(
        _post(authorPhotoUrl: null),
      );
      final Map<String, Object?> full = PostDocument.toMap(
        _post(editedAt: _edited),
      );

      expect(plain.containsKey('authorPhotoUrl'), isFalse);
      expect(plain.containsKey('editedAt'), isFalse);
      expect(full['authorPhotoUrl'], 'https://cdn.test/ayesha.jpg');
      expect(full['editedAt'], Timestamp.fromDate(_edited));
    });

    test(
      'always writes both image lists, even when the post has no images',
      () {
        final Map<String, Object?> fields = PostDocument.toMap(
          _post(imageUrls: const <String>[], imagePaths: const <String>[]),
        );

        // A stable shape is what lets the rules require the key instead of testing
        // for its absence.
        expect(fields['imageUrls'], isEmpty);
        expect(fields['imagePaths'], isEmpty);
      },
    );

    test('writes timestamps as Firestore timestamps in UTC', () {
      final Map<String, Object?> fields = PostDocument.toMap(_post());

      // Compared as a Timestamp rather than through `toDate()`, which answers in
      // the device's zone and would make this test pass or fail by timezone.
      expect(fields['createdAt'], isA<Timestamp>());
      expect(fields['createdAt'], Timestamp.fromDate(_created));
      expect(fields['updatedAt'], Timestamp.fromDate(_created));
    });
  });

  group('PostDocument.fromMap', () {
    test('reads a document with only the required fields', () {
      final Result<Post> result = PostDocument.fromMap(
        id: 'post-1',
        data: _document(),
      );
      final Post post = result.valueOrNull!;

      expect(result.isSuccess, isTrue);
      expect(post.id, 'post-1');
      expect(post.authorUid, 'uid-author');
      expect(post.authorName, 'Ayesha Rahman');
      expect(post.authorPhotoUrl, isNull);
      expect(post.editedAt, isNull);
      expect(post.imageUrls, isEmpty);
      expect(post.likeCount, 0);
      expect(post.createdAt, _created);
      expect(post.createdAt.isUtc, isTrue);
    });

    test('survives a full round trip without changing a value', () {
      final Post original = _post(editedAt: _edited);
      final Map<String, Object?> fields = PostDocument.toMap(original);
      final Result<Post> decoded = PostDocument.fromMap(
        id: original.id,
        data: Map<String, dynamic>.from(fields),
      );

      expect(decoded.valueOrNull, original);
    });

    test('accepts a DateTime as readily as a Timestamp', () {
      final Map<String, dynamic> data = _document()
        ..['createdAt'] = _created
        ..['updatedAt'] = _created;

      expect(PostDocument.fromMap(id: 'post-1', data: data).isSuccess, isTrue);
    });

    test('normalises a local timestamp to the instant that was stored', () {
      // `Timestamp.toDate()` answers in the device's zone, and two DateTimes for
      // the same instant in different zones are not equal — so an unnormalised
      // read would make two devices disagree about an unchanged post.
      final Map<String, dynamic> data = _document()
        ..['createdAt'] = Timestamp.fromDate(_created.toLocal());

      final Post post = PostDocument.fromMap(
        id: 'post-1',
        data: data,
      ).valueOrNull!;

      expect(post.createdAt, _created);
      expect(post.createdAt.isUtc, isTrue);
    });

    test('ignores fields a later version added', () {
      final Map<String, dynamic> data = _document()
        ..['editedAt'] = null
        ..['someFutureField'] = 'ignored';

      expect(PostDocument.fromMap(id: 'post-1', data: data).isSuccess, isTrue);
    });

    test('refuses an empty document id', () {
      final Result<Post> result = PostDocument.fromMap(
        id: '  ',
        data: _document(),
      );

      expect(_issue(result), PostIssue.idMissing);
    });
  });

  group('PostDocument.fromMap: missing required fields', () {
    test('authorUid', () {
      final Map<String, dynamic> data = _document()..remove('authorUid');

      expect(
        _issue(PostDocument.fromMap(id: 'post-1', data: data)),
        PostIssue.authorUidMissing,
      );
    });

    test('a blank authorUid is the same as an absent one', () {
      final Map<String, dynamic> data = _document()..['authorUid'] = '   ';

      expect(
        _issue(PostDocument.fromMap(id: 'post-1', data: data)),
        PostIssue.authorUidMissing,
      );
    });

    test('text (absent is malformed, never an empty post)', () {
      final Map<String, dynamic> data = _document()..remove('text');

      expect(
        _issue(PostDocument.fromMap(id: 'post-1', data: data)),
        PostIssue.fieldMalformed,
      );
    });

    test('createdAt', () {
      final Map<String, dynamic> data = _document()..remove('createdAt');

      expect(
        _issue(PostDocument.fromMap(id: 'post-1', data: data)),
        PostIssue.createdAtMissing,
      );
    });

    test('updatedAt', () {
      final Map<String, dynamic> data = _document()..remove('updatedAt');

      expect(
        _issue(PostDocument.fromMap(id: 'post-1', data: data)),
        PostIssue.updatedAtMissing,
      );
    });

    test('a counter', () {
      final Map<String, dynamic> noLikes = _document()..remove('likeCount');
      final Map<String, dynamic> noComments = _document()
        ..remove('commentCount');

      expect(
        _issue(PostDocument.fromMap(id: 'post-1', data: noLikes)),
        PostIssue.fieldMalformed,
      );
      expect(
        _issue(PostDocument.fromMap(id: 'post-1', data: noComments)),
        PostIssue.fieldMalformed,
      );
    });
  });

  group('PostDocument.fromMap: malformed fields', () {
    test('a name that is not a string', () {
      final Map<String, dynamic> data = _document()..['authorName'] = 42;

      expect(
        _issue(PostDocument.fromMap(id: 'post-1', data: data)),
        PostIssue.fieldMalformed,
      );
    });

    test('a text that is not a string', () {
      final Map<String, dynamic> data = _document()..['text'] = 42;

      expect(
        _issue(PostDocument.fromMap(id: 'post-1', data: data)),
        PostIssue.fieldMalformed,
      );
    });

    test('an image list that is not a list', () {
      final Map<String, dynamic> data = _document()..['imageUrls'] = 'a.jpg';

      expect(
        _issue(PostDocument.fromMap(id: 'post-1', data: data)),
        PostIssue.fieldMalformed,
      );
    });

    test('an image entry that is not a usable string', () {
      // Dropping the entry would silently lose an image the donor attached.
      final Map<String, dynamic> notString = _document()
        ..['imageUrls'] = <Object?>['https://cdn.test/1.jpg', 7];
      final Map<String, dynamic> blank = _document()
        ..['imageUrls'] = <String>['https://cdn.test/1.jpg', ' '];

      expect(
        _issue(PostDocument.fromMap(id: 'post-1', data: notString)),
        PostIssue.fieldMalformed,
      );
      expect(
        _issue(PostDocument.fromMap(id: 'post-1', data: blank)),
        PostIssue.fieldMalformed,
      );
    });

    test('a counter that is not an integer', () {
      final Map<String, dynamic> data = _document()..['likeCount'] = 3.5;

      expect(
        _issue(PostDocument.fromMap(id: 'post-1', data: data)),
        PostIssue.fieldMalformed,
      );
    });

    test('a negative counter', () {
      final Map<String, dynamic> data = _document()..['likeCount'] = -2;

      expect(
        _issue(PostDocument.fromMap(id: 'post-1', data: data)),
        PostIssue.counterNegative,
      );
    });

    test('a timestamp that is not a timestamp', () {
      final Map<String, dynamic> data = _document()
        ..['createdAt'] = '2026-10-20T09:00:00Z';

      expect(
        _issue(PostDocument.fromMap(id: 'post-1', data: data)),
        PostIssue.fieldMalformed,
      );
    });

    test('an optional field of the wrong type is refused, not ignored', () {
      final Map<String, dynamic> badPhoto = _document()
        ..['authorPhotoUrl'] = 12;
      final Map<String, dynamic> badEdit = _document()
        ..['editedAt'] = 'yesterday';

      expect(
        _issue(PostDocument.fromMap(id: 'post-1', data: badPhoto)),
        PostIssue.fieldMalformed,
      );
      expect(
        _issue(PostDocument.fromMap(id: 'post-1', data: badEdit)),
        PostIssue.fieldMalformed,
      );
    });

    test('a blank optional string reads as absent', () {
      final Map<String, dynamic> data = _document()..['authorPhotoUrl'] = '   ';

      expect(
        PostDocument.fromMap(
          id: 'post-1',
          data: data,
        ).valueOrNull!.authorPhotoUrl,
        isNull,
      );
    });
  });

  group('PostDocument.fromMap: boundaries', () {
    test('no images and five images are accepted', () {
      final Map<String, dynamic> none = _document();
      final Map<String, dynamic> five = _document()
        ..['imageUrls'] = List<String>.generate(
          5,
          (int i) => 'https://cdn.test/$i.jpg',
        )
        ..['imagePaths'] = List<String>.generate(
          5,
          (int i) => 'uid-author/post-1/$i.jpg',
        );

      expect(PostDocument.fromMap(id: 'post-1', data: none).isSuccess, isTrue);
      expect(PostDocument.fromMap(id: 'post-1', data: five).isSuccess, isTrue);
    });

    test('six images are refused', () {
      final Map<String, dynamic> data = _document()
        ..['imageUrls'] = List<String>.generate(
          6,
          (int i) => 'https://cdn.test/$i.jpg',
        );

      expect(
        _issue(PostDocument.fromMap(id: 'post-1', data: data)),
        PostIssue.tooManyImages,
      );
    });

    test('six storage paths are refused even with no URLs', () {
      final Map<String, dynamic> data = _document()
        ..['imagePaths'] = List<String>.generate(
          6,
          (int i) => 'uid-author/post-1/$i.jpg',
        );

      expect(
        _issue(PostDocument.fromMap(id: 'post-1', data: data)),
        PostIssue.tooManyImagePaths,
      );
    });

    test('more paths than URLs is refused', () {
      final Map<String, dynamic> data = _document()
        ..['imageUrls'] = <String>['https://cdn.test/1.jpg']
        ..['imagePaths'] = <String>[
          'uid-author/post-1/1.jpg',
          'uid-author/post-1/2.jpg',
        ];

      expect(
        _issue(PostDocument.fromMap(id: 'post-1', data: data)),
        PostIssue.tooManyImagePaths,
      );
    });

    test('text at the limit is accepted and one over is refused', () {
      final Map<String, dynamic> atLimit = _document()
        ..['text'] = 'a' * PostValidator.maxTextLength;
      final Map<String, dynamic> overLimit = _document()
        ..['text'] = 'a' * (PostValidator.maxTextLength + 1);
      final Map<String, dynamic> blank = _document()..['text'] = '   ';

      expect(
        PostDocument.fromMap(id: 'post-1', data: atLimit).isSuccess,
        isTrue,
      );
      expect(
        _issue(PostDocument.fromMap(id: 'post-1', data: overLimit)),
        PostIssue.textTooLong,
      );
      expect(
        _issue(PostDocument.fromMap(id: 'post-1', data: blank)),
        PostIssue.textRequired,
      );
    });
  });

  group('PostDocument failure reporting', () {
    test('carries a validation failure with the issue as its key', () {
      final Map<String, dynamic> data = _document()..remove('authorUid');
      final Failure failure = PostDocument.fromMap(
        id: 'post-1',
        data: data,
      ).failureOrNull!;

      expect(failure, isA<ValidationFailure>());
      expect(failure.code, FailureCode.validation);
      expect(
        (failure as ValidationFailure).messageKey,
        PostIssue.authorUidMissing.name,
      );
    });

    test('never puts what the donor wrote into the debug message', () {
      final Map<String, dynamic> data = _document()
        ..['text'] = 'A private detail that must not reach a log'
        ..['likeCount'] = -1;
      final Failure failure = PostDocument.fromMap(
        id: 'post-1',
        data: data,
      ).failureOrNull!;

      expect(failure.debugMessage, contains('counterNegative'));
      expect(failure.debugMessage, isNot(contains('private detail')));
    });
  });

  group('PostDocument.fromMap: legacy singular imageUrl', () {
    test('folds a pre-Stage-8 imageUrl into imageUrls when there is no array', () {
      // 19 live posts were written before the array schema existed; reading the
      // modern array alone would render them with a photograph the author
      // attached silently missing.
      final Map<String, dynamic> data = _document()
        ..remove('imageUrls')
        ..['imageUrl'] = 'https://cdn.test/legacy.jpg';

      final Post post = PostDocument.fromMap(
        id: 'post-1',
        data: data,
      ).valueOrNull!;

      expect(post.imageUrls, <String>['https://cdn.test/legacy.jpg']);
    });

    test('the modern array wins over a stray legacy key', () {
      final Map<String, dynamic> data = _document()
        ..['imageUrls'] = <String>['https://cdn.test/1.jpg']
        ..['imageUrl'] = 'https://cdn.test/legacy.jpg';

      final Post post = PostDocument.fromMap(
        id: 'post-1',
        data: data,
      ).valueOrNull!;

      expect(post.imageUrls, <String>['https://cdn.test/1.jpg']);
    });

    test('a blank or absent legacy url is not folded in', () {
      final Map<String, dynamic> blank = _document()
        ..remove('imageUrls')
        ..['imageUrl'] = '   ';
      final Map<String, dynamic> absent = _document()..remove('imageUrls');

      expect(
        PostDocument.fromMap(id: 'post-1', data: blank).valueOrNull!.imageUrls,
        isEmpty,
      );
      expect(
        PostDocument.fromMap(id: 'post-1', data: absent).valueOrNull!.imageUrls,
        isEmpty,
      );
    });
  });
}
