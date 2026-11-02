import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/profile/domain/profile_photo.dart';

import '../../support/fake_photo_services.dart';

/// The issue a rejected candidate carries, or `null` when it was accepted.
PhotoIssue? _issueOf(Uint8List bytes) {
  final Result<ValidatedPhoto> result = PhotoValidator.validate(
    PhotoCandidate(bytes: bytes),
  );
  final Failure? failure = result.failureOrNull;
  return failure == null ? null : PhotoValidator.issueOf(failure);
}

void main() {
  group('PhotoValidator.sniff', () {
    test('recognises the three accepted formats by their first bytes', () {
      expect(PhotoValidator.sniff(jpegBytes()), PhotoFormat.jpeg);
      expect(PhotoValidator.sniff(pngBytes()), PhotoFormat.png);
      expect(PhotoValidator.sniff(webpBytes()), PhotoFormat.webp);
    });

    test('reads content, not the file name', () {
      // A `.jpg` name is not consulted anywhere in the validator, so a text file
      // is refused no matter what the picker called it.
      expect(PhotoValidator.sniff(textBytes()), isNull);
    });

    test('a different RIFF payload is not a WebP', () {
      // WAV: "RIFF" + length + "WAVE".
      final Uint8List wav = Uint8List.fromList(<int>[
        0x52, 0x49, 0x46, 0x46, // RIFF
        0x24, 0x00, 0x00, 0x00, // size
        0x57, 0x41, 0x56, 0x45, // WAVE
      ]);

      expect(PhotoValidator.sniff(wav), isNull);
    });

    test('a truncated RIFF header is not a WebP either', () {
      final Uint8List short = Uint8List.fromList(<int>[0x52, 0x49, 0x46, 0x46]);

      expect(PhotoValidator.sniff(short), isNull);
    });

    test('an empty file has no format', () {
      expect(PhotoValidator.sniff(Uint8List(0)), isNull);
    });
  });

  group('PhotoValidator.validate', () {
    test('accepts a JPEG and keeps the bytes it was given', () {
      final Result<ValidatedPhoto> result = PhotoValidator.validate(
        PhotoCandidate(bytes: jpegBytes(length: 128), fileName: 'me.jpg'),
      );
      final ValidatedPhoto photo = result.valueOrNull!;

      expect(result.isSuccess, isTrue);
      expect(photo.format, PhotoFormat.jpeg);
      expect(photo.mimeType, 'image/jpeg');
      // The stored extension comes from the sniffed format, never the name.
      expect(photo.extension, 'jpg');
      expect(photo.byteLength, 128);
    });

    test('reports the extension and content type each format actually needs', () {
      final Map<PhotoFormat, List<String>> expected = <PhotoFormat, List<String>>{
        PhotoFormat.jpeg: <String>['image/jpeg', 'jpg'],
        PhotoFormat.png: <String>['image/png', 'png'],
        PhotoFormat.webp: <String>['image/webp', 'webp'],
      };

      expected.forEach((PhotoFormat format, List<String> pair) {
        expect(format.mimeType, pair[0]);
        expect(format.extension, pair[1]);
      });
    });

    test('an empty pick is refused before anything else is checked', () {
      expect(_issueOf(Uint8List(0)), PhotoIssue.empty);
    });

    test('a file over the limit is refused, and the limit itself is allowed', () {
      expect(_issueOf(jpegBytes(length: PhotoValidator.maxBytes)), isNull);
      expect(
        _issueOf(jpegBytes(length: PhotoValidator.maxBytes + 1)),
        PhotoIssue.tooLarge,
      );
    });

    test('a file that is not one of the three formats is refused', () {
      expect(_issueOf(textBytes()), PhotoIssue.unsupportedType);
    });

    test('every refusal is a validation failure carrying its own key', () {
      final Result<ValidatedPhoto> result = PhotoValidator.validate(
        PhotoCandidate(bytes: textBytes()),
      );
      final Failure failure = result.failureOrNull!;

      expect(failure, isA<ValidationFailure>());
      expect(failure.code, FailureCode.validation);
      expect(failure.debugMessage, contains('unsupportedType'));
    });

    test('the size limit is quoted from one place', () {
      expect(PhotoValidator.maxBytes, 5 * 1024 * 1024);
      expect(PhotoValidator.maxMegabytes, 5);
    });
  });

  group('PhotoValidator.issueOf', () {
    test('round-trips every issue the validator can produce', () {
      final Map<PhotoIssue, Uint8List> samples = <PhotoIssue, Uint8List>{
        PhotoIssue.empty: Uint8List(0),
        PhotoIssue.tooLarge: jpegBytes(length: PhotoValidator.maxBytes + 1),
        PhotoIssue.unsupportedType: textBytes(),
      };

      samples.forEach((PhotoIssue issue, Uint8List bytes) {
        expect(_issueOf(bytes), issue);
      });
    });

    test('a validation failure about something else yields no photo issue', () {
      const Failure nameFailure = ValidationFailure(
        messageKey: 'nameTooShort',
        debugMessage: 'too short',
      );

      expect(PhotoValidator.issueOf(nameFailure), isNull);
    });

    test('a failure of another kind yields no photo issue', () {
      const Failure offline = NetworkFailure(debugMessage: 'offline');

      expect(PhotoValidator.issueOf(offline), isNull);
    });
  });

  group('ValidatedPhoto', () {
    test('describes itself without dumping the image bytes', () {
      final ValidatedPhoto photo = PhotoValidator.validate(
        PhotoCandidate(bytes: pngBytes(length: 32)),
      ).valueOrNull!;

      expect(photo.toString(), contains('png'));
      expect(photo.toString(), contains('32 bytes'));
    });
  });
}
