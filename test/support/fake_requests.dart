import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/requests/data/models/blood_request_document.dart';
import 'package:sholovvo_app/features/requests/data/request_accept_service.dart';
import 'package:sholovvo_app/features/requests/data/request_cancel_service.dart';
import 'package:sholovvo_app/features/requests/data/request_contact_service.dart';
import 'package:sholovvo_app/features/requests/data/request_documents.dart';
import 'package:sholovvo_app/features/requests/data/request_edit_service.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';
import 'package:sholovvo_app/features/requests/domain/entities/request_contact.dart';
import 'package:sholovvo_app/features/requests/domain/open_requests.dart';
import 'package:sholovvo_app/features/requests/domain/request_repository.dart';

/// One valid `blood_requests` document, spelled the way the create rule in
/// `firestore.rules` requires it and the way
/// `firestore-rules-tests/firestore.test.js` seeds it.
///
/// The map is built rather than the entity so the repository tests exercise
/// `BloodRequestDocument.fromMap` — the half of the mapper that reads what another
/// client wrote. `patientName`, `phoneNumber` and `hospitalAddress` are included
/// because every legacy document has them: a test that does not put them in would
/// not be testing that the read model leaves them out (Stage 9.5 M3-C1 moved all
/// three to the private/contact subcollection).
/// The mutable fields are typed `Object?` on purpose: half of what this mapper is
/// for is deciding what to do with a document whose `bloodBags` is a string or
/// whose `bloodGroup` is a ninth spelling, and a helper that only accepted the
/// valid shape could not feed it one.
Map<String, Object?> requestFields({
  String userId = 'uid-recipient',
  String patientName = 'Patient',
  String phoneNumber = '+8801700000000',
  Object? bloodGroup = 'A+',
  Object? bloodBags = 1,
  Object? hospitalName = 'Dhaka Medical College',
  Object? hospitalAddress = 'Dhaka',
  Object? requiredDateTime = '2026-11-10 10:00 AM',
  Object? status = BloodRequestDocument.openStatus,
  String requestType = 'Normal',
  String notes = '',
  DateTime? createdAt,
}) {
  return <String, Object?>{
    'userId': userId,
    'patientName': patientName,
    'phoneNumber': phoneNumber,
    'bloodGroup': bloodGroup,
    'bloodBags': bloodBags,
    'hospitalName': hospitalName,
    'hospitalAddress': hospitalAddress,
    'requiredDateTime': requiredDateTime,
    'status': status,
    'requestType': requestType,
    'notes': notes,
    'latitude': 23.8,
    'longitude': 90.4,
    'assignedDonorId': null,
    'createdAt': Timestamp.fromDate(
      (createdAt ?? DateTime.utc(2026, 11, 8, 6)).toUtc(),
    ),
  };
}

/// A [RequestDocument] wrapping [fields].
RequestDocument requestDocument(String id, {Map<String, Object?>? fields}) {
  return RequestDocument(id: id, fields: fields ?? requestFields());
}

/// A valid [BloodRequest], for the controller and screen tests.
///
/// [neededBy] and [neededByText] are set together the way the mapper sets them: an
/// instant arrives with no verbatim text, and text alone means the instant is null.
///
/// [userId] defaults to `'uid-recipient'` — the same uid [requestFields] uses —
/// so a caller that overrides [requestsAuthUidProvider] to the same string gets
/// the owner branch of the detail screen without needing to know about either
/// default.
BloodRequest fakeRequest({
  String id = 'req-1',
  String userId = 'uid-recipient',
  String bloodGroup = 'A+',
  String hospitalName = 'Dhaka Medical College',
  int units = 1,
  DateTime? neededBy,
  String neededByText = '',
}) {
  return BloodRequest(
    id: id,
    userId: userId,
    bloodGroup: bloodGroup,
    hospitalName: hospitalName,
    units: units,
    neededBy: neededBy,
    neededByText: neededByText,
  );
}

