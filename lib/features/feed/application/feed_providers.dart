import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/logging/app_logger.dart';
import 'package:sholovvo_app/core/media/gallery_saver.dart';
import 'package:sholovvo_app/core/preferences/app_preferences.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/application/feed_state.dart';
import 'package:sholovvo_app/features/feed/data/feed_count_hydration_service.dart';
import 'package:sholovvo_app/features/feed/data/firestore_feed_documents.dart';
import 'package:sholovvo_app/features/feed/data/firestore_feed_repository.dart';
import 'package:sholovvo_app/features/feed/data/like_hydration_service.dart';
import 'package:sholovvo_app/features/feed/data/post_edit_service.dart';
import 'package:sholovvo_app/features/feed/data/post_like_service.dart';
import 'package:sholovvo_app/features/feed/data/saved_posts_service.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/feed_page.dart';
import 'package:sholovvo_app/features/feed/domain/feed_repository.dart';

/// The signed-in user's uid, or null.
///
/// A separate provider so that widget tests can override it without needing
/// a full Firebase initialization, and so the controller can read the uid
/// lazily only when hydration is needed.
final Provider<String?> authUidProvider = Provider<String?>((Ref ref) {
  try {
    return FirebaseAuth.instance.currentUser?.uid;
  } catch (_) {
    return null;
  }
});

/// The feed backend.
///
/// The one seam every feed test overrides: the screen and the controller depend
/// on [FeedRepository], so no widget or controller test needs a Firebase
/// project. Constructed lazily, like `profileRepositoryProvider`, so a tree that
/// never opens the feed never touches `FirebaseFirestore.instance` either.
final Provider<FeedRepository> feedRepositoryProvider =
    Provider<FeedRepository>((Ref ref) {
      return FirestoreFeedRepository(
        FirestoreFeedDocuments(
          FirebaseAuth.instance,
          FirebaseFirestore.instance,
        ),
      );
    });

/// The like/unlike write service.
///
/// Same lazy-constructed seam as [feedRepositoryProvider]: the controller calls
/// through the [PostLikeService] interface, so a test overrides this one
/// provider and never touches a live Firestore.
final Provider<PostLikeService> postLikeServiceProvider =
    Provider<PostLikeService>((Ref ref) {
      return FirestorePostLikeService(FirebaseFirestore.instance);
    });

/// The like-hydration read service.
///
/// Queries which of the currently visible posts the signed-in user liked.
/// Overridden in tests with a fake.
final Provider<LikeHydrationService> likeHydrationServiceProvider =
    Provider<LikeHydrationService>((Ref ref) {
      return FirestoreLikeHydrationService(FirebaseFirestore.instance);
    });

/// The derived social-count read service.
///
/// Reads each visible post's real like and comment totals from the
/// `likes`/`comments` subcollections with an aggregate `count()` query, because
/// the post document's counters are no longer written by any client (rules keep
/// them immutable; the count is derived). Overridden in tests with a fake.
final Provider<FeedCountHydrationService> feedCountHydrationServiceProvider =
    Provider<FeedCountHydrationService>((Ref ref) {
      return FirestoreFeedCountHydrationService(FirebaseFirestore.instance);
    });

/// The local saved-posts persistence service.
///
/// Reads/writes bookmarked post ids to SharedPreferences via the already-loaded
/// [PreferencesStore.raw]. Overridden in tests with a fake.
final Provider<SavedPostsService> savedPostsServiceProvider =
    Provider<SavedPostsService>((Ref ref) {
      return PrefsSavedPostsService(ref.read(preferencesStoreProvider).raw);
    });

/// The post-text edit service.
///
/// Updates an existing post's text, `editedAt`, and `updatedAt`. Overridden in
/// tests with a fake.
final Provider<PostEditService> postEditServiceProvider =
    Provider<PostEditService>((Ref ref) {
      return FirestorePostEditService(FirebaseFirestore.instance);
    });

/// The save-to-gallery seam used by the full-screen image viewer.
///
/// `gal` and `http` both reach the platform, so the viewer depends on this
/// [GallerySaver] interface rather than the packages directly. Overridden in
/// tests with a fake, exactly like the like/save services above.
final Provider<GallerySaver> gallerySaverProvider = Provider<GallerySaver>(
  (Ref ref) => const HttpGallerySaver(),
);

