import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/media/photo.dart';
import 'package:sholovvo_app/core/media/photo_picker.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/application/compose_providers.dart';
import 'package:sholovvo_app/features/feed/application/compose_state.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/post_draft.dart';
import 'package:sholovvo_app/features/feed/domain/post_image_storage.dart';

import '../../support/fake_compose.dart';
import '../../support/fake_feed.dart';
import '../../support/fake_photo_services.dart';

/// The author every publish in this file is attributed to.
const PostAuthor _author = PostAuthor(name: 'Ayesha Rahman');

void main() {
  late FakePostRepository repository;
  late FakePostImageStorage storage;
  late FakePhotoPicker picker;
  late FakeFeedRepository feed;
  late ProviderContainer container;

  ComposeController controller() =>
      container.read(composeControllerProvider.notifier);
  ComposeState state() => container.read(composeControllerProvider);

  /// Mounts the controller over fakes, optionally with a feed already loaded so
  /// the prepend path has somewhere to put the post.
  Future<void> setUpController({List<Post>? feedPosts}) async {
    repository = FakePostRepository();
    storage = FakePostImageStorage();
    picker = FakePhotoPicker(
      candidate: PhotoCandidate(bytes: jpegBytes()),
    );
    feed = FakeFeedRepository(posts: feedPosts ?? <Post>[fakePost()]);

    container = ProviderContainer(
      overrides: [
        postRepositoryProvider.overrideWithValue(repository),
        postImageStorageProvider.overrideWithValue(storage),
        postPhotoPickerProvider.overrideWithValue(picker),
        feedRepositoryProvider.overrideWithValue(feed),
      ],
    );
    addTearDown(container.dispose);

    if (feedPosts != null) {
      await container.read(feedControllerProvider.notifier).loadFirstPage();
    }
  }

  group('ComposeController, the form', () {
    test('starts empty, clean and unpublishable', () async {
      await setUpController();

      expect(state().text, isEmpty);
      expect(state().images, isEmpty);
      expect(state().isDirty, isFalse);
      expect(state().isBusy, isFalse);
      expect(state().failure, isNull);
      // Empty text is an issue, but the screen does not draw it as an error —
      // the disabled publish button already says so.
      expect(state().issue, PostIssue.textRequired);
    });

    test('records what was typed', () async {
      await setUpController();

      controller().updateText('Looking for O-');

      expect(state().text, 'Looking for O-');
      expect(state().isDirty, isTrue);
      expect(state().issue, isNull);
    });

    test('measures the trimmed length, not the raw one', () async {
      await setUpController();

      controller().updateText('   hello   ');

      expect(state().length, 5);
    });

    test('whitespace alone is not worth confirming', () async {
      await setUpController();

      controller().updateText('    ');

      expect(state().isDirty, isFalse);
      expect(state().issue, PostIssue.textRequired);
    });

    test('a single character is publishable', () async {
      await setUpController();

      controller().updateText('A');

      expect(state().issue, isNull);
    });

    test('text past the limit is an issue, and clearing it is not', () async {
      await setUpController();

      controller().updateText('a' * (PostValidator.maxTextLength + 1));
      expect(state().issue, PostIssue.textTooLong);

      controller().updateText('a' * PostValidator.maxTextLength);
      expect(state().issue, isNull);
    });
  });

  group('ComposeController.addImage', () {
    test('picks, uploads and appends', () async {
      await setUpController();

      await controller().addImage(PhotoSource.gallery);

      expect(picker.calls, 1);
      expect(picker.lastSource, PhotoSource.gallery);
      expect(storage.uploadCalls, 1);
      expect(state().images, <StoredPostImage>[storedImage(0)]);
      expect(state().isUploading, isFalse);
      expect(state().isDirty, isTrue);
    });

    test('reports uploading while the object is in flight', () async {
      await setUpController();
      storage.gate = Completer<void>();

      final Future<void> pending = controller().addImage(PhotoSource.gallery);
      expect(state().isUploading, isTrue);
      expect(state().images, isEmpty);

      storage.gate!.complete();
      await pending;

      expect(state().isUploading, isFalse);
      expect(state().images, hasLength(1));
    });

    test('a cancelled pick changes nothing and says nothing', () async {
      await setUpController();
      picker.candidate = null;

      await controller().addImage(PhotoSource.camera);

      expect(picker.calls, 1);
      expect(storage.uploadCalls, 0);
      expect(state().images, isEmpty);
      expect(state().failure, isNull);
    });

    test('a refused picker surfaces its failure and uploads nothing', () async {
      await setUpController();
      picker.failure = const PermissionFailure(debugMessage: 'denied');

      await controller().addImage(PhotoSource.camera);

      expect(state().failure, isA<PermissionFailure>());
      expect(storage.uploadCalls, 0);
    });

    test('bytes that are not an image never reach the network', () async {
      await setUpController();
      picker.candidate = PhotoCandidate(bytes: textBytes());

      await controller().addImage(PhotoSource.gallery);

      final Failure? failure = state().failure;
      expect(failure, isA<ValidationFailure>());
      expect(
        (failure! as ValidationFailure).messageKey,
        PhotoIssue.unsupportedType.name,
      );
      expect(
        storage.uploadCalls,
        0,
        reason: 'the validator refused it, so there is nothing to upload',
      );
      expect(state().images, isEmpty);
    });

    test('a failed upload is reported and adds no image', () async {
      await setUpController();
      storage.uploadFailure = const NetworkFailure(debugMessage: 'offline');

      await controller().addImage(PhotoSource.gallery);

      expect(state().failure, isA<NetworkFailure>());
      expect(state().images, isEmpty);
      expect(state().isUploading, isFalse);
    });

    test('a later successful upload clears the earlier failure', () async {
      await setUpController();
      storage.uploadFailure = const NetworkFailure(debugMessage: 'offline');
      await controller().addImage(PhotoSource.gallery);
      expect(state().failure, isNotNull);

      storage.uploadFailure = null;
      await controller().addImage(PhotoSource.gallery);

      expect(state().failure, isNull);
      expect(state().images, hasLength(1));
    });

    test('refuses a fifth photograph', () async {
      await setUpController();

      for (int index = 0; index < PostValidator.maxImages; index++) {
        await controller().addImage(PhotoSource.gallery);
      }
      expect(state().images, hasLength(PostValidator.maxImages));

      await controller().addImage(PhotoSource.gallery);

      expect(picker.calls, PostValidator.maxImages);
      expect(state().images, hasLength(PostValidator.maxImages));
    });

    test('a second tap while a pick is in flight opens no second picker',
        () async {
      await setUpController();
      final Completer<void> gate = Completer<void>();
      storage.gate = gate;

      final Future<void> first = controller().addImage(PhotoSource.gallery);
      // The gap the flag exists for: the picker has been awaited but the state
      // has not changed yet, so a naive guard on `isUploading` would miss this.
      await controller().addImage(PhotoSource.camera);

      gate.complete();
      await first;

      expect(picker.calls, 1);
      expect(storage.uploadCalls, 1);
      expect(state().images, hasLength(1));
    });
  });

  group('ComposeController.removeImage', () {
    test('drops the slot first, then deletes that object', () async {
      await setUpController();
      await controller().addImage(PhotoSource.gallery);
      await controller().addImage(PhotoSource.gallery);
      final StoredPostImage first = state().images.first;

      await controller().removeImage(first);

      expect(state().images, <StoredPostImage>[storedImage(1)]);
      // The path of the photo that was dropped, not of whatever was first.
      expect(storage.removedPaths, <String>[first.path]);
    });

    test('a failed delete is logged, not shown', () async {
      await setUpController();
      await controller().addImage(PhotoSource.gallery);
      storage.removeFailure = const NetworkFailure(debugMessage: 'offline');

      await controller().removeImage(state().images.single);

      // The donor asked for it to go and it went; the sentence would be about a
      // file that is no longer on screen.
      expect(state().images, isEmpty);
      expect(state().failure, isNull);
    });

    test('does nothing while a publish is in flight', () async {
      await setUpController();
      controller().updateText('hello');
      await controller().addImage(PhotoSource.gallery);
      repository.gate = Completer<void>();

      final Future<Result<Post>> publishing = controller().publish(author: _author);
      await controller().removeImage(state().images.single);

      expect(state().images, hasLength(1));
      expect(storage.removedPaths, isEmpty);

      repository.gate!.complete();
      await publishing;
    });
  });

  group('ComposeController.discard', () {
    test('empties the form and deletes every uploaded object', () async {
      await setUpController();
      controller().updateText('something');
      await controller().addImage(PhotoSource.gallery);
      await controller().addImage(PhotoSource.gallery);

      await controller().discard();

      expect(state().text, isEmpty);
      expect(state().images, isEmpty);
      // No document will ever name these objects, so the draft takes them with
      // it rather than leaving bytes nobody can find.
      expect(storage.removedPaths, <String>[
        storedImage(0).path,
        storedImage(1).path,
      ]);
    });

    test('a draft with no photos does not touch storage', () async {
      await setUpController();
      controller().updateText('something');

      await controller().discard();

      expect(state().text, isEmpty);
      expect(storage.removedPaths, isEmpty);
    });

    test('a failed delete still empties the form', () async {
      await setUpController();
      await controller().addImage(PhotoSource.gallery);
      storage.removeFailure = const NetworkFailure(debugMessage: 'offline');

      await controller().discard();

      expect(state().images, isEmpty);
      expect(state().failure, isNull);
    });
  });

  group('ComposeController.publish', () {
    test('writes the trimmed text and puts the post at the top of the feed',
        () async {
      await setUpController(feedPosts: <Post>[
        fakePost(id: 'post-old', createdAt: DateTime.utc(2026, 10, 1)),
      ]);
      controller().updateText('  Donated at Dhaka Medical today.  ');

      final Result<Post> result = await controller().publish(author: _author);

      expect(result.valueOrNull, isNotNull);
      // Trimmed once, at the boundary: the form is the last place that knows
      // which whitespace the donor meant.
      expect(repository.lastDraft!.text, 'Donated at Dhaka Medical today.');
      expect(repository.lastDraft!.author.name, 'Ayesha Rahman');

      final List<Post> posts = container.read(feedControllerProvider).posts;
      expect(posts.first.id, 'post-published-1');
      expect(posts.last.id, 'post-old');
    });

    test('publishes the photographs in the order they were added', () async {
      await setUpController();
      controller().updateText('Two photos');
      await controller().addImage(PhotoSource.gallery);
      await controller().addImage(PhotoSource.gallery);

      await controller().publish(author: _author);

      final PostDraft draft = repository.lastDraft!;
      expect(draft.imageUrls, <String>[storedImage(0).url, storedImage(1).url]);
      expect(draft.imagePaths, <String>[
        storedImage(0).path,
        storedImage(1).path,
      ]);
    });

    test('resets the form before returning, so nothing can publish twice',
        () async {
      await setUpController(feedPosts: <Post>[fakePost()]);
      controller().updateText('hello');

      await controller().publish(author: _author);

      expect(state().text, isEmpty);
      expect(state().images, isEmpty);
      expect(state().isPublishing, isFalse);
      expect(state().failure, isNull);
    });

    test('reports publishing while the write is in flight', () async {
      await setUpController();
      controller().updateText('hello');
      repository.gate = Completer<void>();

      final Future<Result<Post>> pending = controller().publish(author: _author);
      expect(state().isPublishing, isTrue);
      expect(state().isBusy, isTrue);

      repository.gate!.complete();
      await pending;

      expect(state().isPublishing, isFalse);
    });

    test('a failed write keeps the draft so the retry is one tap', () async {
      await setUpController();
      controller().updateText('hello');
      await controller().addImage(PhotoSource.gallery);
      repository.failure = const NetworkFailure(debugMessage: 'offline');

      final Result<Post> result = await controller().publish(author: _author);

      expect(result.failureOrNull, isA<NetworkFailure>());
      expect(state().failure, isA<NetworkFailure>());
      // Text and photographs both survive: retyping a post because the network
      // blinked is not a thing to ask of somebody.
      expect(state().text, 'hello');
      expect(state().images, hasLength(1));
      expect(state().isPublishing, isFalse);
      expect(storage.removedPaths, isEmpty);
    });

    test('a failed write adds nothing to the feed', () async {
      await setUpController(feedPosts: <Post>[fakePost(id: 'post-old')]);
      controller().updateText('hello');
      repository.failure = const NetworkFailure(debugMessage: 'offline');

      await controller().publish(author: _author);

      expect(
        container.read(feedControllerProvider).posts.map((Post post) => post.id),
        <String>['post-old'],
      );
    });

    test('an empty draft is refused without a write', () async {
      await setUpController();

      final Result<Post> result = await controller().publish(author: _author);

      expect(
        (result.failureOrNull! as ValidationFailure).messageKey,
        PostIssue.textRequired.name,
      );
      expect(repository.calls, 0);
    });

    test('a second publish while the first is in flight is a conflict',
        () async {
      await setUpController();
      controller().updateText('hello');
      repository.gate = Completer<void>();

      final Future<Result<Post>> first = controller().publish(author: _author);
      // Text is still there at this point, so the guard cannot be the validator.
      final Result<Post> second = await controller().publish(author: _author);

      expect(second.failureOrNull, isA<ConflictFailure>());
      expect(repository.calls, 1);

      repository.gate!.complete();
      await first;
    });

    test('the post is prepended only to a feed that has loaded', () async {
      // No feed overridden with posts, so nothing has been read.
      await setUpController();
      controller().updateText('hello');

      await controller().publish(author: _author);

      expect(container.read(feedControllerProvider).loaded, isFalse);
      expect(container.read(feedControllerProvider).posts, isEmpty);
    });

    test('a post already in the feed is not prepended twice', () async {
      final Post existing = fakePost(id: 'post-1');
      await setUpController(feedPosts: <Post>[existing]);
      repository.fixed = existing;
      controller().updateText('hello');

      await controller().publish(author: _author);

      expect(
        container.read(feedControllerProvider).posts,
        <Post>[existing],
      );
    });
  });
}
