import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/data/post_like_service.dart';

/// A recording [PostLikeService] for controller tests.
///
/// Tracks calls + returns a configurable result, so a test can exercise the
/// optimistic-toggle and rollback paths without a Firestore instance.
class FakePostLikeService implements PostLikeService {
  final List<String> likeCalls = <String>[];
  final List<String> unlikeCalls = <String>[];

  /// When set, both methods return this failure instead of success.
  Failure? failure;

  @override
  Future<Result<void>> like(String postId, String uid) async {
    likeCalls.add(postId);
    if (failure != null) {
      return FailureResult<void>(failure!);
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> unlike(String postId, String uid) async {
    unlikeCalls.add(postId);
    if (failure != null) {
      return FailureResult<void>(failure!);
    }
    return const Success<void>(null);
  }
}