/// Owns the feed's pages.
///
/// Three operations, and the difference between them is the whole point:
///
/// * [loadFirstPage] replaces the list. It is what the screen calls on mount,
///   what "Try again" calls after a failure, and what the pull gesture calls.
/// * [refresh] is the same request under the name the gesture uses; kept as a
///   separate method so the screen says what it means.
/// * [loadMore] appends the next page and is the only one that consumes the
///   cursor.
///
/// **One read at a time.** A pull-to-refresh landing on top of a page-in-flight
/// would produce two overlapping writes to the same state and a list whose
/// second half belongs to a different window; a second tap on "Load more" would
/// pay for the same page twice. Both are prevented by one flag rather than by
/// disabling buttons, because the gesture is not a button.
///
/// **An empty page is not an empty feed.** [FirestoreFeedRepository] refuses
/// documents it cannot map rather than guessing at them, and it decides
/// `hasMore` from the raw document count. Those two truths combine into a page
/// that carries no post at all while the collection still has plenty: see
/// [maxEmptyPages].
class FeedController extends Notifier<FeedState> {
  bool _fetching = false;

  static const AppLogger _logger = AppLogger('feed.read');

  /// How many unreadable pages one operation walks past before it stops and
  /// lets the donor decide.
  ///
  /// Walking is correct because the cursor addresses *raw* documents, not posts:
  /// a refused document still moves it, so the next window starts where this one
  /// ended and nothing is skipped or repeated. It is bounded because a collection
  /// malformed all the way down is a data incident, not a bottom of the list, and
  /// an unbounded loop would pay for a read every frame until the app is closed.
  /// Five pages is fifty documents scanned on one tap — far past any plausible
  /// run of bad writes — and the screen keeps offering "Load more" throughout,
  /// so the walk continues by choice rather than by machinery. Exposed so a test
  /// can pin the boundary rather than guess at it.
  static const int maxEmptyPages = 5;

  /// Whether a read is in flight. Exposed for tests and for the screen's
  /// footer, which must not offer "Load more" while one is running.
  bool get isFetching => _fetching;

  @override
  FeedState build() {
    // Defensive read: in tests the preferencesStoreProvider may not be
    // overridden, causing savedPostsServiceProvider to throw. Fallback to an
    // empty set so existing test harnesses remain unaffected.
    Set<String> saved;
    try {
      saved = ref.read(savedPostsServiceProvider).load();
    } catch (_) {
      saved = <String>{};
    }
    return FeedState(savedPostIds: saved);
  }

  /// Reads page one, replacing whatever is on screen.
  Future<void> loadFirstPage() {
    if (_fetching) {
      return Future<void>.value();
    }
    return _read(after: null, append: false);
  }

  /// The pull-to-refresh request. Identical to [loadFirstPage] by construction:
  /// a refresh *is* a first page, and having two code paths is how one of them
  /// ends up not resetting the cursor.
  Future<void> refresh() => loadFirstPage();

  /// Puts a just-published post at the top of the list.
  ///
  /// Refused when no page has resolved: the first page replaces the list
  /// outright, so a post prepended into an untouched feed would either be lost
  /// or make an empty feed look non-empty before anything was read. Once a page
  /// is on screen, showing the new post immediately is the difference between
  /// "published" and "published, but where?".
  ///
  /// No cursor is touched. The post is newer than the window the cursor
  /// addresses, so page two is unaffected by its arrival.
  void prepend(Post post) {
    if (!state.loaded) {
      return;
    }
    if (state.posts.any((Post existing) => existing.id == post.id)) {
      return;
    }
    state = state.copyWith(posts: <Post>[post, ...state.posts]);
  }

  /// Appends the page after the current cursor.
  Future<void> loadMore() {
    if (_fetching || !state.hasMore) {
      return Future<void>.value();
    }
    final FeedCursor? cursor = state.cursor;
    if (cursor == null) {
      // `hasMore` without a cursor cannot happen — the repository sets both
      // together — but asking the database for "the page after nowhere" would
      // be worse than doing nothing.
      return Future<void>.value();
    }
    return _read(after: cursor, append: true);
  }

