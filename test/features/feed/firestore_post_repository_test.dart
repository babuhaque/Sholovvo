import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/data/firestore_post_repository.dart';
import 'package:sholovvo_app/features/feed/data/models/post_document.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/post_draft.dart';
import 'package:sholovvo_app/features/feed/domain/post_image_storage.dart';

import '../../support/fake_compose.dart';

/// The author every draft in this file is attributed to.
const PostAuthor _author = PostAuthor(
  name: 'Ayesha Rahman',
  photoUrl: 'https://demo.supabase.co/storage/v1/object/public/avatars/a.jpg',
);

PostDraft _draft({
  String text = 'Donated at Dhaka Medical today.',
  List<StoredPostImage> images = const <StoredPostImage>[],
  PostAuthor author = _author,
}) {
  return PostDraft(author: author, text: text, images: images);
}

void main() {
  late FakePostWriter writer;
  late FirestorePostRepository repository;

  /// The moment the repository's clock reports, so the assertion about the
  /// returned entity does not depend on when the test ran.
  final DateTime now = DateTime.utc(2026, 11, 2, 9, 15);

  void setUpRepository({DateTime? clock}) {
    writer = FakePostWriter();
    repository = FirestorePostRepository(
      writer,
      clock: () => clock ?? now,
    );
  }

  group('FirestorePostRepository.publish', () {
    test('writes one document and returns the post it wrote', () async {
      setUpRepository();

      final Result<Post> result = await repository.publish(_draft());
      final Post? post = result.valueOrNull;

      expect(post, isNotNull);
      expect(post!.id, 'post-new');
      expect(post.authorUid, 'uid-verified');
      expect(post.authorName, 'Ayesha Rahman');
      expect(post.text, 'Donated at Dhaka Medical today.');
      expect(post.imageUrls, isEmpty);
      expect(post.imagePaths, isEmpty);
      expect(post.likeCount, 0);
      expect(post.commentCount, 0);
      expect(post.createdAt, now);
      expect(post.updatedAt, now);
      expect(post.editedAt, isNull);

      expect(writer.created, hasLength(1));
      expect(writer.created.single.id, 'post-new');
    });

    test('the author snapshot comes from the draft, the uid from the session',
        () async {
      setUpRepository();

      await repository.publish(
        _draft(author: const PostAuthor(name: 'Rafiq Hasan')),
      );

      final Map<String, Object?> fields = writer.created.single.fields;
      expect(fields['authorName'], 'Rafiq Hasan');
      expect(fields['authorPhotoUrl'], isNull);
      // Rules compare this to `request.auth.uid`, so it can only ever be the
      // token's value — never something a form supplied.
      expect(fields['authorUid'], 'uid-verified');
    });

    test('a draft by a donor with no profile writes an empty name', () async {
      setUpRepository();

      final Result<Post> result = await repository.publish(
        _draft(author: const PostAuthor.unknown()),
      );

      expect(result.valueOrNull?.authorName, '');
      expect(writer.created.single.fields['authorName'], '');
    });

    test('both timestamps are server timestamps on the written map', () async {
      setUpRepository();

      await repository.publish(_draft());

      final Map<String, Object?> fields = writer.created.single.fields;
      // The document is stamped by the server; only the *returned* entity
      // carries the client clock.
      expect(fields['createdAt'], isA<FieldValue>());
      expect(fields['updatedAt'], isA<FieldValue>());
      expect(fields.containsKey('editedAt'), isFalse);
    });

    test('the written field set is exactly what the mapper builds', () async {
      setUpRepository();

      await repository.publish(_draft());

      // A photo URL is present, so it is written; there is no `editedAt` on a
      // brand-new post.
      expect(writer.created.single.fields.keys.toSet(), <String>{
        ...PostDocument.requiredFields,
        'authorPhotoUrl',
      });
    });

    test('a draft with no photo URL writes only the required fields', () async {
      setUpRepository();

      await repository.publish(_draft(author: const PostAuthor(name: 'Rafiq')));

      expect(
        writer.created.single.fields.keys.toSet(),
        PostDocument.requiredFields.toSet(),
      );
    });

    test('publishes the image urls and paths in the order they were added',
        () async {
      setUpRepository();

      await repository.publish(
        _draft(
          images: <StoredPostImage>[storedImage(0), storedImage(1)],
        ),
      );

      final Map<String, Object?> fields = writer.created.single.fields;
      expect(fields['imageUrls'], <String>[
        storedImage(0).url,
        storedImage(1).url,
      ]);
      expect(fields['imagePaths'], <String>[
        storedImage(0).path,
        storedImage(1).path,
      ]);
    });

    test('a signed-out session is an auth failure, not a write', () async {
      setUpRepository();
      writer.authorUid = null;

      final Result<Post> result = await repository.publish(_draft());

      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, isA<AuthFailure>());
      expect(writer.created, isEmpty);
      expect(writer.idCalls, 0);
    });

    test('an empty uid is refused the same way as a missing one', () async {
      setUpRepository();
      writer.authorUid = '';

      final Result<Post> result = await repository.publish(_draft());

      expect(result.failureOrNull, isA<AuthFailure>());
      expect(writer.created, isEmpty);
    });

    test('an unpublishable draft never reaches the network', () async {
      setUpRepository();

      final Result<Post> result = await repository.publish(_draft(text: '   '));

      final Failure? failure = result.failureOrNull;
      expect(failure, isA<ValidationFailure>());
      expect((failure! as ValidationFailure).messageKey, PostIssue.textRequired.name);
      expect(writer.created, isEmpty);
      expect(writer.idCalls, 0, reason: 'not even an id is allocated');
    });

    test('too much text is refused with the issue the form would show',
        () async {
      setUpRepository();
      final String tooLong = 'a' * (PostValidator.maxTextLength + 1);

      final Result<Post> result = await repository.publish(_draft(text: tooLong));

      expect(
        (result.failureOrNull! as ValidationFailure).messageKey,
        PostIssue.textTooLong.name,
      );
      expect(writer.created, isEmpty);
    });

    test('more images than the card can draw is refused', () async {
      setUpRepository();

      final Result<Post> result = await repository.publish(
        _draft(
          images: <StoredPostImage>[
            for (int index = 0; index <= PostValidator.maxImages; index++)
              storedImage(index),
          ],
        ),
      );

      expect(
        (result.failureOrNull! as ValidationFailure).messageKey,
        PostIssue.tooManyImages.name,
      );
      expect(writer.created, isEmpty);
    });

    test('a failed write returns the failure and no post', () async {
      setUpRepository();
      writer.createFailure = const NetworkFailure(debugMessage: 'offline');

      final Result<Post> result = await repository.publish(_draft());

      // A post that is not in the database must never be handed back as if it
      // were: the feed would show a document that does not exist.
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, isA<NetworkFailure>());
      expect(writer.created, hasLength(1), reason: 'the write was attempted');
    });

    test('the returned entity does not read the clock a second time', () async {
      int calls = 0;
      writer = FakePostWriter();
      repository = FirestorePostRepository(
        writer,
        clock: () {
          calls++;
          return now.add(Duration(seconds: calls));
        },
      );

      final Result<Post> result = await repository.publish(_draft());

      // One read of the clock, so `createdAt` and `updatedAt` on a fresh post
      // are the same instant rather than a second apart.
      expect(calls, 1);
      expect(result.valueOrNull?.createdAt, result.valueOrNull?.updatedAt);
    });

    test('the clock is recorded in UTC whatever it reports', () async {
      setUpRepository(clock: DateTime(2026, 11, 2, 15, 15));

      final Result<Post> result = await repository.publish(_draft());

      expect(result.valueOrNull!.createdAt.isUtc, isTrue);
      expect(
        result.valueOrNull!.createdAt,
        DateTime(2026, 11, 2, 15, 15).toUtc(),
      );
    });
  });
}
