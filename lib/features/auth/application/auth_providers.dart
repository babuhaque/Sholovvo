import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/features/auth/data/firebase_auth_repository.dart';
import 'package:sholovvo_app/features/auth/domain/auth_repository.dart';
import 'package:sholovvo_app/features/auth/domain/auth_user.dart';

/// The identity backend.
///
/// The single seam for tests: screens and the auth gate depend on the
/// [AuthRepository] interface, so no widget test needs a live Firebase project.
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) {
      return FirebaseAuthRepository(FirebaseAuth.instance);
    });

/// The signed-in user, or `null` when signed out.
///
/// A stream rather than a one-shot read on purpose. Three things arrive here
/// without any screen navigating by hand: a session restored from disk at
/// startup, a verification that happened in a mail client, and a sign-out.
final StreamProvider<AuthUser?> authStateProvider =
    StreamProvider<AuthUser?>((Ref ref) {
      return ref.watch(authRepositoryProvider).authStateChanges();
    });
