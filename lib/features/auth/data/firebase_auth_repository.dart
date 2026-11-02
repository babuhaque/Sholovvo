import 'package:firebase_auth/firebase_auth.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/logging/app_logger.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/auth/data/auth_error_mapper.dart';
import 'package:sholovvo_app/features/auth/domain/auth_repository.dart';
import 'package:sholovvo_app/features/auth/domain/auth_user.dart';

/// [AuthRepository] backed by Firebase Authentication.
///
/// Every SDK call is wrapped so that a rejection leaves this file as a [Failure]
/// and never as a raw `FirebaseAuthException`. The translation table lives in
/// `auth_error_mapper.dart`; this class only supplies the code.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  static const AppLogger _log = AppLogger('auth');

  final FirebaseAuth _auth;

  /// `userChanges` rather than `authStateChanges`: it also fires when the user
  /// profile changes, which is how a "verified in your mail client" tap reaches
  /// the UI without an app restart.
  @override
  Stream<AuthUser?> authStateChanges() {
    return _auth.userChanges().map(_toDomain);
  }

  @override
  AuthUser? get currentUser => _toDomain(_auth.currentUser);

  @override
  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  }) {
    return _run(
      () async {
        final UserCredential credential = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        return _toDomain(_requireUser(credential.user))!;
      },
      action: 'sign-in',
    );
  }

  @override
  Future<Result<AuthUser>> register({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _run(
      () async {
        final UserCredential credential = await _auth
            .createUserWithEmailAndPassword(
              email: email.trim(),
              password: password,
            );
        final User user = _requireUser(credential.user);

        // The display name is written before the verification mail is sent so a
        // later profile screen never shows a nameless account.
        await user.updateDisplayName(displayName.trim());
        await user.sendEmailVerification();
        await user.reload();

        return _toDomain(_auth.currentUser) ?? _toDomain(user)!;
      },
      action: 'register',
    );
  }

  @override
  Future<Result<void>> sendEmailVerification() {
    return _run(
      () async {
        final User? user = _auth.currentUser;
        if (user == null) {
          throw const AuthFailure(
            reason: AuthFailureReason.emailNotVerified,
            debugMessage: 'No signed-in user to verify',
          );
        }
        await user.sendEmailVerification();
      },
      action: 'send-verification',
    );
  }

  @override
  Future<Result<void>> reloadUser() {
    return _run(
      () async {
        final User? user = _auth.currentUser;
        if (user == null) {
          throw const AuthFailure(debugMessage: 'No signed-in user to reload');
        }
        await user.reload();
      },
      action: 'reload-user',
    );
  }

  /// Deliberately reports success even when the address is unknown: Firebase
  /// itself does not disclose that, and neither should the UI. An unknown
  /// address is therefore swallowed here rather than turned into an
  /// `invalidCredentials` failure, which would make this form an oracle for
  /// which addresses have accounts.
  @override
  Future<Result<void>> sendPasswordResetEmail(String email) {
    return _run(
      () async {
        try {
          await _auth.sendPasswordResetEmail(email: email.trim());
        } on FirebaseAuthException catch (error) {
          if (error.code != 'user-not-found') {
            rethrow;
          }
          _log.debug('Password reset requested for an unknown address');
        }
      },
      action: 'password-reset',
    );
  }

  @override
  Future<Result<void>> signOut() {
    return _run(_auth.signOut, action: 'sign-out');
  }

  AuthUser? _toDomain(User? user) {
    if (user == null) {
      return null;
    }
    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      isEmailVerified: user.emailVerified,
      createdAt: user.metadata.creationTime,
    );
  }

  User _requireUser(User? user) {
    if (user == null) {
      throw const AuthFailure(debugMessage: 'SDK returned no user');
    }
    return user;
  }

  /// Runs [operation], translating SDK exceptions into classified failures.
  Future<Result<T>> _run<T>(
    Future<T> Function() operation, {
    required String action,
  }) async {
    try {
      return Success<T>(await operation());
    } on FirebaseAuthException catch (error, stackTrace) {
      _log.warning(
        'Auth $action failed: ${error.code}',
        error: error,
        stackTrace: stackTrace,
      );
      return FailureResult<T>(
        mapAuthErrorCode(
          error.code,
          debugMessage: error.message,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } catch (error, stackTrace) {
      _log.error('Auth $action crashed', error: error, stackTrace: stackTrace);
      return FailureResult<T>(mapExceptionToFailure(error, stackTrace));
    }
  }
}
