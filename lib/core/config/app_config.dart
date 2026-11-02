import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Build-time environment selector.
enum AppFlavor {
  development,
  staging,
  production;

  /// Parses `--dart-define=APP_FLAVOR=...`, defaulting to [development] so an
  /// un-flagged build can never silently behave as production.
  static AppFlavor fromName(String raw) {
    return AppFlavor.values.firstWhere(
      (flavor) => flavor.name == raw.trim().toLowerCase(),
      orElse: () => AppFlavor.development,
    );
  }
}

/// Immutable runtime configuration resolved once during bootstrap.
///
/// Only values that are genuinely environment- or policy-driven live here.
/// Secrets are never stored in this file: privileged keys (Firebase Admin,
/// Supabase service role) must never ship inside the client bundle.
final class AppConfig {
  const AppConfig({
    required this.flavor,
    this.emergencyDefaultRadiusKm = defaultEmergencyRadiusKm,
    this.allowedSearchRadiiKm = allowedSearchRadii,
  });

  /// Reads compile-time defines:
  /// `flutter run --dart-define=APP_FLAVOR=staging`.
  factory AppConfig.fromEnvironment() {
    const rawFlavor = String.fromEnvironment(
      'APP_FLAVOR',
      defaultValue: 'development',
    );
    return AppConfig(flavor: AppFlavor.fromName(rawFlavor));
  }

  /// Radius the emergency matcher starts with, per the product brief.
  static const int defaultEmergencyRadiusKm = 10;

  /// Radii offered in blood search and emergency radius escalation.
  static const List<int> allowedSearchRadii = <int>[5, 10, 15, 20];

  final AppFlavor flavor;

  /// Starting search radius for emergency donor matching.
  final int emergencyDefaultRadiusKm;

  /// Selectable radii, ascending.
  final List<int> allowedSearchRadiiKm;

  bool get isProduction => flavor == AppFlavor.production;

  bool get isDevelopment => flavor == AppFlavor.development;
}

/// Replaced with the real value by [ProviderScope] overrides in bootstrap.
///
/// Throwing by default guarantees a loud failure if someone reaches this
/// provider before configuration exists, instead of silently using defaults.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError(
    'appConfigProvider must be overridden in bootstrap() with AppConfig.fromEnvironment().',
  ),
);