  /// Increments the comment count on a visible post.
  ///
  /// Called by the comment sheet after a successful write, so the tile the
  /// donor tapped reflects the new count without a full feed refresh.
  void incrementCommentCount(String postId) {
    final int index = state.posts.indexWhere((Post p) => p.id == postId);
    if (index < 0) {
      return;
    }
    final Post original = state.posts[index];
    final Post updated = original.withCommentCount(original.commentCount + 1);
    final List<Post> next = List<Post>.from(state.posts);
    next[index] = updated;
    state = state.copyWith(posts: next);
  }

  /// Called by the comment sheet after a successful delete, so the tile
  /// reflects the reduced count without a full feed refresh.
  void decrementCommentCount(String postId) {
    final int index = state.posts.indexWhere((Post p) => p.id == postId);
    if (index < 0) {
      return;
    }
    final Post original = state.posts[index];
    final Post updated =
        original.withCommentCount((original.commentCount - 1).clamp(0, 1 << 31));
    final List<Post> next = List<Post>.from(state.posts);
    next[index] = updated;
    state = state.copyWith(posts: next);
  }

  /// Toggles the current user's like on the given post.
  ///
  /// Optimistic: the UI updates immediately; the Firestore transaction runs
  /// behind it. If the write fails (network, permission, missing post), the
  /// local state rolls back and the error is logged but not shown as a snackbar
  /// (a silent reversion is less disruptive than a popup for a misfire).
  ///
  /// No-op when the post is not visible in the current list.
  Future<void> toggleLike(String postId, String uid) async {
    // Locate the post to adjust its count.
    final int index = state.posts.indexWhere(
      (Post p) => p.id == postId,
    );
    if (index < 0) {
      return;
    }

    final bool wasLiked = state.likedPostIds.contains(postId);
    final Post original = state.posts[index];
    final Post updated = original.withLikeCount(
      wasLiked ? original.likeCount - 1 : original.likeCount + 1,
    );

    // Optimistic: flip the like in local state before awaiting the write.
    final Set<String> nextLiked = Set<String>.from(state.likedPostIds);
    if (wasLiked) {
      nextLiked.remove(postId);
    } else {
      nextLiked.add(postId);
    }
    final List<Post> nextPosts = List<Post>.from(state.posts);
    nextPosts[index] = updated;
    state = state.copyWith(posts: nextPosts, likedPostIds: nextLiked);

    // Write to the backend.
    final PostLikeService service = ref.read(postLikeServiceProvider);
    final Result<void> result = wasLiked
        ? await service.unlike(postId, uid)
        : await service.like(postId, uid);

    // Roll back on failure.
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

  /// Fetches which of the currently visible posts [uid] has liked, and the
  /// server-authoritative like/comment counts for every visible post, and merges
  /// both into the list on screen.
  ///
  /// Fire-and-forget after the first page resolves. Likes are applied first, on
  /// their own, and a failure of either read is swallowed: a missing heart or a
  /// stale zero is a minor visual gap that self-heals on the next toggle or
  /// refresh, whereas a thrown exception would take the feed down. The count
  /// read is defensive (its provider reaches for a live Firestore) so a test
  /// that exercises likes without overriding the count seam is unaffected.
  Future<void> _hydrate(String uid) async {
    final List<String> postIds = state.posts.map((Post p) => p.id).toList();
    if (postIds.isEmpty) {
      return;
    }

    // 1. The viewer's own likes.
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

    // 2. The derived counts, applied after likes so the two reads cannot race
    //    on the same posts list (each does a read-modify-write of `state`).
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
      // No count seam available (test environment) or the read failed: the
      // optimistic counts already on screen stand until the next load.
    }
  }

  /// Toggles the bookmark on [postId] and persists the full set.
  void toggleSave(String postId) {
    final Set<String> next = Set<String>.from(state.savedPostIds);
    if (!next.remove(postId)) {
      next.add(postId);
    }
    state = state.copyWith(savedPostIds: next);
    // Persist fire-and-forget: a failed write means the bookmark is lost on
    // the next cold start, not that tapping the icon should throw.
    try {
      final SavedPostsService service = ref.read(savedPostsServiceProvider);
      unawaited(service.save(next));
    } catch (_) {
      // No persistence available (test environment); state update is sufficient.
    }
  }

