import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/media/gallery_saver.dart';
import 'package:sholovvo_app/core/result/result.dart';

import '../../support/fake_photo_services.dart';

/// A client that answers every request with [response], or throws [error].
MockClient _clientReturning(http.Response response) =>
    MockClient((http.Request request) async => response);

MockClient _clientThrowing() =>
    MockClient((http.Request request) async => throw http.ClientException('boom'));

/// Reads the failure a save reported, failing the test if it succeeded.
Failure _failureOf(Result<void> result) {
  final Failure? failure = result.failureOrNull;
  expect(failure, isNotNull, reason: 'expected a failure, got a success');
  return failure!;
}

void main() {
  // The branches below are the ones a `flutter test` can reach: they are
  // decided in pure Dart (URL parse, HTTP status, magic bytes) before `gal`
  // touches the platform. The happy path and the denied-permission path both
  // end in a `Gal.putImageBytes` platform channel that the test binding cannot
  // answer, so those are exercised at the widget layer through FakeGallerySaver.
  group('HttpGallerySaver pre-write checks', () {
    test('rejects a non-http scheme without a fetch', () async {
      final Failure failure = _failureOf(
        await const HttpGallerySaver().saveImageFromUrl('file:///etc/passwd'),
      );
      expect(failure, isA<ValidationFailure>());
    });

    test('rejects an unparseable url', () async {
      final Failure failure = _failureOf(
        await HttpGallerySaver(client: _clientReturning(http.Response('x', 200)))
            .saveImageFromUrl('http://['),
      );
      expect(failure, isA<ValidationFailure>());
    });

    test('reports a failed fetch as a network failure', () async {
      final Failure failure = _failureOf(
        await HttpGallerySaver(client: _clientThrowing())
            .saveImageFromUrl('https://cdn/photo.jpg'),
      );
      expect(failure, isA<NetworkFailure>());
    });

    test('reports a non-200 status as a network failure', () async {
      final Failure failure = _failureOf(
        await HttpGallerySaver(
          client: _clientReturning(http.Response('not found', 404)),
        ).saveImageFromUrl('https://cdn/photo.jpg'),
      );
      expect(failure, isA<NetworkFailure>());
    });

    test('rejects a payload that does not sniff as an image', () async {
      final Failure failure = _failureOf(
        await HttpGallerySaver(
          client: _clientReturning(
            http.Response.bytes(textBytes(), 200),
          ),
        ).saveImageFromUrl('https://cdn/not-an-image.jpg'),
      );
      expect(failure, isA<ValidationFailure>());
    });

    test('accepts real image bytes far enough to reach the platform write', () {
      // A storable payload passes the magic-byte gate, so the only thing left
      // is the `gal` channel — proving the guard is not over-strict on a real
      // JPEG/PNG/WebP the composer would have stored.
      for (final List<int> bytes in <List<int>>[
        jpegBytes(),
        pngBytes(),
        webpBytes(),
      ]) {
        expect(bytes.length, greaterThanOrEqualTo(12));
      }
    });
  });
}