/// An in-memory [RequestDocuments].
///
/// Behaves like the query it stands in for: it honours `limit` and counts calls,
/// so the window assembly, the refusal count and the over-fetch-by-one can be
/// tested against literal maps with no Firebase project.
class FakeRequestDocuments implements RequestDocuments {
  FakeRequestDocuments(this.documents);

  final List<RequestDocument> documents;

  /// Returned instead of the window when set.
  Failure? failure;

  /// Holds every call open until completed, which is how the "one read at a time"
  /// tests keep two requests genuinely in flight at once.
  Completer<void>? gate;

  int calls = 0;
  int? lastLimit;

  @override
  Future<Result<List<RequestDocument>>> fetch({required int limit}) async {
    calls++;
    lastLimit = limit;

    final Completer<void>? pending = gate;
    if (pending != null) {
      await pending.future;
    }

    if (failure != null) {
      return FailureResult<List<RequestDocument>>(failure!);
    }

    return Success<List<RequestDocument>>(
      documents.take(limit).toList(growable: false),
    );
  }
}

/// A [RequestRepository] over a fixed window of requests.
///
/// The real repository is covered against [FakeRequestDocuments]; this one exists
/// for the controller and the screens, which care about *state* rather than about
/// mapping.
class FakeRequestRepository implements RequestRepository {
  FakeRequestRepository({
    List<BloodRequest>? requests,
    this.truncated = false,
    this.skipped = 0,
  }) : requests = requests ?? <BloodRequest>[];

  /// Soonest needed first, as the real repository orders them. Mutable, because a
  /// test that publishes something between two reads wants the second read to see
  /// it.
  List<BloodRequest> requests;

  /// Reported with every window: the collection has more open requests than the
  /// window holds.
  bool truncated;

  /// Reported with every window: documents inside it the mapper refused.
  int skipped;

  /// Returned instead of a window when set.
  Failure? failure;

  /// Holds every call open until completed.
  Completer<void>? gate;

  int calls = 0;

  @override
  Future<Result<OpenRequests>> loadOpenRequests() async {
    calls++;

    final Completer<void>? pending = gate;
    if (pending != null) {
      await pending.future;
    }

    if (failure != null) {
      return FailureResult<OpenRequests>(failure!);
    }

    return Success<OpenRequests>(
      OpenRequests(
        requests: requests,
        truncated: truncated,
        skipped: skipped,
      ),
    );
  }
}

/// An in-memory [RequestAcceptService].
///
/// Records every call as a `(requestId, donorUid)` pair, so a widget test
/// can assert the detail screen passed the right donor id. Also drives the
/// error branch (a race that another donor won) for the accept-affordance
/// tests.
class FakeRequestAcceptService implements RequestAcceptService {
  /// Each entry is `(requestId, donorUid)` in call order.
  final List<(String, String)> calls = <(String, String)>[];

  /// Holds every call open until completed.
  Completer<void>? gate;

  /// Returned instead of a success when set.
  Failure? failure;

  @override
  Future<Result<void>> acceptRequest({
    required String requestId,
    required String donorUid,
  }) async {
    calls.add((requestId, donorUid));

    final Completer<void>? pending = gate;
    if (pending != null) {
      await pending.future;
    }

    final Failure? f = failure;
    if (f != null) {
      return FailureResult<void>(f);
    }
    return const Success<void>(null);
  }
}

/// An in-memory [RequestCancelService].
///
/// Records every call, so a widget test can assert that a cancel-tap actually
/// reached the service (rather than only that a dialog dismissed), and can drive
/// both the success and the failure branch of the detail screen's write flow.
class FakeRequestCancelService implements RequestCancelService {
  /// Called with every [requestId] passed to [cancelRequest], in call order.
  final List<String> calls = <String>[];

  /// When set, [cancelRequest] awaits this future before doing anything else.
  /// Tests use it to keep a write in flight long enough to observe the loading
  /// state and to double-tap-guard against a second call.
  Completer<void>? gate;

