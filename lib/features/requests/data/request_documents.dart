import 'package:sholovvo_app/core/result/result.dart';

/// One `blood_requests` document exactly as the database returned it.
///
/// The fields are left unreconstructed — a plain map with the wire's own
/// spellings — so that [BloodRequestDocument] stays the only thing that knows how
/// a request is written down. There is no cursor here, unlike the feed's
/// equivalent, because this read has no order to continue from; see
/// `OpenRequests` for why.
final class RequestDocument {
  const RequestDocument({required this.id, required this.fields});

  final String id;
  final Map<String, Object?> fields;
}

/// The one thing [FirestoreRequestRepository] needs from the database.
///
/// It exists so the window, the mapping, the refusal count and the ordering can
/// be tested against literal maps and no Firebase app, in the same style as the
/// rest of the app's repository tests. [FirestoreRequestDocuments] is the only
/// class in the feature that holds a `Query`.
abstract interface class RequestDocuments {
  /// Reads at most [limit] requests whose status is `open`.
  ///
  /// Returns a failure rather than throwing, so the caller can tell "the read was
  /// refused" from "nobody has an open request".
  Future<Result<List<RequestDocument>>> fetch({required int limit});
}
