import 'package:sholovvo_app/features/feed/data/like_hydration_service.dart';

/// A configurable [LikeHydrationService] for controller tests.
///
/// Returns a preset set of "liked" post IDs and records the calls received.
class FakeLikeHydrationService implements LikeHydrationService {
  /// The set returned when [fetchLikedPostIds] is called.
  Set<String> likedIds = <String>{};

  /// Post-id lists received, for assertions.
  final List<List<String>> calls = <List<String>>[];

  /// The uid passed on the last call, or null.
  String? lastUid;

  @override
  Future<Set<String>> fetchLikedPostIds(
    List<String> postIds,
    String uid,
  ) async {
    calls.add(postIds);
    lastUid = uid;
    return likedIds;
  }
}
