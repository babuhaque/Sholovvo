import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sholovvo_app/core/logging/app_logger.dart';
import 'package:sholovvo_app/features/feed/data/models/post_document.dart';

/// Reads the viewer's existing likes for a set of posts.
///
/// Likes live in the flat `post_likes` collection (`{postId, userId,
/// createdAt}`), the shape the live database actually uses. One query per page
/// — `userId == me` and `postId in [visible ids]` — returns exactly the posts
/// the viewer has liked, so a page of 10 costs a single read rather than ten
/// existence checks.
abstract interface class LikeHydrationService {
  /// Returns the subset of [postIds] for which [uid] has a like document.
  ///
  /// Never throws: a read failure silently yields an empty set (the worst case
  /// is a missing heart, not a crashed feed).
  Future<Set<String>> fetchLikedPostIds(List<String> postIds, String uid);
}

/// Firestore-backed implementation.
///
/// Chunks the ids to respect Firestore's 30-value `in` ceiling and issues one
/// query per chunk. A chunk that fails is logged and skipped, never propagated.
final class FirestoreLikeHydrationService implements LikeHydrationService {
  const FirestoreLikeHydrationService(this._firestore);

  final FirebaseFirestore _firestore;

  static final AppLogger _logger = AppLogger('feed.hydration');

  @override
  Future<Set<String>> fetchLikedPostIds(
    List<String> postIds,
    String uid,
  ) async {
    if (postIds.isEmpty) return const <String>{};

    final Set<String> liked = <String>{};
    // Firestore caps an `in` filter at 30 values, so walk the page in chunks.
    const int chunkSize = 30;
    for (int start = 0; start < postIds.length; start += chunkSize) {
      final int end =
          (start + chunkSize) < postIds.length
              ? start + chunkSize
              : postIds.length;
      final List<String> chunk = postIds.sublist(start, end);
      try {
        final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
            .collection(PostDocument.likesCollection)
            .where('userId', isEqualTo: uid)
            .where('postId', whereIn: chunk)
            .get(const GetOptions(source: Source.server));
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snap.docs) {
          final Object? postId = doc.data()['postId'];
          if (postId is String) liked.add(postId);
        }
      } on FirebaseException catch (e) {
        _logger.warning('Like hydration read failed: ${e.code}');
      }
    }
    return liked;
  }
}
