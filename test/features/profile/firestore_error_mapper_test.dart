import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/error/firestore_error_mapper.dart';

/// The mapper moved to `core/error` in Stage 8.2, when the feed became its
/// second caller. The assertions are unchanged; only the import path is.
void main() {
  group('mapFirestoreCodeToFailure', () {
    test('a refused write is a permission failure, not a generic error', () {
      final Failure failure = mapFirestoreCodeToFailure('permission-denied');

      expect(failure, isA<PermissionFailure>());
      expect(failure.code, FailureCode.permissionDenied);
      // The default debug message is the code itself, which is what makes a log
      // line diagnosable without reproducing the request.
      expect(failure.debugMessage, 'permission-denied');
    });

    test('a missing session is an auth failure', () {
      final Failure failure = mapFirestoreCodeToFailure('unauthenticated');

      expect(failure, isA<AuthFailure>());
      expect(failure.code, FailureCode.unauthorised);
    });

    test('transport failures keep their distinction', () {
      final Failure offline = mapFirestoreCodeToFailure('unavailable');
      final Failure late = mapFirestoreCodeToFailure('deadline-exceeded');

      expect(offline, isA<NetworkFailure>());
      expect(offline.code, FailureCode.network);
      expect(late, isA<NetworkFailure>());
      expect(late.code, FailureCode.timeout);
    });

    test('quota, missing document and contention are classified', () {
      expect(
        mapFirestoreCodeToFailure('resource-exhausted'),
        isA<RateLimitedFailure>(),
      );
      expect(mapFirestoreCodeToFailure('not-found'), isA<NotFoundFailure>());
      expect(mapFirestoreCodeToFailure('aborted'), isA<ConflictFailure>());
      expect(
        mapFirestoreCodeToFailure('already-exists'),
        isA<ConflictFailure>(),
      );
    });

    test('a payload the rules reject is a validation failure', () {
      for (final String code in <String>[
        'invalid-argument',
        'failed-precondition',
      ]) {
        final Failure failure = mapFirestoreCodeToFailure(code);

        expect(failure, isA<ValidationFailure>(), reason: code);
        expect(failure.code, FailureCode.validation);
        expect((failure as ValidationFailure).messageKey, 'failureValidation');
      }
    });

    test('a cancelled call is unexpected, with its own code', () {
      final Failure failure = mapFirestoreCodeToFailure('cancelled');

      expect(failure, isA<UnexpectedFailure>());
      expect(failure.code, FailureCode.cancelled);
    });

    test('an unknown code stays diagnosable', () {
      final Failure failure = mapFirestoreCodeToFailure('internal');

      expect(failure, isA<UnexpectedFailure>());
      expect(failure.code, FailureCode.unknown);
      expect(failure.debugMessage, contains('internal'));
    });

    test('keeps the detail, the cause and the stack trace it was given', () {
      final Object cause = Exception('boom');
      final StackTrace trace = StackTrace.current;
      final Failure failure = mapFirestoreCodeToFailure(
        'unavailable',
        debugMessage: 'backend unreachable',
        cause: cause,
        stackTrace: trace,
      );

      expect(failure.debugMessage, 'backend unreachable');
      expect(failure.cause, same(cause));
      expect(failure.stackTrace, same(trace));
    });

    test('an unknown code appends the detail instead of dropping it', () {
      final Failure failure = mapFirestoreCodeToFailure(
        'internal',
        debugMessage: 'assertion failed',
      );

      expect(failure.debugMessage, 'internal: assertion failed');
    });
  });
}
