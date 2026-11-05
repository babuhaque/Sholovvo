import 'package:sholovvo_app/features/feed/data/saved_posts_service.dart';

/// In-memory [SavedPostsService] for tests.
final class FakeSavedPostsService implements SavedPostsService {
  FakeSavedPostsService({Set<String>? initialIds})
      : _ids = initialIds != null ? Set<String>.from(initialIds) : <String>{};

  Set<String> _ids;

  /// The set most recently passed to [save].
  Set<String> get savedIds => _ids;

  int saveCallCount = 0;

  @override
  Set<String> load() => <String>{..._ids};

  @override
  Future<void> save(Set<String> ids) async {
    saveCallCount++;
    _ids = Set<String>.from(ids);
  }
}
