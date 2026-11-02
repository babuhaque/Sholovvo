import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/features/auth/domain/auth_validators.dart';

void main() {
  group('AuthValidators.email', () {
    test('accepts ordinary and plus-tagged addresses', () {
      for (final String address in <String>[
        'donor@solovvo.app',
        'rafiq.hasan+donor@gmail.com',
        'a@b.co',
        'first_last@sub.domain.org',
      ]) {
        expect(AuthValidators.email(address), isNull, reason: address);
      }
    });

    test('trims surrounding whitespace before judging', () {
      expect(AuthValidators.email('  donor@solovvo.app  '), isNull);
    });

    test('rejects an empty or malformed address', () {
      expect(AuthValidators.email(null), AuthFieldIssue.emailRequired);
      expect(AuthValidators.email('   '), AuthFieldIssue.emailRequired);
      expect(AuthValidators.email('donor@'), AuthFieldIssue.emailInvalid);
      expect(AuthValidators.email('donor'), AuthFieldIssue.emailInvalid);
      expect(AuthValidators.email('donor@solovvo'), AuthFieldIssue.emailInvalid);
      expect(
        AuthValidators.email('donor@@solovvo.app'),
        AuthFieldIssue.emailInvalid,
      );
    });

    test('rejects an address over the 254 character limit', () {
      final String long = '${'a' * 250}@solovvo.app';
      expect(AuthValidators.email(long), AuthFieldIssue.emailTooLong);
    });
  });

  group('AuthValidators.signInPassword', () {
    test('only requires a non-empty value', () {
      // Existing accounts may predate any composition rule, so sign-in must not
      // re-impose one.
      expect(AuthValidators.signInPassword('x'), isNull);
      expect(AuthValidators.signInPassword(null), AuthFieldIssue.passwordRequired);
      expect(AuthValidators.signInPassword(''), AuthFieldIssue.passwordRequired);
    });
  });

  group('AuthValidators.newPassword', () {
    test('requires eight characters mixing letters and numbers', () {
      expect(AuthValidators.newPassword(''), AuthFieldIssue.passwordChoose);
      expect(
        AuthValidators.newPassword('short1'),
        AuthFieldIssue.passwordTooShort,
      );
      expect(
        AuthValidators.newPassword('onlyletters'),
        AuthFieldIssue.passwordComposition,
      );
      expect(
        AuthValidators.newPassword('12345678'),
        AuthFieldIssue.passwordComposition,
      );
      expect(AuthValidators.newPassword('strong-pass1'), isNull);
    });
  });

  group('AuthValidators.confirmPassword', () {
    test('must match the chosen password', () {
      expect(
        AuthValidators.confirmPassword('', 'secret123'),
        AuthFieldIssue.confirmRequired,
      );
      expect(
        AuthValidators.confirmPassword('secret124', 'secret123'),
        AuthFieldIssue.confirmMismatch,
      );
      expect(AuthValidators.confirmPassword('secret123', 'secret123'), isNull);
    });
  });

  group('AuthValidators.displayName', () {
    test('bounds the length', () {
      expect(AuthValidators.displayName(''), AuthFieldIssue.nameRequired);
      expect(AuthValidators.displayName('A'), AuthFieldIssue.nameTooShort);
      expect(AuthValidators.displayName('Rafiq Hasan'), isNull);
      expect(AuthValidators.displayName('R' * 41), AuthFieldIssue.nameTooLong);
    });
  });
}
