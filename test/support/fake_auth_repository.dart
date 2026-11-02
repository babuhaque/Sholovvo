import 'dart:async';

import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/auth/domain/auth_repository.dart';
import 'package:sholovvo_app/features/auth/domain/auth_user.dart';

/// In-memory [AuthRepository] for widget tests.
///
/// Each method returns whatever the test configured through the `*Failure`
/// fields and records how many times it was called, and the session stream is
/// driven by hand with [emit]. That is enough to pin down what every screen does
/// with a rejection or a session change, without a Firebase project, a network
/// or a device.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? initialUser}) : _current = initialUser;

  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();

  AuthUser? _current;

  /// When set, the matching call returns this failure instead of succeeding.
  Failure? signInFailure;
  Failure? registerFailure;
  Failure? resetFailure;
  Failure? verifyFailure;
  Failure? reloadFailure;
  Failure? signOutFailure;

  /// What [reloadUser] does to the cached profile. Set to true to emulate a
  /// user who confirmed the address in their mail client.
  bool verifyOnReload = false;

  int signInCalls = 0;
  int registerCalls = 0;
  int resetCalls = 0;
  int verifyCalls = 0;
  int reloadCalls = 0;
  int signOutCalls = 0;

  String? lastEmail;
  String? lastDisplayName;

  /// Pushes a new session state to listeners, as the SDK would.
  void emit(AuthUser? user) {
    _current = user;
    _controller.add(user);
  }

  Future<void> dispose() => _controller.close();

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  AuthUser? get currentUser => _current;

  @override
  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    lastEmail = email;
    if (signInFailure != null) {
      return FailureResult<AuthUser>(signInFailure!);
    }
    final AuthUser user = AuthUser(
      uid: 'uid-signed-in',
      email: email,
      displayName: 'Test Donor',
      isEmailVerified: true,
      createdAt: DateTime(2026, 11, 2),
    );
    emit(user);
    return Success<AuthUser>(user);
  }

  @override
  Future<Result<AuthUser>> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    registerCalls++;
    lastEmail = email;
    lastDisplayName = displayName;
    if (registerFailure != null) {
      return FailureResult<AuthUser>(registerFailure!);
    }
    final AuthUser user = AuthUser(
      uid: 'uid-registered',
      email: email,
      displayName: displayName,
      isEmailVerified: false,
      createdAt: DateTime(2026, 11, 2),
    );
    emit(user);
    return Success<AuthUser>(user);
  }

  @override
  Future<Result<void>> sendEmailVerification() async {
    verifyCalls++;
    if (verifyFailure != null) {
      return FailureResult<void>(verifyFailure!);
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> reloadUser() async {
    reloadCalls++;
    if (reloadFailure != null) {
      return FailureResult<void>(reloadFailure!);
    }
    if (verifyOnReload && _current != null) {
      _current = _current!.copyWith(isEmailVerified: true);
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> sendPasswordResetEmail(String email) async {
    resetCalls++;
    lastEmail = email;
    if (resetFailure != null) {
      return FailureResult<void>(resetFailure!);
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> signOut() async {
    signOutCalls++;
    if (signOutFailure != null) {
      return FailureResult<void>(signOutFailure!);
    }
    emit(null);
    return const Success<void>(null);
  }
}

/// A session that never resolves, for pinning down the loading state.
class SilentAuthRepository extends FakeAuthRepository {
  @override
  Stream<AuthUser?> authStateChanges() => Stream<AuthUser?>.multi((_) {});
}

/// A session stream that fails outright, e.g. a revoked refresh token.
class BrokenAuthRepository extends FakeAuthRepository {
  @override
  Stream<AuthUser?> authStateChanges() => Stream<AuthUser?>.error(
    const NetworkFailure(debugMessage: 'offline'),
  );
}

/// A verified donor.
const AuthUser verifiedUser = AuthUser(
  uid: 'uid-verified',
  email: 'ayesha@solovvo.app',
  displayName: 'Ayesha Rahman',
  isEmailVerified: true,
  createdAt: null,
);

/// A registered donor who has not opened the verification email.
const AuthUser unverifiedUser = AuthUser(
  uid: 'uid-unverified',
  email: 'rafiq@solovvo.app',
  displayName: 'Rafiq Hasan',
  isEmailVerified: false,
);
