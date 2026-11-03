import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/config/supabase_config.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/media/image_picker_photo_picker.dart';
import 'package:sholovvo_app/core/media/photo.dart';
import 'package:sholovvo_app/core/media/photo_picker.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/profile/application/profile_providers.dart';
import 'package:sholovvo_app/features/profile/data/supabase_photo_storage.dart';
import 'package:sholovvo_app/features/profile/domain/profile_photo_storage.dart';

/// The photo backend.
///
/// Lazily constructed, like [profileRepositoryProvider], so a test that never
/// touches a photo never reads [supabaseConfigProvider] either. Every widget
/// test of the photo flow overrides this one provider and needs no Supabase
/// project, no bucket and no network.
final Provider<ProfilePhotoStorage> profilePhotoStorageProvider =
    Provider<ProfilePhotoStorage>((Ref ref) {
      return SupabasePhotoStorage(
        FirebaseAuth.instance,
        ref.watch(supabaseConfigProvider),
      );
    });

/// The platform image picker.
///
/// Overridden in tests: `image_picker` answers on a platform channel that the
/// test binding does not implement.
final Provider<PhotoPicker> photoPickerProvider = Provider<PhotoPicker>(
  (Ref ref) => ImagePickerPhotoPicker(),
);

/// Drives one photo operation at a time, from picker to published URL.
///
/// The ordering here is the whole design, so it is stated once, in one place:
///
/// * **Replacing:** upload to storage, then write the URL to the profile. If the
///   profile write fails, the object that was just uploaded is deleted again. The
///   donor's existing photo is never touched, so a failed replacement leaves the
///   profile exactly as it was.
/// * **Removing:** write the removal to the profile first, then delete the
///   object. The opposite order would leave the donor card pointing at a file
///   that no longer exists if the write failed; this order's worst case is an
///   orphaned object nobody links to.
class ProfilePhotoController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  bool _busy = false;

  /// Picks an image, checks it, uploads it and publishes the new URL.
  ///
  /// Returns `true` when a photo replaced the previous one, `false` when the
  /// donor closed the picker without choosing anything — a cancel is not a
  /// failure and must not be reported as one.
  Future<Result<bool>> chooseAndUpload(PhotoSource source) {
    return _run<bool>(() async {
      final Result<PhotoCandidate?> picked = await ref
          .read(photoPickerProvider)
          .pick(source);
      final Failure? pickFailure = picked.failureOrNull;
      if (pickFailure != null) {
        return FailureResult<bool>(pickFailure);
      }
      final PhotoCandidate? candidate = picked.valueOrNull;
      if (candidate == null) {
        return const Success<bool>(false);
      }

      final Result<ValidatedPhoto> checked = PhotoValidator.validate(candidate);
      final Failure? validationFailure = checked.failureOrNull;
      if (validationFailure != null) {
        return FailureResult<bool>(validationFailure);
      }
      return _upload(checked.valueOrNull!);
    });
  }

  /// Removes the photo at [currentUrl] from the profile, then from storage.
  ///
  /// [currentUrl] comes from the profile the screen is showing rather than being
  /// re-read here: the screen already has it, and a second read could see a
  /// different value than the one the donor is looking at.
  Future<Result<void>> remove(String? currentUrl) {
    return _run<void>(() async {
      final String url = currentUrl?.trim() ?? '';
      if (url.isEmpty) {
        // Nothing to remove. Not an error, and no write wasted on it.
        return const Success<void>(null);
      }

      final Result<void> cleared = await ref
          .read(profileRepositoryProvider)
          .setPhotoUrl(null);
      if (cleared.isFailure) {
        return cleared;
      }

      // Best effort, result deliberately ignored: the profile no longer points
      // at the object, so a storage failure here costs a few kilobytes of
      // orphaned data and nothing the donor can see. Failing the whole action
      // now would report a failure for something that already worked.
      await ref.read(profilePhotoStorageProvider).removeAvatar(url);
      return const Success<void>(null);
    });
  }

  Future<Result<bool>> _upload(ValidatedPhoto photo) async {
    final ProfilePhotoStorage storage = ref.read(profilePhotoStorageProvider);
    if (!storage.isConfigured) {
      return FailureResult<bool>(
        ConfigurationFailure(
          setting: 'SUPABASE_URL / SUPABASE_ANON_KEY',
          debugMessage: 'A photo upload was attempted without configuration',
        ),
      );
    }

    final Result<String> uploaded = await storage.uploadAvatar(photo);
    final String? url = uploaded.valueOrNull;
    if (url == null) {
      // Nothing was stored, so nothing changed. The previous photo, if any, is
      // still published and still whole.
      return FailureResult<bool>(uploaded.failureOrNull!);
    }

    final Result<void> published = await ref
        .read(profileRepositoryProvider)
        .setPhotoUrl(url);
    if (published.isSuccess) {
      return const Success<bool>(true);
    }

    // Compensate: the object exists but nothing points at it. Deleting it keeps
    // storage in step with the profile instead of accumulating photos no donor
    // can see or remove. If the delete also fails, the object is orphaned — a
    // documented limitation, and still better than publishing a URL that the
    // profile write has already rejected.
    await storage.removeAvatar(url);
    return FailureResult<bool>(published.failureOrNull!);
  }

  /// Runs one operation, mirroring its outcome into [state].
  ///
  /// [AsyncValue] rather than a `bool`, for the reason [ProfileController] gives:
  /// the screen needs idle, in flight and failed-with-a-reason, and no lasting
  /// "saved" flag — success is reported to the caller, which shows the
  /// confirmation and returns to the profile.
  Future<Result<T>> _run<T>(Future<Result<T>> Function() operation) async {
    if (_busy) {
      // Two photo writes at once would race on the same field; the second one
      // would win with a URL from a photo nobody is looking at.
      return FailureResult<T>(
        const ConflictFailure(debugMessage: 'A photo operation is already running'),
      );
    }
    _busy = true;
    state = const AsyncLoading<void>();
    try {
      final Result<T> result = await operation();
      state = switch (result) {
        Success<T>() => const AsyncData<void>(null),
        FailureResult<T>(:final Failure failure) => AsyncError<void>(
          failure,
          StackTrace.current,
        ),
      };
      return result;
    } finally {
      _busy = false;
    }
  }
}

final AsyncNotifierProvider<ProfilePhotoController, void>
profilePhotoControllerProvider =
    AsyncNotifierProvider<ProfilePhotoController, void>(
      ProfilePhotoController.new,
    );