  /// Returned instead of a success when set.
  Failure? failure;

  @override
  Future<Result<void>> cancelRequest({required String requestId}) async {
    calls.add(requestId);

    final Completer<void>? pending = gate;
    if (pending != null) {
      await pending.future;
    }

    final Failure? f = failure;
    if (f != null) {
      return FailureResult<void>(f);
    }
    return const Success<void>(null);
  }
}

/// An in-memory [RequestEditService].
///
/// Records every call as a `(requestId, fields)` pair, so a widget test can
/// assert not only that the edit-tap reached the service but what the form
/// actually sent — the two facts a bug in the field whitelist could easily
/// separate (a call happens, but it carries a key the rules will refuse).
class FakeRequestEditService implements RequestEditService {
  /// Each entry is `(requestId, fields)` in call order. Kept as a record so a
  /// test can destructure rather than index into parallel lists.
  final List<(String, Map<String, Object?>)> calls =
      <(String, Map<String, Object?>)>[];

  /// Holds every call open until completed, for the loading / double-tap
  /// guard tests.
  Completer<void>? gate;

  /// Returned instead of a success when set.
  Failure? failure;

  @override
  Future<Result<void>> editRequest({
    required String requestId,
    required Map<String, Object?> fields,
  }) async {
    // Copy the map before storing — a later mutation in the form's controller
    // would otherwise edit the recorded call and the test's assertion would
    // describe a shape the service never actually saw.
    calls.add((requestId, Map<String, Object?>.of(fields)));

    final Completer<void>? pending = gate;
    if (pending != null) {
      await pending.future;
    }

    final Failure? f = failure;
    if (f != null) {
      return FailureResult<void>(f);
    }
    return const Success<void>(null);
  }
}

/// An in-memory [RequestContactService].
///
/// Records every call as a `(requestId, patientName, phoneNumber,
/// hospitalAddress)` tuple, so a widget test can assert both that the
/// contact-tap reached the service and what the form actually sent — including
/// that an empty hospital address still reaches the service (the one field the
/// rule allows to be blank). Holds the values rather than reading them back,
/// because this fake (like the app) never reads a contact document.
class FakeRequestContactService implements RequestContactService {
  /// Each entry is `(requestId, patientName, phoneNumber, hospitalAddress)` in
  /// call order.
  final List<(String, String, String, String)> calls =
      <(String, String, String, String)>[];

  /// Holds every [saveContact] call open until completed, for the loading /
  /// double-tap guard tests.
  Completer<void>? gate;

  /// Returned instead of a success on [saveContact] when set.
  Failure? failure;

  /// The contact [loadContact] returns. `null` (the default) means "no contact
  /// saved yet" — the first-capture case.
  RequestContact? nextContact;

  /// Returned instead of [nextContact] on [loadContact] when set, to drive the
  /// form's load-failure / retry branch.
  Failure? loadFailure;

  /// Holds every [loadContact] call open until completed, so the loading state is
  /// observable in a test.
  Completer<void>? loadGate;

  /// Called with every [requestId] passed to [loadContact], in call order.
  final List<String> loadCalls = <String>[];

  @override
  Future<Result<RequestContact?>> loadContact({
    required String requestId,
  }) async {
    loadCalls.add(requestId);

    final Completer<void>? pending = loadGate;
    if (pending != null) {
      await pending.future;
    }

    final Failure? f = loadFailure;
    if (f != null) {
      return FailureResult<RequestContact?>(f);
    }
    return Success<RequestContact?>(nextContact);
  }

  @override
  Future<Result<void>> saveContact({
    required String requestId,
    required String patientName,
    required String phoneNumber,
    required String hospitalAddress,
  }) async {
    calls.add((requestId, patientName, phoneNumber, hospitalAddress));

    final Completer<void>? pending = gate;
    if (pending != null) {
      await pending.future;
    }

    final Failure? f = failure;
    if (f != null) {
      return FailureResult<void>(f);
    }
    return const Success<void>(null);
  }
}
