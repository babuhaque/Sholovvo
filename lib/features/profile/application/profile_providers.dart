import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/profile/data/firestore_profile_repository.dart';
import 'package:sholovvo_app/features/profile/domain/donation_record.dart';
import 'package:sholovvo_app/features/profile/domain/profile_repository.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';

/// The profile backend.
///
/// The one seam every profile test overrides: the screens depend on
/// [ProfileRepository], so no widget test needs a Firebase project. Constructed
/// lazily so a test that never reaches a profile screen never touches
/// `FirebaseFirestore.instance` either.
final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>((Ref ref) {
      return FirestoreProfileRepository(
        FirebaseAuth.instance,
        FirebaseFirestore.instance,
      );
    });

/// The signed-in user's profile, live.
///
/// `null` means "no profile document yet", which the screen renders as a prompt
/// to create one rather than as an empty card. A stream rather than a one-shot
/// read so the availability switch and a save both land on screen without the
/// screen having to re-fetch by hand.
final StreamProvider<UserProfile?> profileProvider =
    StreamProvider<UserProfile?>((Ref ref) {
      return ref.watch(profileRepositoryProvider).watchProfile();
    });

/// The signed-in donor's donation history.
///
/// Wrapped in [Result] rather than thrown: "there is no history" and "the read
/// failed" are different sentences on screen, and flattening them into an empty
/// list would show someone a zero where the truth is unknown.
final FutureProvider<Result<DonationHistory>> donationHistoryProvider =
    FutureProvider<Result<DonationHistory>>((Ref ref) {
      return ref.watch(profileRepositoryProvider).loadDonationHistory();
    });

/// The screen-wide state of the last profile write.
///
/// [AsyncValue] rather than a bare `bool` because the screen needs three states,
/// not two: idle, in flight, and failed-with-a-reason. There is deliberately no
/// "saved" flag held here — success is reported to the caller, which shows a
/// confirmation and leaves; a lasting success state would be a second source of
/// truth about whether the write happened.
class ProfileController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Result<void>> save(UserProfile profile) {
    return _run(() => ref.read(profileRepositoryProvider).saveProfile(profile));
  }

  Future<Result<void>> setAvailability(bool isAvailable) {
    return _run(
      () => ref.read(profileRepositoryProvider).setAvailability(isAvailable),
    );
  }

  Future<Result<void>> _run(Future<Result<void>> Function() write) async {
    state = const AsyncLoading<void>();
    final Result<void> result = await write();
    state = switch (result) {
      Success<void>() => const AsyncData<void>(null),
      FailureResult<void>(:final Failure failure) => AsyncError<void>(
        failure,
        StackTrace.current,
      ),
    };
    return result;
  }
}

final AsyncNotifierProvider<ProfileController, void> profileControllerProvider =
    AsyncNotifierProvider<ProfileController, void>(ProfileController.new);
