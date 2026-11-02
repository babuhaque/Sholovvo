import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/logging/app_logger.dart';
import 'package:sholovvo_app/firebase_options.dart';

/// Outcome of the real Firebase initialisation attempt.
///
/// There is no "assume it worked" path: the UI renders whatever this returns,
/// so a misconfigured project is visible immediately instead of surfacing as a
/// mysterious empty list later in the app.
sealed class FirebaseBootstrapResult {
  const FirebaseBootstrapResult();
}

/// Firebase responded and the SDK holds a live app instance.
final class FirebaseReady extends FirebaseBootstrapResult {
  const FirebaseReady({required this.appName, required this.projectId});

  final String appName;
  final String projectId;
}

/// Initialisation failed; [failure] carries the classified reason.
final class FirebaseUnavailable extends FirebaseBootstrapResult {
  const FirebaseUnavailable({required this.failure});

  final Failure failure;
}

/// Initialises Firebase exactly once, tolerating hot restart.
///
/// A hot restart keeps the native Firebase app registered, so calling
/// `initializeApp` again throws `duplicate-app`. Reusing the existing instance
/// keeps development iteration fast without hiding genuine failures.
Future<FirebaseBootstrapResult> initialiseFirebase({
  AppLogger logger = AppLogger.root,
}) async {
  try {
    final FirebaseApp app;
    if (Firebase.apps.isNotEmpty) {
      app = Firebase.app();
      logger.debug('Reusing registered Firebase app "${app.name}"');
    } else {
      app = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      logger.info('Firebase initialised for "${app.options.projectId}"');
    }

    return FirebaseReady(
      appName: app.name,
      projectId: app.options.projectId,
    );
  } on FirebaseException catch (error, stackTrace) {
    logger.error(
      'Firebase initialisation failed (${error.code})',
      error: error,
      stackTrace: stackTrace,
    );
    return FirebaseUnavailable(
      failure: error.code == 'network-request-failed'
          ? NetworkFailure(
              debugMessage: error.message,
              cause: error,
              stackTrace: stackTrace,
            )
          : UnexpectedFailure(
              debugMessage: '${error.code}: ${error.message}',
              cause: error,
              stackTrace: stackTrace,
            ),
    );
  } catch (error, stackTrace) {
    logger.error(
      'Firebase initialisation threw an unclassified error',
      error: error,
      stackTrace: stackTrace,
    );
    return FirebaseUnavailable(
      failure: mapExceptionToFailure(error, stackTrace),
    );
  }
}

/// Overridden in `bootstrap()` with the resolved [FirebaseBootstrapResult].
final firebaseBootstrapProvider = Provider<FirebaseBootstrapResult>(
  (ref) => throw UnimplementedError(
    'firebaseBootstrapProvider must be overridden in bootstrap() after initialiseFirebase() completes.',
  ),
);
