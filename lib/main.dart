import 'package:sholovvo_app/app/bootstrap.dart';

/// Application entry point.
///
/// Kept intentionally trivial: all startup sequencing lives in `bootstrap()` so
/// it stays unit-testable and identical across platforms.
Future<void> main() => bootstrap();
