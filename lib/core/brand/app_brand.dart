/// Single source of truth for outward-facing brand identity.
///
/// The supplied logo artwork reads "Sholovvo" while the product brief
/// consistently uses "Solovvo". The brief wins for user-facing copy, and the
/// spelling is centralised here so it stays a one-line change.
abstract final class AppBrand {
  /// Product name shown to users (app title, store listing, splash text).
  static const String name = 'Solovvo';

  /// Tagline from the supplied logo artwork.
  static const String tagline = 'Save Lives • Connect Hearts';

  /// Legal/company name used in policy documents (Stage 13).
  static const String legalName = 'Solovvo';

  /// Firebase project that every environment connects to.
  static const String firebaseProjectId = 'sholovvo-blood-donation';

  /// Package identifier used in URLs, analytics and support mail.
  static const String slug = 'sholovvo';
}
