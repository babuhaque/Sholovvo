import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';

void main() {
  group('Result', () {
    test('exposes the value on success and no failure', () {
      const Result<int> result = Success<int>(7);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull, 7);
      expect(result.failureOrNull, isNull);
    });

    test('exposes the failure on failure and no value', () {
      const Result<int> result = FailureResult<int>(
        NetworkFailure(debugMessage: 'offline'),
      );

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, isA<NetworkFailure>());
    });

    test('fold selects exactly one branch', () {
      const Result<int> success = Success<int>(2);
      const Result<int> failure = FailureResult<int>(
        NotFoundFailure(debugMessage: 'missing'),
      );

      expect(
        success.fold(onSuccess: (value) => value * 10, onFailure: (_) => -1),
        20,
      );
      expect(
        failure.fold(onSuccess: (value) => value * 10, onFailure: (_) => -1),
        -1,
      );
    });

    test('map transforms success and preserves failure identity', () {
      const Result<int> success = Success<int>(3);
      const Failure failure = ConflictFailure(debugMessage: 'claimed');
      const Result<int> failureResult = FailureResult<int>(failure);

      final Result<String> mappedSuccess = success.map((value) => 'v$value');
      final Result<String> mappedFailure = failureResult.map(
        (value) => 'v$value',
      );

      expect(mappedSuccess.valueOrNull, 'v3');
      expect(mappedFailure.failureOrNull, same(failure));
    });

    group('guard', () {
      test('wraps a successful async call', () async {
        final Result<int> result = await Result.guard(() async => 42);

        expect(result.valueOrNull, 42);
      });

      test('converts a thrown TimeoutException into a timeout failure', () async {
        final Result<int> result = await Result.guard<int>(() async {
          throw TimeoutException('slow');
        });

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull?.code, FailureCode.timeout);
      });

      test('converts any thrown object into a failure instead of rethrowing',
          () async {
        final Result<int> result = await Result.guard<int>(() async {
          throw const FormatException('bad payload');
        });

        expect(result.isFailure, isTrue);
        expect(result.failureOrNull?.code, FailureCode.unknown);
        expect(result.failureOrNull?.cause, isA<FormatException>());
      });

      test('keeps an existing Failure unchanged', () async {
        final Result<int> result = await Result.guard<int>(() async {
          throw const PermissionFailure(debugMessage: 'rules rejected');
        });

        expect(result.failureOrNull, isA<PermissionFailure>());
      });
    });
  });
}
