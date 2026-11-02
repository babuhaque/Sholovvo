import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/auth/domain/auth_user.dart';

/// Identity operations the app needs, expressed without any SDK types.
///
/// Every method returns a [Result] instead of throwing, so a screen cannot
/// forget to handle a rejected sign-in: the type system asks for the failure
/// branch. Implementations are responsible for translating SDK exceptions into
/// [Failure]s.
abstract interface class AuthRepository {
  /// Emits the current user immediately, then on every sign-in, sign-out and
  /// profile/token refresh. Emits `null` when signed out.
  Stream<AuthUser?> authStateChanges();

  /// The user as of right now, without waiting for the stream.
  AuthUser? get currentUser;

  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  });

  /// Creates the account and sends the verification email.
  ///
  /// The returned user is signed in but unverified; the caller routes to the
  /// verification screen rather than the app proper.
  Future<Result<AuthUser>> register({
    required String email,
    required String password,
    required String displayName,
  });

  Future<Result<void>> sendEmailVerification();

  /// Re-reads the user from the server so a verification that happened in a
  /// mail client becomes visible here.
  Future<Result<void>> reloadUser();

  Future<Result<void>> sendPasswordResetEmail(String email);

  Future<Result<void>> signOut();
}
