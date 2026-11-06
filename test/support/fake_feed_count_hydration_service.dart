import 'package:sholovvo_app/features/feed/data/feed_count_hydration_service.dart';

/// A configurable [FeedCountHydrationService] for controller tests.
///
/// Returns whatever is in [counts] and records the post-id lists it was asked
/// for, so a test can assert the feed derived counts for the posts on screen.
class FakeFeedCountHydrationService implements FeedCountHydrationService {
  /// The map returned by [fetchCounts]. A post id absent from it is omitted
  /// exactly as the real service omits a post whose read failed.
  Map<String, PostCountSnapshot> counts = <String, PostCountSnapshot>{};

  /// Post-id lists received, for assertions.
  final List<List<String>> calls = <List<String>>[];

  /// When true, [fetchCounts] throws to exercise the defensive branch in the
  /// controller (a count seam that is unavailable must not take the feed down).
  bool throws = false;

  @override
  Future<Map<String, PostCountSnapshot>> fetchCounts(
    List<String> postIds,
  ) async {
    calls.add(postIds);
    if (throws) {
      throw StateError('count seam unavailable');
    }
    return counts;
  }
}
