import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/domain/feed_page.dart';

/// The feed's read side.
///
/// One method, and it stays one method: publishing lives on [PostRepository], a
/// separate port, because a reader and a writer are used by different screens
/// and tested against different fakes. Folding them together would make every
/// read fake answer a write question it has no opinion about — which is how a
/// stub that throws ends up in a test and then in an untested branch.
///
/// Returns `Result` rather than throwing, like every other repository in this
/// app: "the feed is empty" and "the feed could not be read" are different
/// sentences on screen, and flattening them into an empty list would tell a
/// donor there is nothing to see when the truth is that nobody knows.
abstract interface class FeedRepository {
  /// How many posts one page carries.
  ///
  /// Ten, not twenty: the card shows up to five images, so a page is already
  /// several screenfuls, and the Spark plan's daily read quota is spent per
  /// document. It is a constant here rather than a literal in the controller so
  /// a test can assert against the number the query actually uses.
  static const int pageSize = 10;

  /// Reads one page, newest first.
  ///
  /// [after] is the cursor from the previous page; `null` reads the first page.
  /// Never reads more than `pageSize` posts, whatever the caller passes.
  ///
  /// [authorUid] narrows the page to one author's posts (the tap-through
  /// "author posts" screen). `null` — the whole feed's default — reads every
  /// author, exactly as before, so no existing caller changes. Narrowing to a
  /// single author is what makes the read need a composite index
  /// (`authorUid` + `createdAt`); see `firestore.indexes.json`.
  Future<Result<FeedPage>> loadPage({FeedCursor? after, String? authorUid});
}
