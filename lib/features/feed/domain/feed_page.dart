import 'package:flutter/foundation.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';

/// An opaque position in the feed's ordering.
///
/// Deliberately empty: the domain needs to carry a cursor from one page request
/// to the next, and that is all it needs. What the cursor actually is — in this
/// app a `DocumentSnapshot` — belongs to `data`, because naming it here would
/// put `cloud_firestore` in the domain layer and make every feed test require
/// the SDK to construct a page.
///
/// A cursor is only meaningful to the repository that produced it. Handing one
/// repository's cursor to another is not supported, and the data layer refuses a
/// cursor it does not recognise rather than guessing.
abstract interface class FeedCursor {}

/// One page of the feed, as the repository returns it.
///
/// **Paging is cursor-based, not offset-based.** A feed is ordered newest first
/// and is written to while it is read, so "skip 10, take 10" would show a post
/// twice or skip one every time somebody published. The cursor is the address of
/// the last document this page contained; the next request starts after it.
///
/// **[hasMore] is exact, not a guess.** The repository asks Firestore for one
/// document more than it returns, so a page that happens to end exactly on a
/// multiple of the page size does not produce a phantom "load more" that
/// resolves to nothing.
@immutable
final class FeedPage {
  FeedPage({
    required List<Post> posts,
    this.cursor,
    this.hasMore = false,
    this.skipped = 0,
  }) : posts = List<Post>.unmodifiable(posts);

  /// The posts that could be read, newest first.
  final List<Post> posts;

  /// Where the next page starts, or `null` when this page carried nothing.
  final FeedCursor? cursor;

  /// Whether there is at least one more post after [cursor].
  final bool hasMore;

  /// How many documents were refused by the mapper.
  ///
  /// A malformed document does not fail the page — one bad write must not hide
  /// twenty good posts — but it is counted so the number is visible to a test
  /// and to a log rather than silently vanishing into a shorter list.
  final int skipped;

  bool get isEmpty => posts.isEmpty;

  @override
  String toString() =>
      'FeedPage(${posts.length} posts, hasMore: $hasMore, skipped: $skipped)';
}
