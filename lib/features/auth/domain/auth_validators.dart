/// Which rule a field broke.
///
/// The domain answers *what is wrong*, never *what to write*. Returning prose
/// from here would hard-code one language into the layer that knows nothing
/// about the user, and every extra rule would mean editing every catalogue.
/// Presentation turns the issue into a sentence in the active language.
enum AuthFieldIssue {
  emailRequired,
  emailTooLong,
  emailInvalid,
  passwordRequired,
  passwordChoose,
  passwordTooShort,
  passwordComposition,
  confirmRequired,
  confirmMismatch,
  nameRequired,
  nameTooShort,
  nameTooLong,
}

/// Field rules shared by every auth form.
///
/// Pure functions returning `null` when valid and the broken rule when not.
/// They live in the domain layer so the same rule backs registration, sign-in
/// and password reset, and so they can be unit-tested without a widget tree.
abstract final class AuthValidators {
  /// Deliberately permissive: the only authority on whether an address exists is
  /// the verification email. Over-strict client rules reject valid addresses
  /// (plus-tags, new TLDs) without protecting anything.
  static final RegExp _emailPattern = RegExp(
    r'^[\w.!#$%&*+/=?^`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?'
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$',
  );

  static const int minPasswordLength = 8;
  static const int maxDisplayNameLength = 40;
  static const int minDisplayNameLength = 2;

  /// RFC 5321 caps a forward path at 254 octets; anything longer cannot be
  /// delivered, so it is rejected before a round trip.
  static const int maxEmailLength = 254;

  static AuthFieldIssue? email(String? value) {
    final String address = value?.trim() ?? '';
    if (address.isEmpty) {
      return AuthFieldIssue.emailRequired;
    }
    if (address.length > maxEmailLength) {
      return AuthFieldIssue.emailTooLong;
    }
    if (!_emailPattern.hasMatch(address)) {
      return AuthFieldIssue.emailInvalid;
    }
    return null;
  }

  /// Sign-in must not enforce composition rules: existing accounts may predate
  /// them, and telling an attacker what a valid password looks like helps them.
  static AuthFieldIssue? signInPassword(String? value) {
    if ((value ?? '').isEmpty) {
      return AuthFieldIssue.passwordRequired;
    }
    return null;
  }

  /// Registration is where composition is enforced, because it is where the
  /// password is chosen.
  static AuthFieldIssue? newPassword(String? value) {
    final String password = value ?? '';
    if (password.isEmpty) {
      return AuthFieldIssue.passwordChoose;
    }
    if (password.length < minPasswordLength) {
      return AuthFieldIssue.passwordTooShort;
    }
    if (!password.contains(RegExp(r'[A-Za-z]')) ||
        !password.contains(RegExp(r'[0-9]'))) {
      return AuthFieldIssue.passwordComposition;
    }
    return null;
  }

  static AuthFieldIssue? confirmPassword(String? value, String password) {
    if ((value ?? '').isEmpty) {
      return AuthFieldIssue.confirmRequired;
    }
    if (value != password) {
      return AuthFieldIssue.confirmMismatch;
    }
    return null;
  }

  static AuthFieldIssue? displayName(String? value) {
    final String name = value?.trim() ?? '';
    if (name.isEmpty) {
      return AuthFieldIssue.nameRequired;
    }
    if (name.length < minDisplayNameLength) {
      return AuthFieldIssue.nameTooShort;
    }
    if (name.length > maxDisplayNameLength) {
      return AuthFieldIssue.nameTooLong;
    }
    return null;
  }
}
