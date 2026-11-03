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
@immutable
final class FeedState {
  const FeedState({
    this.status = FeedStatus.initial,
    this.posts = const <Post>[],
    this.cursor,
    this.hasMore = false,
    this.failure,
    this.loaded = false,
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
  }) {
    return FeedState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      cursor: cursor ?? this.cursor,
      hasMore: hasMore ?? this.hasMore,
      failure: clearFailure ? null : (failure ?? this.failure),
      loaded: loaded ?? this.loaded,
    );
  }

  @override
  String toString() =>
      'FeedState($status, ${posts.length} posts, hasMore: $hasMore)';
}
