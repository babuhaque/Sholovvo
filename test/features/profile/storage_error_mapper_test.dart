import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/error/storage_error_mapper.dart';
import 'package:sholovvo_app/core/media/photo.dart';

void main() {
  group('mapStorageErrorToFailure: identity problems', () {
    test('401 is an auth failure, because retrying cannot help', () {
      final Failure failure = mapStorageErrorToFailure(
        message: 'Invalid authentication credentials',
        statusCode: '401',
      );

      expect(failure, isA<AuthFailure>());
      expect(failure.code, FailureCode.unauthorised);
    });

    test('a rejected JWT is recognised from the message alone', () {
      for (final String message in <String>[
        'Invalid JWT',
        'jwt expired',
      ]) {
        expect(
          mapStorageErrorToFailure(message: message),
          isA<AuthFailure>(),
          reason: message,
        );
      }
    });
  });

  group('mapStorageErrorToFailure: policy problems', () {
    test('403 is a permission failure, not a broken upload', () {
      final Failure failure = mapStorageErrorToFailure(
        message: 'new row violates row-level security policy',
        statusCode: '403',
      );

      expect(failure, isA<PermissionFailure>());
      expect(failure.code, FailureCode.permissionDenied);
      expect(failure.debugMessage, 'new row violates row-level security policy');
    });

    test('an RLS sentence without a status is still a permission failure', () {
      expect(
        mapStorageErrorToFailure(
          message: 'new row violates row-level security policy for table "objects"',
        ),
        isA<PermissionFailure>(),
      );
    });

    test('"not allowed" and "insufficient privilege" map the same way', () {
      expect(
        mapStorageErrorToFailure(message: 'not allowed'),
        isA<PermissionFailure>(),
      );
      expect(
        mapStorageErrorToFailure(message: 'insufficient privilege'),
        isA<PermissionFailure>(),
      );
    });

    test('404 is not found, 409 is a conflict', () {
      expect(
        mapStorageErrorToFailure(message: 'not found', statusCode: '404'),
        isA<NotFoundFailure>(),
      );
      expect(
        mapStorageErrorToFailure(message: 'Object not found'),
        isA<NotFoundFailure>(),
      );
      expect(
        mapStorageErrorToFailure(message: 'The resource already exists', statusCode: '409'),
        isA<ConflictFailure>(),
      );
    });
  });

  group('mapStorageErrorToFailure: the bucket\'s own limits', () {
    test('413 is the same "too large" the validator would have said', () {
      final Failure failure = mapStorageErrorToFailure(
        message: 'The object exceeded the maximum allowed size',
        statusCode: '413',
      );

      expect(failure, isA<ValidationFailure>());
      expect(PhotoValidator.issueOf(failure), PhotoIssue.tooLarge);
    });

    test('the size sentence is recognised without a status code', () {
      expect(
        PhotoValidator.issueOf(
          mapStorageErrorToFailure(
            message: 'The object exceeded the maximum allowed size',
          ),
        ),
        PhotoIssue.tooLarge,
      );
    });

    test('a refused content type is "unsupported", not "invalid input"', () {
      // Both phrasings Supabase uses for a mime rejection. Neither says "not
      // allowed", which the permission branch claims.
      for (final String message in <String>[
        'mime type text/plain is not supported',
        'The content type image/gif is not supported',
      ]) {
        final Failure failure = mapStorageErrorToFailure(message: message);

        expect(PhotoValidator.issueOf(failure), PhotoIssue.unsupportedType,
            reason: message);
      }
    });
  });

  group('mapStorageErrorToFailure: transport', () {
    test('429 is rate limiting', () {
      expect(
        mapStorageErrorToFailure(message: 'too many requests', statusCode: '429'),
        isA<RateLimitedFailure>(),
      );
    });

    test('5xx is a network failure worth retrying', () {
      final Failure failure = mapStorageErrorToFailure(
        message: 'Internal Server Error',
        statusCode: '503',
      );

      expect(failure, isA<NetworkFailure>());
      expect(failure.code, FailureCode.network);
    });

    test('socket and DNS failures are network failures too', () {
      expect(
        mapStorageErrorToFailure(message: 'SocketException: Failed host lookup'),
        isA<NetworkFailure>(),
      );
      expect(
        mapStorageErrorToFailure(message: 'Connection closed before full header'),
        isA<NetworkFailure>(),
      );
    });

    test('a timeout keeps its own code', () {
      final Failure failure = mapStorageErrorToFailure(
        message: 'Connection timed out',
      );

      expect(failure, isA<NetworkFailure>());
      expect(failure.code, FailureCode.timeout);
    });
  });

  group('mapStorageErrorToFailure: the rest', () {
    test('an unclassified error stays diagnosable', () {
      final Failure failure = mapStorageErrorToFailure(
        message: 'something new',
        statusCode: '418',
      );

      expect(failure, isA<UnexpectedFailure>());
      expect(failure.debugMessage, contains('418'));
      expect(failure.debugMessage, contains('something new'));
    });

    test('a missing status is reported as such rather than as a zero', () {
      final Failure failure = mapStorageErrorToFailure(
        message: 'ClientException: oops',
      );

      // "connection" is absent, so this one really is unclassified.
      expect(failure, isA<UnexpectedFailure>());
      expect(failure.debugMessage, startsWith('no status'));
    });

    test('keeps the cause and the stack trace it was given', () {
      final Object cause = Exception('boom');
      final StackTrace trace = StackTrace.current;
      final Failure failure = mapStorageErrorToFailure(
        message: 'Internal Server Error',
        statusCode: '500',
        cause: cause,
        stackTrace: trace,
      );

      expect(failure.cause, same(cause));
      expect(failure.stackTrace, same(trace));
    });
  });
}
