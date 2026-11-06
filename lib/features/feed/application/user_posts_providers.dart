import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/logging/app_logger.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/application/feed_state.dart';
import 'package:sholovvo_app/features/feed/data/feed_count_hydration_service.dart';
import 'package:sholovvo_app/features/feed/data/like_hydration_service.dart';
import 'package:sholovvo_app/features/feed/data/post_like_service.dart';
import 'package:sholovvo_app/features/feed/data/saved_posts_service.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/feed_page.dart';

/// Owns one author's posts.
///
/// The list side of the tap-through "author posts" screen. It is deliberately a
/// sibling of [FeedController] rather than the same class with a filter flag:
/// the whole feed is the app's most-tested controller (its read walk, empty-page
/// handling and hydration are pinned by a large suite), and threading a nullable
/// author through it would either complicate every one of those paths or leave
/// the author case untested. This one reuses the same [FeedState] shape and the
/// same read/hydration seams, so a post card behaves identically here and in the
/// feed, while the global feed keeps its exact contract.
///
/// **What it does not carry.** [FeedState.showOnlySaved] and the empty-page
/// walk have no meaning for a single author's list, so the saved filter stays
/// unused and the walk is kept only in its simplest form (advance while a page
/// is empty-but-promises-more, bounded by [maxEmptyPages], so a run of unreadable
/// documents can never spin here either).
class UserPostsController extends Notifier<FeedState> {
  bool _fetching = false;

  static const AppLogger _logger = AppLogger('feed.userPosts');

  /// How many unreadable pages one operation walks past, mirroring
  /// [FeedController.maxEmptyPages] so the two lists fail the same way.
  static const int maxEmptyPages = 5;

  /// The author this instance lists, set by [open] before the first read.
  ///
  /// A plain field rather than a provider the controller reads, so the value
  /// cannot come from the wrong scope: the screen that owns a wall hands the uid
  /// in explicitly, and the autoDispose provider gives each new wall a fresh
  /// instance (fresh uid and list). It is null only before [open] runs, which no
  /// page read can reach — [_read] bails rather than fall back to the whole feed.
  String? _authorUid;

  bool get isFetching => _fetching;

  @override
  FeedState build() {
    Set<String> saved;
    try {
      saved = ref.read(savedPostsServiceProvider).load();
    } catch (_) {
      saved = <String>{};
    }
    return FeedState(savedPostIds: saved);
  }

  /// Opens one author's wall: records whose posts to list, then reads page one.
  ///
  /// The screen calls this from its first frame with the uid it was pushed
  /// with. Splitting it from [loadFirstPage] lets [refresh] and [loadMore] re-use
  /// the uid this set once, rather than every gesture re-supplying it.
  Future<void> open(String authorUid) {
    _authorUid = authorUid;
    return loadFirstPage();
  }

  /// Reads page one of this author's posts, replacing whatever is on screen.
  Future<void> loadFirstPage() {
    if (_fetching) {
      return Future<void>.value();
    }
    return _read(after: null, append: false);
  }

  /// The pull-to-refresh gesture; identical to [loadFirstPage] by construction.
  Future<void> refresh() => loadFirstPage();

  /// Appends the page after the current cursor.
  Future<void> loadMore() {
    if (_fetching || !state.hasMore) {
      return Future<void>.value();
    }
    final FeedCursor? cursor = state.cursor;
    if (cursor == null) {
      return Future<void>.value();
    }
    return _read(after: cursor, append: true);
  }

  /// Increments the comment count on a visible post (the comment sheet's
  /// optimistic nudge, exactly as the feed controller offers it).
  void incrementCommentCount(String postId) {
    _bumpComment(postId, 1);
  }

  /// Decrements the comment count on a visible post after a delete.
  void decrementCommentCount(String postId) {
    _bumpComment(postId, -1);
  }

  void _bumpComment(String postId, int delta) {
    final int index = state.posts.indexWhere((Post p) => p.id == postId);
    if (index < 0) {
      return;
    }
    final Post original = state.posts[index];
    final int next = (original.commentCount + delta).clamp(0, 1 << 31);
    final List<Post> posts = List<Post>.from(state.posts);
    posts[index] = original.withCommentCount(next);
    state = state.copyWith(posts: posts);
  }

  /// Toggles the current user's like on one of this author's posts.
  ///
  /// Optimistic write with rollback, byte-for-byte the feed's behaviour: the UI
  /// flips immediately, the backend write runs behind it, and a failure rolls
  /// the flip back and logs rather than popping (a silent reversion is kinder
  /// than a snackbar for a misfire).
  Future<void> toggleLike(String postId, String uid) async {
    final int index = state.posts.indexWhere((Post p) => p.id == postId);
    if (index < 0) {
      return;
    }

    final bool wasLiked = state.likedPostIds.contains(postId);
    final Post original = state.posts[index];
    final Post updated = original.withLikeCount(
      wasLiked ? original.likeCount - 1 : original.likeCount + 1,
    );

    final Set<String> nextLiked = Set<String>.from(state.likedPostIds);
    if (wasLiked) {
      nextLiked.remove(postId);
    } else {
      nextLiked.add(postId);
    }
    final List<Post> nextPosts = List<Post>.from(state.posts);
    nextPosts[index] = updated;
    state = state.copyWith(posts: nextPosts, likedPostIds: nextLiked);

    final PostLikeService service = ref.read(postLikeServiceProvider);
    final Result<void> result = wasLiked
        ? await service.unlike(postId, uid)
        : await service.like(postId, uid);

    if (result is FailureResult<void>) {
      final Set<String> rolledBack = Set<String>.from(state.likedPostIds);
      if (wasLiked) {
        rolledBack.add(postId);
      } else {
        rolledBack.remove(postId);
      }
      final List<Post> rolledPosts = List<Post>.from(state.posts);
      rolledPosts[index] = original;
      state = state.copyWith(posts: rolledPosts, likedPostIds: rolledBack);
      _logger.warning(
        'Like toggle failed on post $postId: ${result.failure.code.name}',
      );
    }
  }

