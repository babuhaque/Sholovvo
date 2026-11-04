import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/requests/data/models/blood_request_document.dart';
import 'package:sholovvo_app/features/requests/data/request_documents.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';
import 'package:sholovvo_app/features/requests/domain/open_requests.dart';
import 'package:sholovvo_app/features/requests/domain/request_repository.dart';

/// One valid `blood_requests` document, spelled the way the create rule in
/// `firestore.rules` requires it and the way
/// `firestore-rules-tests/firestore.test.js` seeds it.
///
/// The map is built rather than the entity so the repository tests exercise
/// `BloodRequestDocument.fromMap` — the half of the mapper that reads what another
/// client wrote. `patientName` and `phoneNumber` are included because every real
/// document has them: a test that does not put them in would not be testing that
/// the read model leaves them out.
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
BloodRequest fakeRequest({
  String id = 'req-1',
  String bloodGroup = 'A+',
  String hospitalName = 'Dhaka Medical College',
  String hospitalAddress = 'Dhaka',
  int units = 1,
  DateTime? neededBy,
  String neededByText = '',
}) {
  return BloodRequest(
    id: id,
    bloodGroup: bloodGroup,
    hospitalName: hospitalName,
    hospitalAddress: hospitalAddress,
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
