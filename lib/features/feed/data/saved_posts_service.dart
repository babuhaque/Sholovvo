import 'package:shared_preferences/shared_preferences.dart';

/// Stores which post ids the user has bookmarked, on-device.
///
/// A simple set persisted as a `StringList` under [key]. No server round-trip:
/// a bookmark is a private reading-list aid, not a signal to the community.
abstract interface class SavedPostsService {
  /// The set of saved post ids currently on disk.
  Set<String> load();

  /// Persists the full set (replaces whatever was stored).
  Future<void> save(Set<String> ids);
}

/// SharedPreferences-backed implementation.
///
/// Reads are synchronous because [SharedPreferences] resolves once before
/// `runApp` (the same instance `PreferencesStore` uses); after that, `getStringList`
/// is a map lookup.
final class PrefsSavedPostsService implements SavedPostsService {
  const PrefsSavedPostsService(this._prefs);

  final SharedPreferences _prefs;

  static const String key = 'feed.savedPostIds';

  @override
  Set<String> load() {
    final List<String>? list = _prefs.getStringList(key);
    return list == null ? <String>{} : <String>{...list};
  }

  @override
  Future<void> save(Set<String> ids) {
    return _prefs.setStringList(key, ids.toList());
  }
}
