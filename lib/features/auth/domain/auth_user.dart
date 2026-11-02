/// The signed-in user, as the rest of the app sees them.
///
/// Deliberately not `firebase_auth.User`: presentation and every later feature
/// (donor profile, requests, feed) depend on this shape, so swapping or mocking
/// the identity provider never reaches beyond the data layer.
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.isEmailVerified,
    this.createdAt,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final bool isEmailVerified;
  final DateTime? createdAt;

  /// A stable, human-readable identity for greetings and avatar fallbacks.
  String get shortName {
    final String name = displayName?.trim() ?? '';
    if (name.isNotEmpty) {
      return name.split(' ').first;
    }
    final String address = email ?? '';
    if (address.contains('@')) {
      return address.split('@').first;
    }
    return 'there';
  }

  AuthUser copyWith({bool? isEmailVerified, String? displayName}) {
    return AuthUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.uid == uid &&
      other.email == email &&
      other.displayName == displayName &&
      other.isEmailVerified == isEmailVerified;

  @override
  int get hashCode => Object.hash(uid, email, displayName, isEmailVerified);

  @override
  String toString() =>
      'AuthUser(uid: $uid, email: $email, verified: $isEmailVerified)';
}
