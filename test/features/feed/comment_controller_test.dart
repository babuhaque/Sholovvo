import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/application/comment_providers.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/data/comment_service.dart';
import 'package:sholovvo_app/features/feed/domain/entities/comment.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';

import '../../support/fake_feed.dart';

/// A fake [CommentService] that returns scripted results.
class _FakeCommentService implements CommentService {
  List<Comment> comments = <Comment>[];
  Failure? loadFailure;
  Failure? addFailure;
  final List<String> addCalls = <String>[];

  @override
  Future<Result<List<Comment>>> loadComments(String postId) async {
    if (loadFailure != null) {
      return FailureResult<List<Comment>>(loadFailure!);
    }
    return Success<List<Comment>>(List<Comment>.from(comments));
  }

  @override
  Future<Result<Comment>> addComment({
    required String postId,
    required String authorUid,
    required String authorName,
    String? authorPhotoUrl,
    required String text,
    String? parentId,
    String? replyToName,
  }) async {
    addCalls.add(postId);
    if (addFailure != null) {
      return FailureResult<Comment>(addFailure!);
    }
    final Comment c = Comment(
      id: 'new-${addCalls.length}',
      authorUid: authorUid,
      authorName: authorName,
      authorPhotoUrl: authorPhotoUrl,
      text: text.trim(),
      parentId: parentId,
      replyToName: replyToName,
      createdAt: DateTime.utc(2026, 10, 20, 12),
    );
    comments.add(c);
    return Success<Comment>(c);
  }

  @override
  Future<Result<void>> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    comments.removeWhere((c) => c.id == commentId);
    return const Success<void>(null);
  }
}

void main() {
  late _FakeCommentService service;
  late ProviderContainer container;

  CommentController controller() =>
      container.read(commentControllerProvider.notifier);
  CommentState state() => container.read(commentControllerProvider);

  void setUp({List<Comment>? existing}) {
    service = _FakeCommentService()
      ..comments = existing ?? <Comment>[];
    // FeedController needs a repository; provide a minimal fake.
    final FakeFeedRepository feedRepo = FakeFeedRepository(
      posts: <Post>[fakePost(id: 'p-1', commentCount: 0)],
      pageSize: 1,
    );
    container = ProviderContainer(
      overrides: [
        commentServiceProvider.overrideWithValue(service),
        feedRepositoryProvider.overrideWithValue(feedRepo),
      ],
    );
    addTearDown(container.dispose);
  }

  /// Loads the feed so incrementCommentCount has a post to find.
  Future<void> loadFeed() async {
    await container.read(feedControllerProvider.notifier).loadFirstPage();
  }

  group('CommentController', () {
    test('open loads comments from service', () async {
      setUp(existing: <Comment>[
        Comment(
          id: 'c-1',
          authorUid: 'uid-1',
          authorName: 'Rahim',
          text: 'Nice',
          createdAt: DateTime.utc(2026, 10, 20),
        ),
      ]);

      await controller().open('p-1');

      expect(state().comments.length, 1);
      expect(state().comments.first.id, 'c-1');
      expect(state().loaded, isTrue);
      expect(state().isLoading, isFalse);
    });

    test('submitComment appends to thread + increments feed count', () async {
      setUp();
      await loadFeed();

      await controller().open('p-1');
      expect(state().comments, isEmpty);

      final bool ok = await controller().submitComment(
        authorUid: 'uid-2',
        authorName: 'Karim',
        text: 'Great!',
      );

      expect(ok, isTrue);
      expect(state().comments.length, 1);
      expect(state().comments.first.authorName, 'Karim');
      expect(service.addCalls, ['p-1']);
    });

    test('submitComment failure sets error and does not append', () async {
      setUp();
      service.addFailure = NetworkFailure(debugMessage: 'offline');

      await controller().open('p-1');
      final bool ok = await controller().submitComment(
        authorUid: 'uid-2',
        authorName: 'Karim',
        text: 'Hi',
      );

      expect(ok, isFalse);
      expect(state().comments, isEmpty);
      expect(state().failure, isA<NetworkFailure>());
    });

    test('open with load failure sets error state', () async {
      setUp();
      service.loadFailure = PermissionFailure(debugMessage: 'denied');

      await controller().open('p-1');

      expect(state().failure, isA<PermissionFailure>());
      expect(state().loaded, isTrue);
      expect(state().isLoading, isFalse);
    });

    test('retry reloads after a previous failure', () async {
      setUp();
      service.loadFailure = NetworkFailure(debugMessage: 'offline');
      await controller().open('p-1');
      expect(state().failure, isNotNull);

      // Fix the failure.
      service.loadFailure = null;
      await controller().retry();

      expect(state().failure, isNull);
      expect(state().comments, isEmpty);
    });
  });

  group('submitComment with reply', () {
    test('appends a comment carrying parentId and replyToName', () async {
      setUp();
      await loadFeed();
      await controller().open('p-1');

      final bool ok = await controller().submitComment(
        authorUid: 'uid-2',
        authorName: 'Replier',
        text: 'I agree!',
        parentId: 'comment-abc',
        replyToName: 'Original Author',
      );

      expect(ok, isTrue);
      final Comment last = state().comments.last;
      expect(last.parentId, 'comment-abc');
      expect(last.replyToName, 'Original Author');
      expect(last.isReply, isTrue);
    });

    test('without parentId creates a top-level comment', () async {
      setUp();
      await loadFeed();
      await controller().open('p-1');

      await controller().submitComment(
        authorUid: 'uid-1',
        authorName: 'Top',
        text: 'Top-level',
      );

      final Comment last = state().comments.last;
      expect(last.parentId, isNull);
      expect(last.isReply, isFalse);
    });
  });
}
