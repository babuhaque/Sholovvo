import 'package:flutter/foundation.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/feed_page.dart';

/// What the feed is doing right now.
///
/// [loadingMore] is a separate state from [loading] on purpose: a first page
/// replaces the list and may show a full-height spinner, while a later page
/// appends to a list the donor is already reading and must only spin at the
/// bottom. Collapsing them would either flash an empty screen on every page or
/// leave the first load looking stuck.
enum FeedStatus { initial, loading, ready, loadingMore, failure }

/// Everything the feed screen draws, in one immutable value.
///
/// The list, the cursor and [hasMore] travel together because they are only
/// meaningful together: a cursor without its list is a position in a document
/// the screen is not showing, and a list without [hasMore] cannot say whether
/// scrolling to the bottom achieved anything.
///
/// [skipped] travels with them for the same reason. A shorter list is only
/// honest if the screen can say whether the collection was empty or merely
/// unreadable, and that answer belongs to the read that produced the list, not
/// to a second question asked later.
@immutable
final class FeedState {
  const FeedState({
    this.status = FeedStatus.initial,
    this.posts = const <Post>[],
    this.cursor,
    this.hasMore = false,
    this.failure,
    this.loaded = false,
    this.skipped = 0,
    this.likedPostIds = const <String>{},
    this.savedPostIds = const <String>{},
    this.showOnlySaved = false,
  });

  final FeedStatus status;

  /// Newest first, as the repository returned them.
  final List<Post> posts;

  /// Where the next page starts. `null` until a page has been read.
  final FeedCursor? cursor;

  /// Whether another page exists.
  final bool hasMore;

  /// Why the last read failed, or `null`.
  ///
  /// It survives alongside posts on purpose: a refresh that fails should not
  /// throw away the posts the donor is reading, and it should not pretend the
  /// failure did not happen either. The screen shows the list *and* a banner.
  final Failure? failure;

  /// Whether a first page has ever resolved. Distinguishes "no posts yet"
  /// (empty and loaded) from "nothing has been asked for" (empty and untouched),
  /// which are the same list but very different sentences.
  final bool loaded;

  /// How many documents the reads that produced [posts] could not turn into a
  /// post.
  ///
  /// Accumulated across a bounded empty-page walk and across pages, so it counts
  /// every refusal behind what is on screen rather than only the last page's. It
  /// is not a failure: a refused document does not fail a read. It is the number
  /// that tells a donor their list is shorter than the collection, and tells
  /// whoever maintains this app that the collection has drifted from the mapper.
  final int skipped;

  /// The set of post ids the current user has liked.
  ///
  /// Hydrated from the server on first-page load (targeted existence reads
  /// per visible post) and grown by session-local toggle actions. A refresh
  /// preserves this set and merges new server data into it.
  final Set<String> likedPostIds;

  /// The set of post ids the user has bookmarked locally.
  ///
  /// Persisted to SharedPreferences; hydrated on controller build.
  final Set<String> savedPostIds;

  /// Whether the feed is showing only bookmarked posts.
  final bool showOnlySaved;

  bool get isEmpty => posts.isEmpty;

  /// A first load or retry with nothing on screen — the one case that earns a
  /// full-height spinner.
  bool get isInitialLoading =>
      posts.isEmpty &&
      (status == FeedStatus.loading || status == FeedStatus.initial);

  /// Nothing to show, nothing pending, and nothing further to ask for: the
  /// honest empty state.
  ///
  /// The `!hasMore` term is what makes this honest. A page whose documents were
  /// all refused by the mapper is an empty *page* without being an empty
  /// *collection*, and calling that "no posts yet" would strand the donor above
  /// a list they have no control left to page past — the screen renders this
  /// branch instead of the list and its footer, so the one "Load more" that
  /// could reach the readable posts behind the bad writes would never be drawn.
  bool get isEmptyResult =>
      posts.isEmpty && loaded && !hasMore && status != FeedStatus.loading;

  /// Nothing to show, and the collection is *not* exhausted: the newest window
  /// was read, refused every document it held, and there are more behind it.
  ///
  /// The mirror image of [isEmptyResult] — same guards, [hasMore] inverted — and
  /// the reason both exist: "no posts yet" and "the posts could not be read" are
  /// one empty list apart and completely different claims. A screen that cannot
  /// tell them apart tells a donor their community is quiet when the app has
  /// actually failed to read it.
  ///
  /// [FeedStatus.loadingMore] is excluded as well as [FeedStatus.loading]. The
  /// two exclusions are not the same kind of caution, so the difference is worth
  /// stating: a first load has nothing to show yet and earns the full-height
  /// spinner above this getter, while a later page is being asked for *behind* an
  /// empty list the screen is already drawing, and replacing that list with a
  /// card would hide the footer spinner which is the only proof the tap landed.
  /// [isEmptyResult] needs no such term: it requires `!hasMore`, and a page is
  /// only ever requested while `hasMore` is true, so the two can never overlap.
  bool get isUnreadableResult =>
      posts.isEmpty &&
      loaded &&
      hasMore &&
      status != FeedStatus.loading &&
      status != FeedStatus.loadingMore;

  /// An error with nothing behind it, so the screen has to say so in place of
  /// the list rather than above it.
  bool get isFatalError =>
      posts.isEmpty && status == FeedStatus.failure && failure != null;

  FeedState copyWith({
    FeedStatus? status,
    List<Post>? posts,
    FeedCursor? cursor,
    bool? hasMore,
    Failure? failure,
    bool clearFailure = false,
    bool? loaded,
    int? skipped,
    Set<String>? likedPostIds,
    Set<String>? savedPostIds,
    bool? showOnlySaved,
  }) {
    return FeedState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      cursor: cursor ?? this.cursor,
      hasMore: hasMore ?? this.hasMore,
      failure: clearFailure ? null : (failure ?? this.failure),
      loaded: loaded ?? this.loaded,
      skipped: skipped ?? this.skipped,
      likedPostIds: likedPostIds ?? this.likedPostIds,
      savedPostIds: savedPostIds ?? this.savedPostIds,
      showOnlySaved: showOnlySaved ?? this.showOnlySaved,
    );
  }

  @override
  String toString() =>
      'FeedState($status, ${posts.length} posts, hasMore: $hasMore, '
      'skipped: $skipped)';
}
