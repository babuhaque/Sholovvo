import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/features/auth/data/auth_error_mapper.dart';
import 'package:sholovvo_app/features/auth/presentation/auth_messages.dart';

import '../../support/test_app.dart';

void main() {
  group('mapAuthErrorCode', () {
    test('treats every credential rejection as one indistinguishable reason', () {
      // If these diverged, the sign-in form would tell an attacker which
      // addresses have accounts.
      for (final String code in <String>[
        'wrong-password',
        'user-not-found',
        'invalid-credential',
        'invalid-login-credentials',
        'invalid-email',
      ]) {
        final Failure failure = mapAuthErrorCode(code);
        expect(failure, isA<AuthFailure>(), reason: code);
        expect(
          (failure as AuthFailure).reason,
          AuthFailureReason.invalidCredentials,
          reason: code,
        );
        expect(failure.code, FailureCode.unauthorised);
      }
    });

    test('maps the specific account problems to their own reasons', () {
      expect(
        (mapAuthErrorCode('user-disabled') as AuthFailure).reason,
        AuthFailureReason.userDisabled,
      );
      expect(
        (mapAuthErrorCode('email-already-in-use') as AuthFailure).reason,
        AuthFailureReason.emailAlreadyInUse,
      );
      expect(
        (mapAuthErrorCode('weak-password') as AuthFailure).reason,
        AuthFailureReason.weakPassword,
      );
      expect(
        (mapAuthErrorCode('requires-recent-login') as AuthFailure).reason,
        AuthFailureReason.requiresRecentLogin,
      );
      expect(
        (mapAuthErrorCode('operation-not-allowed') as AuthFailure).reason,
        AuthFailureReason.operationNotAllowed,
      );
    });

    test('classifies throttling and connectivity separately from credentials', () {
      expect(mapAuthErrorCode('too-many-requests'), isA<RateLimitedFailure>());
      expect(mapAuthErrorCode('network-request-failed'), isA<NetworkFailure>());
    });

    test('keeps a stale token an auth failure, not a credentials failure', () {
      for (final String code in <String>[
        'user-token-expired',
        'user-token-revoked',
      ]) {
        final Failure failure = mapAuthErrorCode(code);
        expect(failure, isA<AuthFailure>());
        expect(failure.code, FailureCode.unauthorised);
        expect(
          (failure as AuthFailure).reason,
          AuthFailureReason.unknown,
          reason: 'a stale token is not a wrong password',
        );
      }
    });

    test('does not guess at an unrecognised code', () {
      final Failure failure = mapAuthErrorCode(
        'something-new-from-firebase',
        debugMessage: 'brand new',
      );
      expect(failure, isA<UnexpectedFailure>());
      expect(failure.code, FailureCode.unknown);
      expect(failure.debugMessage, contains('something-new-from-firebase'));
    });

    test('carries the cause and stack trace through for logging', () {
      final Object cause = StateError('boom');
      final StackTrace trace = StackTrace.current;
      final Failure failure = mapAuthErrorCode(
        'wrong-password',
        cause: cause,
        stackTrace: trace,
      );
      expect(failure.cause, cause);
      expect(failure.stackTrace, trace);
    });
  });

  group('authFailureMessage', () {
    test('gives every reason a distinct, non-empty sentence', () {
      final Set<String> messages = <String>{};
      for (final AuthFailureReason reason in AuthFailureReason.values) {
        final String message = authFailureMessage(
          english,
          AuthFailure(reason: reason),
        );
        expect(message, isNotEmpty, reason: reason.name);
        messages.add(message);
      }
      expect(messages.length, AuthFailureReason.values.length);
    });

    test('never leaks a developer message to the user', () {
      final String message = authFailureMessage(
        english,
        const AuthFailure(
          reason: AuthFailureReason.invalidCredentials,
          debugMessage: 'wrong-password [auth/internal-12345]',
        ),
      );
      expect(message, isNot(contains('auth/internal')));
      expect(message, isNot(contains('wrong-password')));
    });

    test('covers the transport failures a form can actually hit', () {
      expect(
        authFailureMessage(english, const NetworkFailure()),
        contains('No connection'),
      );
      expect(
        authFailureMessage(english, const RateLimitedFailure()),
        contains('Too many attempts'),
      );
      expect(
        authFailureMessage(english, const UnexpectedFailure()),
        contains('Something went wrong'),
      );
    });

    test('every reason is also covered in Bangla, with no English left', () {
      for (final AuthFailureReason reason in AuthFailureReason.values) {
        final String message = authFailureMessage(
          bangla,
          AuthFailure(reason: reason),
        );
        expect(message, isNotEmpty, reason: reason.name);
        expect(
          message,
          isNot(authFailureMessage(english, AuthFailure(reason: reason))),
          reason: '${reason.name} still renders English',
        );
        // Latin letters are only legitimate in the one sentence that names the
        // product itself; none of the failure sentences do.
        expect(
          RegExp(r'[A-Za-z]').hasMatch(message),
          isFalse,
          reason: '${reason.name} kept Latin text: $message',
        );
      }
    });
  });
}
