import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';

void main() {
  group('mapExceptionToFailure', () {
    test('passes an existing Failure through untouched', () {
      const Failure original = RateLimitedFailure(debugMessage: 'too many');

      expect(mapExceptionToFailure(original), same(original));
    });

    test('classifies TimeoutException as a timeout network failure', () {
      final Failure failure = mapExceptionToFailure(TimeoutException('deadline'));

      expect(failure, isA<NetworkFailure>());
      expect(failure.code, FailureCode.timeout);
      expect(failure.debugMessage, 'deadline');
    });

    test('classifies an unclassified object as unexpected', () {
      final Failure failure = mapExceptionToFailure(StateError('boom'));

      expect(failure, isA<UnexpectedFailure>());
      expect(failure.code, FailureCode.unknown);
      expect(failure.cause, isA<StateError>());
    });

    test('retains the supplied stack trace', () {
      final StackTrace trace = StackTrace.current;

      expect(mapExceptionToFailure(StateError('boom'), trace).stackTrace, trace);
    });
  });

  group('ValidationFailure', () {
    test('carries the localisation key and field so no prose is hardcoded', () {
      const ValidationFailure failure = ValidationFailure(
        messageKey: 'error_password_too_short',
        field: 'password',
      );

      expect(failure.code, FailureCode.validation);
      expect(failure.messageKey, 'error_password_too_short');
      expect(failure.field, 'password');
    });
  });
}
