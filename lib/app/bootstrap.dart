import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/app/app.dart';
import 'package:sholovvo_app/core/config/app_config.dart';
import 'package:sholovvo_app/core/config/supabase_config.dart';
import 'package:sholovvo_app/core/firebase/firebase_bootstrap.dart';
import 'package:sholovvo_app/core/preferences/app_preferences.dart';

/// Single entry point for startup side effects.
///
/// Ordering matters: bindings must exist before any plugin call, and Firebase
/// must be initialised before any provider that touches Auth or Firestore is
/// first read. Stage 1 moves the Firebase wait behind the animated splash so
/// the first frame is never blocked.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppConfig config = AppConfig.fromEnvironment();
  // Resolved here rather than read from a provider so the compile-time defines
  // are consulted exactly once, and so a build with no Supabase project simply
  // reports "not configured" instead of failing at the first upload.
  final SupabaseConfig supabaseConfig = SupabaseConfig.fromEnvironment();

  // Loaded before `runApp` so the MaterialApp is built with the saved theme
  // and language already in hand. Resolving them later would paint one frame
  // in the wrong theme and re-theme in front of the user.
  final PreferencesStore preferences = await PreferencesStore.load();
  final FirebaseBootstrapResult firebaseResult = await initialiseFirebase();

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        supabaseConfigProvider.overrideWithValue(supabaseConfig),
        preferencesStoreProvider.overrideWithValue(preferences),
        firebaseBootstrapProvider.overrideWithValue(firebaseResult),
      ],
      child: const SolovvoApp(),
    ),
  );
}