  /// Toggles the bookmark on [postId] and persists the full set, exactly as the
  /// feed does (save state is global, not per-author).
  void toggleSave(String postId) {
    final Set<String> next = Set<String>.from(state.savedPostIds);
    if (!next.remove(postId)) {
      next.add(postId);
    }
    state = state.copyWith(savedPostIds: next);
    try {
      final SavedPostsService service = ref.read(savedPostsServiceProvider);
      unawaited(service.save(next));
    } catch (_) {
      // No persistence available (test environment); state update is enough.
    }
  }

  /// Fetches the viewer's likes and the derived counts for the visible posts
  /// and merges both in, fire-and-forget after a first page resolves — the same
  /// two reads, in the same order, as [FeedController]'s hydration.
  Future<void> _hydrate(String uid) async {
    final List<String> postIds = state.posts.map((Post p) => p.id).toList();
    if (postIds.isEmpty) {
      return;
    }

    try {
      final LikeHydrationService service = ref.read(
        likeHydrationServiceProvider,
      );
      final Set<String> liked = await service.fetchLikedPostIds(postIds, uid);
      if (liked.isNotEmpty) {
        state = state.copyWith(
          likedPostIds: <String>{...state.likedPostIds, ...liked},
        );
      }
    } catch (_) {
      // A missing heart self-corrects on the next toggle; not fatal.
    }

    try {
      final FeedCountHydrationService service = ref.read(
        feedCountHydrationServiceProvider,
      );
      final Map<String, PostCountSnapshot> counts = await service.fetchCounts(
        postIds,
      );
      if (counts.isEmpty) {
        return;
      }
      final List<Post> next = <Post>[
        for (final Post post in state.posts)
          counts.containsKey(post.id)
              ? post
                    .withLikeCount(counts[post.id]!.likeCount)
                    .withCommentCount(counts[post.id]!.commentCount)
              : post,
      ];
      state = state.copyWith(posts: next);
    } catch (_) {
      // No count seam, or the read failed: the on-screen counts stand.
    }
  }

  Future<void> _read({required FeedCursor? after, required bool append}) async {
    if (_fetching) {
      return;
    }
    _fetching = true;

    state = append
        ? state.copyWith(status: FeedStatus.loadingMore, clearFailure: true)
        : (state.posts.isEmpty
              ? state.copyWith(status: FeedStatus.loading, clearFailure: true)
              : state.copyWith(clearFailure: true));

    try {
      // Without an author this is not an author's wall — bail rather than let a
      // null filter read the whole collection under one person's name.
      final String? authorUid = _authorUid;
      if (authorUid == null) {
        return;
      }

      FeedCursor? cursor = after;
      int emptyPages = 0;
      int refused = 0;
      FeedPage page;

      while (true) {
        final Result<FeedPage> result = await ref
            .read(feedRepositoryProvider)
            .loadPage(after: cursor, authorUid: authorUid);
        final FeedPage? resolved = result.valueOrNull;

        if (resolved == null) {
          state = state.copyWith(
            status: state.posts.isEmpty ? FeedStatus.failure : FeedStatus.ready,
            failure: result.failureOrNull,
          );
          return;
        }

        page = resolved;
        refused += page.skipped;
        if (page.posts.isNotEmpty ||
            !page.hasMore ||
            ++emptyPages >= maxEmptyPages) {
          break;
        }
        cursor = page.cursor ?? cursor;
      }

      final bool keepsExisting = append || (page.posts.isEmpty && page.hasMore);
      final List<Post> next = keepsExisting
          ? _append(state.posts, page.posts)
          : page.posts;
      final int skippedTotal = (keepsExisting ? state.skipped : 0) + refused;

      state = FeedState(
        status: FeedStatus.ready,
        posts: next,
        cursor: page.cursor,
        hasMore: page.hasMore,
        loaded: true,
        skipped: skippedTotal,
        likedPostIds: state.likedPostIds,
        savedPostIds: state.savedPostIds,
      );

      if (skippedTotal > 0) {
        _logger.warning(
          'Author-posts read skipped $skippedTotal unreadable post document(s)',
        );
      }

      if (!append && next.isNotEmpty) {
        final String? uid = ref.read(authUidProvider);
        if (uid != null) {
          unawaited(_hydrate(uid));
        }
      }
    } finally {
      _fetching = false;
    }
  }

  static List<Post> _append(List<Post> existing, List<Post> incoming) {
    final Set<String> seen = <String>{
      for (final Post post in existing) post.id,
    };
    return <Post>[
      ...existing,
      for (final Post post in incoming)
        if (seen.add(post.id)) post,
    ];
  }
}

/// A fresh wall per open.
///
/// [NotifierProvider.autoDispose] rather than a kept-alive provider: with no
/// listener the controller and its [FeedState] are dropped the moment the screen
/// pops, so opening a second author starts clean instead of inheriting the first
/// author's list, cursor, and liked set. The uid lives in the instance, so a
/// shared long-lived controller would otherwise show one author under another's
/// name.
final NotifierProvider<UserPostsController, FeedState>
userPostsControllerProvider = NotifierProvider.autoDispose<
  UserPostsController,
  FeedState
>(UserPostsController.new);
