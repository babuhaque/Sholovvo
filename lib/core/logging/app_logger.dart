import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Thin, dependency-free logging facade.
///
/// Verbose levels are stripped in release builds so no debug detail leaks into
/// production logs or crash reports. Use this instead of `print`, which the
/// lint configuration forbids.
final class AppLogger {
  const AppLogger(this.name);

  /// Shared logger for app-level events.
  static const AppLogger root = AppLogger('solovvo');

  /// Channel name, matching the subsystem that emits the event.
  final String name;

  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    if (kReleaseMode) {
      return;
    }
    developer.log(
      message,
      name: name,
      level: 500,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void info(String message, {Object? error, StackTrace? stackTrace}) {
    if (kReleaseMode) {
      return;
    }
    developer.log(
      message,
      name: name,
      level: 800,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: name,
      level: 900,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Errors survive in release builds: a silent production failure is worse
  /// than a noisy log.
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
