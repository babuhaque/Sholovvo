import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/domain/feed_page.dart';

/// One document exactly as the database returned it, plus the cursor that
/// addresses it.
///
/// The fields are left unreconstructed — a plain map with the wire's own
/// spellings — so that [PostDocument] is still the only thing that knows how a
/// post is written down. This class is a transport envelope and nothing more.
final class FeedDocument {
  const FeedDocument({
    required this.id,
    required this.fields,
    required this.cursor,
  });

  final String id;
  final Map<String, Object?> fields;

  /// A cursor pointing *at this document*, so the last one kept can be used to
  /// start the next page after it.
  final FeedCursor cursor;
}

/// The one thing [FirestoreFeedRepository] needs from the database.
///
/// It exists so pagination, mapping and page assembly can be tested against
/// literal maps and fake cursors, in the same style as the rest of the app's
/// repository tests: no emulator, no network, no Firebase app. The Firestore
/// implementation ([FirestoreFeedDocuments]) is the only class in the feature
/// that holds a `Query`.
abstract interface class FeedDocuments {
  /// Reads at most [limit] documents, newest first, starting after [after].
  ///
  /// Returns a failure rather than throwing, so the caller can tell "the read
  /// was refused" from "there were no posts".
  Future<Result<List<FeedDocument>>> fetch({
    required int limit,
    FeedCursor? after,
  });
}
