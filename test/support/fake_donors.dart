import 'dart:async';

import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/donors/data/donor_documents.dart';
import 'package:sholovvo_app/features/donors/domain/discovered_donors.dart';
import 'package:sholovvo_app/features/donors/domain/donor_query.dart';
import 'package:sholovvo_app/features/donors/domain/donor_repository.dart';
import 'package:sholovvo_app/features/donors/domain/entities/donor.dart';

/// One valid public `users/{uid}` donor profile, spelled the way
/// `ProfileDocuments.publicFields` writes it and the way the discovery read expects.
///
/// The map is built rather than the entity so the repository tests exercise
/// `DonorProfileDocument.fromUserDoc` — the half of the mapper that reads what another
/// client wrote. `displayName` and `area` are included because every real donor who
/// has finished onboarding has them: a test that did not put them in would not be
/// testing that the read model keeps them while leaving a phone out. The corruptible
/// fields are typed `Object?` on purpose: much of what this mapper is for is deciding
/// what to do with a document whose `role` is not `donor` or whose `bloodGroup` is a
/// ninth spelling, and a helper that only accepted the valid shape could not feed it
/// one.
Map<String, Object?> donorFields({
  String role = 'donor',
  Object? displayName = 'Ayesha Rahman',
  Object? bloodGroup = 'A+',
  Object? isAvailable = true,
  Object? area = 'Dhanmondi, Dhaka',
  Object? photoUrl,
}) {
  return <String, Object?>{
    'role': role,
    'displayName': displayName,
    'bloodGroup': bloodGroup,
    'isAvailable': isAvailable,
    'area': area,
    'photoUrl': ?photoUrl,
    'updatedAt': 0,
  };
}

/// A [DonorDocument] wrapping [fields].
DonorDocument donorDocument(String id, {Map<String, Object?>? fields}) {
  return DonorDocument(id: id, fields: fields ?? donorFields());
}

/// A valid [Donor], for the controller and screen tests.
Donor fakeDonor({
  String uid = 'donor-1',
  String displayName = 'Ayesha Rahman',
  String? bloodGroup = 'A+',
  bool isAvailable = true,
  String? area = 'Dhanmondi, Dhaka',
  String? photoUrl,
}) {
  return Donor(
    uid: uid,
    displayName: displayName,
    bloodGroup: bloodGroup,
    isAvailable: isAvailable,
    area: area,
    photoUrl: photoUrl,
  );
}

/// An in-memory [DonorDocuments].
///
/// Behaves like the query it stands in for: it honours `limit`, records the query it
/// was handed, and counts calls, so the window assembly, the refusal count and the
/// over-fetch-by-one can be tested against literal maps with no Firebase project. The
/// [DonorQuery] itself is not applied here — filtering is the data source's job and is
/// covered against the emulator — this fake exists so the repository's *window* logic
/// has something to read.
class FakeDonorDocuments implements DonorDocuments {
  FakeDonorDocuments(this.documents);

  final List<DonorDocument> documents;

  /// Returned instead of the window when set.
  Failure? failure;

  /// Holds every call open until completed, which is how the "one read at a time"
  /// tests keep two requests genuinely in flight at once.
  Completer<void>? gate;

  int calls = 0;
  int? lastLimit;
  DonorQuery? lastQuery;

  @override
  Future<Result<List<DonorDocument>>> fetch({
    required DonorQuery query,
    required int limit,
  }) async {
    calls++;
    lastLimit = limit;
    lastQuery = query;

    final Completer<void>? pending = gate;
    if (pending != null) {
      await pending.future;
    }

    if (failure != null) {
      return FailureResult<List<DonorDocument>>(failure!);
    }

    return Success<List<DonorDocument>>(
      documents.take(limit).toList(growable: false),
    );
  }
}

/// A [DonorRepository] over a fixed window of donors.
///
/// The real repository is covered against [FakeDonorDocuments]; this one exists for
/// the controller and the screens, which care about *state* rather than about mapping.
class FakeDonorRepository implements DonorRepository {
  FakeDonorRepository({
    List<Donor>? donors,
    this.truncated = false,
    this.skipped = 0,
  }) : donors = donors ?? <Donor>[];

  /// Available first, then by name, as the real repository orders them. Mutable,
  /// because a test that changes the filter between two reads wants the second read
  /// to be able to answer differently.
  List<Donor> donors;

  /// Reported with every window: the directory has more donors than the window holds.
  bool truncated;

  /// Reported with every window: documents inside it the mapper refused.
  int skipped;

  /// Returned instead of a window when set.
  Failure? failure;

  /// Holds every call open until completed.
  Completer<void>? gate;

  int calls = 0;
  DonorQuery? lastQuery;

  @override
  Future<Result<DiscoveredDonors>> search(DonorQuery query) async {
    calls++;
    lastQuery = query;

    final Completer<void>? pending = gate;
    if (pending != null) {
      await pending.future;
    }

    if (failure != null) {
      return FailureResult<DiscoveredDonors>(failure!);
    }

    return Success<DiscoveredDonors>(
      DiscoveredDonors(
        donors: donors,
        truncated: truncated,
        skipped: skipped,
      ),
    );
  }
}
