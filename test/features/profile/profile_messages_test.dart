import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/media/photo.dart';
import 'package:sholovvo_app/features/profile/presentation/profile_messages.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

import '../../support/test_app.dart';

/// Every sentence a photo failure can reach, in one language.
Map<PhotoIssue, String> _sentences(AppLocalizations l10n) {
  return <PhotoIssue, String>{
    for (final PhotoIssue issue in PhotoIssue.values)
      issue: photoIssueMessage(l10n, issue)!,
  };
}

void main() {
  group('photoIssueMessage', () {
    test('has a sentence for every issue, in both languages', () {
      for (final MapEntry<PhotoIssue, String> entry
          in _sentences(english).entries) {
        expect(entry.value.trim(), isNotEmpty, reason: entry.key.name);
      }
      for (final MapEntry<PhotoIssue, String> entry
          in _sentences(bangla).entries) {
        expect(entry.value.trim(), isNotEmpty, reason: entry.key.name);
      }
    });

    test('is actually translated, not the English sentence twice', () {
      final Map<PhotoIssue, String> en = _sentences(english);
      final Map<PhotoIssue, String> bn = _sentences(bangla);

      for (final PhotoIssue issue in PhotoIssue.values) {
        expect(bn[issue], isNot(en[issue]), reason: issue.name);
      }
    });

    test('the five issues read as five different sentences', () {
      final Set<String> unique = _sentences(english).values.toSet();

      expect(unique, hasLength(PhotoIssue.values.length));
    });

    test('quotes the size limit from the validator', () {
      expect(
        photoIssueMessage(english, PhotoIssue.tooLarge),
        english.errorPhotoTooLarge(PhotoValidator.maxMegabytes),
      );
      // The Bangla sentence carries the limit too, in its own digits: the
      // generated formatter localises the number, so it is a Bengali numeral
      // there rather than an ASCII one.
      expect(
        photoIssueMessage(bangla, PhotoIssue.tooLarge),
        bangla.errorPhotoTooLarge(PhotoValidator.maxMegabytes),
      );
      expect(
        photoIssueMessage(bangla, PhotoIssue.tooLarge),
        contains(RegExp(r'[০-৯]')),
      );
    });

    test('no issue yields no message, so a caller can fall back', () {
      expect(photoIssueMessage(english, null), isNull);
    });
  });

  group('profileFailureMessage with a photo failure', () {
    test('a validator refusal names the rule it broke', () {
      const Failure failure = ValidationFailure(
        messageKey: 'tooLarge',
        debugMessage: 'too large',
      );

      expect(
        profileFailureMessage(english, failure),
        english.errorPhotoTooLarge(PhotoValidator.maxMegabytes),
      );
    });

    test('a validation failure about something else keeps the generic '
        'sentence', () {
      const Failure failure = ValidationFailure(
        messageKey: 'nameTooShort',
        debugMessage: 'too short',
      );

      expect(profileFailureMessage(english, failure), english.failureValidation);
    });

    test('an unconfigured build says so instead of "something went wrong"', () {
      const Failure failure = ConfigurationFailure(setting: 'SUPABASE_URL');

      expect(
        profileFailureMessage(english, failure),
        english.profilePhotoNotConfigured,
      );
      expect(profileFailureMessage(bangla, failure), bangla.profilePhotoNotConfigured);
    });

    test('a refused upload is still a permission sentence, not a photo one', () {
      const Failure failure = PermissionFailure(debugMessage: 'denied');

      expect(profileFailureMessage(english, failure), english.failurePermission);
    });
  });
}