  /// Toggles the "Saved only" filter on the feed list.
  void toggleSavedFilter() {
    state = state.copyWith(showOnlySaved: !state.showOnlySaved);
  }

  Future<void> _read({required FeedCursor? after, required bool append}) async {
    if (_fetching) {
      return;
    }
    _fetching = true;

    // A refresh with posts on screen keeps them: the list is still true, and
    // blanking it for a spinner is a worse answer than showing stale-but-real
    // posts for another second.
    state = append
        ? state.copyWith(status: FeedStatus.loadingMore, clearFailure: true)
        : (state.posts.isEmpty
              ? state.copyWith(status: FeedStatus.loading, clearFailure: true)
              : state.copyWith(clearFailure: true));

    try {
      FeedCursor? cursor = after;
      int emptyPages = 0;

      /// Documents refused by the pages this operation walked over, before the
      /// list they belong to is decided. Kept separate from the state until the
      /// read resolves, because a read that failed has not refused anything to
      /// the donor — it has told them it could not read at all.
      int refused = 0;
      FeedPage page;

      // The walk. A page is accepted as soon as it carries a post, or as soon
      // as there is no further page to ask for; otherwise the cursor it carries
      // is used to ask again, up to [maxEmptyPages] times. Only a *successful*
      // read extends the walk — a refused one leaves below, unanswered.
      while (true) {
        final Result<FeedPage> result = await ref
            .read(feedRepositoryProvider)
            .loadPage(after: cursor);
        final FeedPage? resolved = result.valueOrNull;

        if (resolved == null) {
          // The cursor is deliberately not consumed, and posts are kept, so the
          // retry re-asks the same question and an already-visible page survives
          // a failure to extend it.
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
        // `cursor ??` rather than `cursor = page.cursor`: a repository that
        // answers with neither a post nor a position would otherwise re-ask the
        // same page forever. It cannot happen by the domain's contract, and the
        // bound above would stop it anyway, but the loop must not *depend* on
        // either.
        cursor = page.cursor ?? cursor;
      }

      // A first-page read that walked to its cap without finding a readable
      // document keeps what the donor can already see. Refusing to show *new*
      // posts is what the bad writes earned; blanking the good old ones is a
      // second, unearned penalty, and `hasMore` stays true so the footer still
      // offers the way on.
      final bool keepsExisting = append || (page.posts.isEmpty && page.hasMore);
      final List<Post> next = keepsExisting
          ? _append(state.posts, page.posts)
          : page.posts;

      // The count belongs to the list, not to the last read: documents refused
      // by an earlier page are still missing from what is on screen, so a read
      // that appends adds its refusals to the ones already there rather than
      // replacing them, and a read that replaces the list resets the account.
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

      // The operator-facing half of the count. A screen can only say "some posts
      // could not be shown" to the person standing in front of it; this line is
      // what reaches whoever maintains the collection, and it names the number
      // rather than a document id so no other donor's post content lands in a
      // log. It warns rather than logs at info because a mapper that is refusing
      // documents means the stored data has drifted from the schema, which is
      // what the rules reconciliation needs to be told about.
      if (skippedTotal > 0) {
        _logger.warning(
          'Feed read skipped $skippedTotal unreadable post document(s)',
        );
      }

      // Hydrate likes after a non-append read (first page / refresh).
      // Fire-and-forget: a missing heart self-corrects on the next toggle,
      // and blocking the read on this is worse UX than a late fill-in.
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

  /// Joins a new page onto the list without duplicating a post.
  ///
  /// A snapshot cursor already makes duplicates unlikely, so this is a guard
  /// rather than a mechanism: if a document is rewritten with a new `createdAt`
  /// between two requests it can legitimately appear twice, and a feed that
  /// shows the same post twice looks broken even when the database agreed.
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

final NotifierProvider<FeedController, FeedState> feedControllerProvider =
    NotifierProvider<FeedController, FeedState>(FeedController.new);
