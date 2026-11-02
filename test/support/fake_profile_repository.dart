import 'dart:async';

import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/profile/domain/donation_record.dart';
import 'package:sholovvo_app/features/profile/domain/profile_repository.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';

/// In-memory [ProfileRepository] for widget tests.
///
/// Behaves like the Firestore implementation where it matters: a save updates
/// what the stream emits (the real repository reads the document back), a
/// configured failure is returned instead of writing, and nothing is invented —
/// a fresh fake has *no* profile document at all, so the default rendering is
/// the empty state rather than a sample donor.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({
    this.profile,
    this.history = DonationHistory.empty,
  });

  /// Pushes a profile change, as a Firestore snapshot would.
  final StreamController<UserProfile?> _controller =
      StreamController<UserProfile?>.broadcast();

  /// The document as it would be stored. Public so a test can assert on what a
  /// save left behind as well as on what the stream last emitted.
  UserProfile? profile;
  DonationHistory history;

  /// When set, the matching call returns this failure instead of succeeding.
  Failure? saveFailure;
  Failure? availabilityFailure;
  Failure? historyFailure;
  Failure? photoUrlFailure;

  /// When set, the profile stream fails before emitting, which is the state the
  /// screen has to survive without claiming "no profile".
  Failure? streamFailure;

  int saveCalls = 0;
  int availabilityCalls = 0;
  int historyCalls = 0;
  int photoUrlCalls = 0;

  /// The last payload handed to [saveProfile], for asserting what a form
  /// actually submitted.
  UserProfile? lastSaved;
  bool? lastAvailability;

  /// The last URL handed to [setPhotoUrl], and whether it was called at all.
  /// `null` after a successful call means "the photo was removed".
  String? lastPhotoUrl;

  /// Replaces the document and notifies listeners.
  void emit(UserProfile? next) {
    profile = next;
    _controller.add(next);
  }

  Future<void> dispose() => _controller.close();

  @override
  Stream<UserProfile?> watchProfile() async* {
    if (streamFailure != null) {
      yield* Stream<UserProfile?>.error(streamFailure!);
      return;
    }
    final UserProfile? current = profile;
    yield current;
    yield* _controller.stream;
  }

  @override
  Future<Result<void>> saveProfile(UserProfile saved) async {
    saveCalls++;
    lastSaved = saved;
    if (saveFailure != null) {
      return FailureResult<void>(saveFailure!);
    }
    emit(saved);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> setAvailability(bool isAvailable) async {
    availabilityCalls++;
    lastAvailability = isAvailable;
    if (availabilityFailure != null) {
      return FailureResult<void>(availabilityFailure!);
    }
    final UserProfile? current = profile;
    // The real repository writes the flag onto the existing document; with no
    // document there is nothing to update, exactly as on the server.
    if (current != null) {
      emit(current.copyWith(isAvailable: isAvailable));
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<DonationHistory>> loadDonationHistory() async {
    historyCalls++;
    if (historyFailure != null) {
      return FailureResult<DonationHistory>(historyFailure!);
    }
    return Success<DonationHistory>(history);
  }

  @override
  Future<Result<void>> setPhotoUrl(String? photoUrl) async {
    photoUrlCalls++;
    lastPhotoUrl = photoUrl;
    if (photoUrlFailure != null) {
      return FailureResult<void>(photoUrlFailure!);
    }
    final UserProfile? current = profile;
    // The real repository merges one field into the existing document; with no
    // document there is nothing to update, exactly as on the server.
    if (current != null) {
      emit(current.withPhoto(photoUrl));
    }
    return const Success<void>(null);
  }
}

/// A donor who has filled in the profile, for the populated-state tests.
const UserProfile filledProfile = UserProfile(
  uid: 'uid-verified',
  displayName: 'Ayesha Rahman',
  bloodGroup: 'O+',
  area: 'Dhanmondi, Dhaka',
  addressLine: 'House 12, Road 5',
  phone: '01712345678',
  dateOfBirth: null,
  gender: ProfileGender.female,
  isAvailable: true,
  publishAreaInSearch: true,
  updatedAt: null,
);

/// The same donor with only a name and a blood group: five fields still empty,
/// so the completion indicator has something real to report.
const UserProfile partialProfile = UserProfile(
  uid: 'uid-verified',
  displayName: 'Ayesha Rahman',
  bloodGroup: 'O+',
  gender: ProfileGender.female,
);

/// Two confirmed donations and one still pending.
DonationHistory sampleHistory() {
  return DonationHistory(
    <DonationRecord>[
      DonationRecord(
        id: 'don-2',
        bloodGroup: 'O+',
        hospitalName: 'Dhaka Medical College Hospital',
        status: DonationStatus.confirmed,
        donatedAt: DateTime(2026, 9, 12),
        recordedAt: DateTime(2026, 9, 12),
      ),
      DonationRecord(
        id: 'don-1',
        bloodGroup: 'O+',
        hospitalName: 'Square Hospital',
        status: DonationStatus.confirmed,
        donatedAt: DateTime(2026, 3, 4),
        recordedAt: DateTime(2026, 3, 4),
      ),
      DonationRecord(
        id: 'don-3',
        bloodGroup: 'O+',
        hospitalName: 'United Hospital',
        status: DonationStatus.pending,
        donatedAt: null,
        recordedAt: DateTime(2026, 10, 30),
      ),
    ],
  );
}
