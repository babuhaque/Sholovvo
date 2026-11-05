import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sholovvo_app/core/logging/app_logger.dart';

/// Reads the viewer's existing likes for a set of posts.
///
/// The like document path is `posts/{postId}/likes/{uid}` where the uid IS the
/// document ID. Firestore's collection-group query cannot filter by the last
/// path segment, so hydration uses targeted single-document reads: one per post
/// in the visible page. A page of 10 costs 10 existence reads per cold start.
abstract interface class LikeHydrationService {
  /// Returns the subset of [postIds] for which [uid] has a like document.
  ///
  /// Never throws: a read failure on any individual post silently excludes it
  /// from the result (the worst case is a missing heart, not a crashed feed).
  Future<Set<String>> fetchLikedPostIds(List<String> postIds, String uid);
}

/// Firestore-backed implementation.
///
/// Uses `Future.wait` to issue all reads concurrently and tolerates individual
/// failures. The check is a targeted `.get()` on `posts/{postId}/likes/{uid}`;
/// `exists` is all we need — no payload is read.
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

    final List<Future<bool>> checks = postIds.map((String postId) async {
      try {
        final DocumentSnapshot<Map<String, dynamic>> snap = await _firestore
            .collection('posts')
            .doc(postId)
            .collection('likes')
            .doc(uid)
            .get(const GetOptions(source: Source.server));
        return snap.exists;
      } on FirebaseException catch (e) {
        _logger.warning(
          'Like hydration read failed for post $postId: ${e.code}',
        );
        return false;
      }
    }).toList();

    final List<bool> results = await Future.wait<bool>(checks);

    final Set<String> liked = <String>{};
    for (int i = 0; i < postIds.length; i++) {
      if (results[i]) {
        liked.add(postIds[i]);
      }
    }
    return liked;
  }
}
