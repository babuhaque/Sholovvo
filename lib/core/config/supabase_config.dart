import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Why a key handed to the build cannot be used from a Flutter client.
///
/// Reported instead of silently ignoring the value: a secret key pasted into
/// `--dart-define` has already been copied into a shell history and, in a
/// release build, into the bundle. The client refuses to use it so the mistake
/// cannot turn into an anonymous backdoor on the bucket, and the reason is kept
/// so the mistake is visible rather than looking like "not configured".
enum SupabaseKeyRejection {
  /// A `sb_secret_...` key: Supabase's server-side key, the successor to the
  /// service-role JWT. It bypasses every row-level security policy.
  secretKey,

  /// A JWT whose payload carries `"role": "service_role"`, i.e. the legacy
  /// service-role key. Same privileges as [secretKey].
  serviceRoleToken,
}

/// Supabase Storage configuration, resolved once during bootstrap.
///
/// **Only the publishable (anon) key may ever be in this object.** The
/// service-role key bypasses row-level security, and anything shipped in a
/// Flutter bundle is readable by whoever installs the app — on web it is a GET
/// away. [rejectPrivilegedKey] is a guardrail against that mistake, not a
/// substitute for keeping the secret out of the build in the first place.
///
/// Values arrive as compile-time defines, matching [AppConfig]:
///
/// ```
/// flutter run --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
///             --dart-define=SUPABASE_ANON_KEY=<publishable key>
/// ```
///
/// With neither define present the app is simply *not configured* for photo
/// storage: the profile still works, and the photo sheet says so instead of
/// showing a control that cannot succeed.
final class SupabaseConfig {
  const SupabaseConfig({
    this.url = '',
    this.publishableKey = '',
    this.avatarBucket = defaultAvatarBucket,
    this.postImagesBucket = defaultPostImagesBucket,
    this.rejection,
  });

  /// Reads the compile-time defines described on the class.
  ///
  /// A rejected key is dropped rather than kept and flagged, so no code path
  /// can accidentally hand it to an HTTP header.
  factory SupabaseConfig.fromEnvironment() {
    const String rawUrl = String.fromEnvironment('SUPABASE_URL');
    const String rawKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    final SupabaseKeyRejection? rejection = rejectPrivilegedKey(rawKey);
    return SupabaseConfig(
      url: rawUrl.trim(),
      publishableKey: rejection == null ? rawKey.trim() : '',
      rejection: rejection,
    );
  }

  /// The bucket profile photos live in.
  ///
  /// One bucket with a per-user folder (`{uid}/...`) rather than a bucket per
  /// donor: bucket count is a project-wide resource, and namespacing by folder
  /// is what the storage policies in `docs/storage/` are written against.
  static const String defaultAvatarBucket = 'avatars';

  /// The bucket community post photos live in.
  ///
  /// A second bucket rather than a subfolder of [defaultAvatarBucket], because
  /// the two have different lifetimes and different limits: an avatar is
  /// replaced in place and at most one exists per account, while post photos
  /// accumulate four per post and outlive the screen that uploaded them. Keeping
  /// them apart also means a policy mistake on one cannot expose the other.
  static const String defaultPostImagesBucket = 'post-images';

  /// Project URL, e.g. `https://abcdefgh.supabase.co`. Empty when unset.
  final String url;

  /// The publishable/anon key. Never a secret key — see [rejection].
  final String publishableKey;

  final String avatarBucket;

  final String postImagesBucket;

  /// Non-null when the build supplied a key this client must not use.
  final SupabaseKeyRejection? rejection;

  /// Whether photo upload can be attempted at all.
  ///
  /// False for a missing URL, a missing key, a malformed URL or a rejected key.
  /// The screens turn this into a sentence rather than a disabled-looking no-op.
  bool get isConfigured =>
      rejection == null && publishableKey.isNotEmpty && _isUsableUrl(url);

  /// The storage API base, or `null` when unconfigured.
  ///
  /// `storage_client` appends `object/...` to this value, so it ends at
  /// `/storage/v1`, the same URL the Supabase SDK passes.
  String? get storageUrl {
    final Uri? base = Uri.tryParse(url);
    if (!isConfigured || base == null) {
      return null;
    }
    return '${base.origin}/storage/v1';
  }

  /// https only: an `http` endpoint would put the bearer token on the wire in
  /// clear text, and no Supabase project is served over plain http anyway.
  static bool _isUsableUrl(String value) {
    final Uri? parsed = Uri.tryParse(value);
    return parsed != null &&
        parsed.isScheme('https') &&
        parsed.host.isNotEmpty &&
        parsed.host.contains('.');
  }

  /// Classifies a key as usable-from-the-client or privileged.
  ///
  /// Two shapes exist: the new `sb_publishable_`/`sb_secret_` keys, and the
  /// legacy JWTs. Both current publishable forms return `null` (usable).
  static SupabaseKeyRejection? rejectPrivilegedKey(String raw) {
    final String key = raw.trim();
    if (key.isEmpty) {
      return null;
    }
    if (key.startsWith('sb_secret_')) {
      return SupabaseKeyRejection.secretKey;
    }
    // A JWT is three base64url segments; only the payload matters here.
    final List<String> parts = key.split('.');
    if (parts.length != 3) {
      return null;
    }
    final Map<String, dynamic>? payload = _decodeJwtPayload(parts[1]);
    if (payload != null && payload['role'] == 'service_role') {
      return SupabaseKeyRejection.serviceRoleToken;
    }
    return null;
  }

  /// The JWT payload, or `null` when the segment is not a JSON object.
  ///
  /// Deliberately tolerant: this runs on startup with arbitrary input, and a
  /// key that cannot be decoded is treated as "not recognised" rather than
  /// crashing the app. The signature is *not* verified — the value is only
  /// inspected to keep a secret out of the client, never trusted as identity.
  static Map<String, dynamic>? _decodeJwtPayload(String segment) {
    try {
      final String padded = base64Url.normalize(segment);
      final Object? decoded = json.decode(utf8.decode(base64Url.decode(padded)));
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  @override
  String toString() =>
      'SupabaseConfig(url: ${url.isEmpty ? '(unset)' : url}, '
      'configured: $isConfigured, rejection: $rejection)';
}

/// Replaced with the resolved value by [ProviderScope] overrides in bootstrap.
///
/// Throwing by default, exactly like `appConfigProvider`: a screen that reaches
/// photo storage before configuration exists fails loudly instead of quietly
/// behaving as if uploads were switched off.
final Provider<SupabaseConfig> supabaseConfigProvider =
    Provider<SupabaseConfig>(
      (Ref ref) => throw UnimplementedError(
        'supabaseConfigProvider must be overridden in bootstrap() with '
        'SupabaseConfig.fromEnvironment().',
      ),
    );
