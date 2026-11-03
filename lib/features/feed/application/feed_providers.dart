import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/application/feed_state.dart';
import 'package:sholovvo_app/features/feed/data/firestore_feed_documents.dart';
import 'package:sholovvo_app/features/feed/data/firestore_feed_repository.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/feed_page.dart';
import 'package:sholovvo_app/features/feed/domain/feed_repository.dart';

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
class FeedController extends Notifier<FeedState> {
  bool _fetching = false;

  /// Whether a read is in flight. Exposed for tests and for the screen's
  /// footer, which must not offer "Load more" while one is running.
  bool get isFetching => _fetching;

  @override
  FeedState build() => const FeedState();

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
      final Result<FeedPage> result = await ref
          .read(feedRepositoryProvider)
          .loadPage(after: after);
      final FeedPage? page = result.valueOrNull;

      if (page == null) {
        // The cursor is deliberately not consumed, and posts are kept, so the
        // retry re-asks the same question and an already-visible page survives
        // a failure to extend it.
        state = state.copyWith(
          status: state.posts.isEmpty ? FeedStatus.failure : FeedStatus.ready,
          failure: result.failureOrNull,
        );
        return;
      }

      state = FeedState(
        status: FeedStatus.ready,
        posts: append ? _append(state.posts, page.posts) : page.posts,
        cursor: page.cursor,
        hasMore: page.hasMore,
        loaded: true,
      );
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
