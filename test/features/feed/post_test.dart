import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';

/// A post with only the required fields, so each test states just the field it
/// is about.
Post _post({
  String text = 'Need O- donors at Dhanmondi this Friday.',
  List<String> imageUrls = const <String>[],
  List<String> imagePaths = const <String>[],
  int likeCount = 0,
  int commentCount = 0,
  String? authorPhotoUrl,
  DateTime? editedAt,
}) {
  final DateTime created = DateTime.utc(2026, 10, 20, 9);
  return Post(
    id: 'post-1',
    authorUid: 'uid-verified',
    authorName: 'Ayesha Rahman',
    authorPhotoUrl: authorPhotoUrl,
    text: text,
    imageUrls: imageUrls,
    imagePaths: imagePaths,
    likeCount: likeCount,
    commentCount: commentCount,
    createdAt: created,
    updatedAt: created,
    editedAt: editedAt,
  );
}

/// The issue the validator reports for the given data, or `null`.
PostIssue? _issue({
  String text = 'A valid post.',
  int imageCount = 0,
  int imagePathCount = 0,
  int likeCount = 0,
  int commentCount = 0,
}) {
  return PostValidator.validate(
    text: text,
    imageCount: imageCount,
    imagePathCount: imagePathCount,
    likeCount: likeCount,
    commentCount: commentCount,
  );
}

void main() {
  group('PostValidator: text', () {
    test('an empty post is refused', () {
      expect(_issue(text: ''), PostIssue.textRequired);
    });

    test('whitespace is not text', () {
      // The rule measures the trimmed length: a post of four spaces would render
      // as a blank card that says nothing and cannot be answered.
      expect(_issue(text: '    '), PostIssue.textRequired);
      expect(_issue(text: '\n\t '), PostIssue.textRequired);
    });

    test('the limit itself is allowed and one character more is not', () {
      final String atLimit = 'a' * PostValidator.maxTextLength;
      final String overLimit = 'a' * (PostValidator.maxTextLength + 1);

      expect(PostValidator.maxTextLength, 2000);
      expect(_issue(text: atLimit), isNull);
      expect(_issue(text: overLimit), PostIssue.textTooLong);
    });

    test('the limit counts trimmed characters, not padding', () {
      final String padded =
          '${'  '}${'a' * PostValidator.maxTextLength}${'  '}';

      expect(_issue(text: padded), isNull);
    });
  });

  group('PostValidator: images', () {
    test('no images is a valid post', () {
      expect(_issue(imageCount: 0, imagePathCount: 0), isNull);
    });

    test('four images are allowed and five are not', () {
      final List<String> urls = List<String>.generate(4, (int i) => 'u$i');
      final List<String> paths = List<String>.generate(4, (int i) => 'p$i');

      expect(
        _issue(imageCount: urls.length, imagePathCount: paths.length),
        isNull,
      );
      expect(_issue(imageCount: 5, imagePathCount: 5), PostIssue.tooManyImages);
      expect(PostValidator.maxImages, 4);
    });

    test('more storage paths than URLs is refused', () {
      // A path with no published URL names an object nobody can see, and an
      // object nobody can see is one the delete path cannot account for.
      expect(
        _issue(imageCount: 2, imagePathCount: 3),
        PostIssue.tooManyImagePaths,
      );
    });

    test('fewer paths than URLs is allowed', () {
      // An image this build did not store — an older post, another client —
      // still renders; only its delete path is unknown.
      expect(_issue(imageCount: 3, imagePathCount: 1), isNull);
      expect(_issue(imageCount: 3, imagePathCount: 0), isNull);
    });
  });

  group('PostValidator: counters', () {
    test('counters start at zero and may grow', () {
      expect(_issue(likeCount: 0, commentCount: 0), isNull);
      expect(_issue(likeCount: 999, commentCount: 12), isNull);
    });

    test('a negative counter is refused', () {
      expect(_issue(likeCount: -1), PostIssue.counterNegative);
      expect(_issue(commentCount: -1), PostIssue.counterNegative);
    });
  });

  group('Post', () {
    test('holds image lists that cannot be changed behind its back', () {
      final Post post = _post(
        imageUrls: const <String>['u1'],
        imagePaths: const <String>[],
      );

      expect(() => post.imageUrls.add('u2'), throwsUnsupportedError);
      expect(post.imageUrls, <String>['u1']);
    });

    test('reports whether it has images and whether it was edited', () {
      final Post textOnly = _post();
      final Post withPhoto = _post(imageUrls: const <String>['u1']);
      final Post edited = _post(editedAt: DateTime.utc(2026, 10, 21));

      expect(textOnly.hasImages, isFalse);
      expect(textOnly.isEdited, isFalse);
      expect(withPhoto.hasImages, isTrue);
      expect(edited.isEdited, isTrue);
    });

    test('compares by value, including list contents', () {
      final Post first = _post(imageUrls: const <String>['a', 'b']);
      final Post same = _post(imageUrls: const <String>['a', 'b']);
      final Post differentOrder = _post(imageUrls: const <String>['b', 'a']);

      expect(first, same);
      expect(first.hashCode, same.hashCode);
      expect(first, isNot(differentOrder));
    });

    test('describes itself without quoting what was written', () {
      final Post post = _post(
        text: 'A private detail nobody should see in a log',
      );

      // A log line is not a place for a donor's words.
      expect(post.toString(), contains('post-1'));
      expect(post.toString(), isNot(contains('private detail')));
    });
  });
}
