import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/logging/app_logger.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/requests/data/models/blood_request_document.dart';
import 'package:sholovvo_app/features/requests/data/request_documents.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';
import 'package:sholovvo_app/features/requests/domain/open_requests.dart';
import 'package:sholovvo_app/features/requests/domain/request_ordering.dart';
import 'package:sholovvo_app/features/requests/domain/request_repository.dart';

/// Turns raw `blood_requests` documents into an [OpenRequests] window.
///
/// It holds no Firestore type: the query lives in [FirestoreRequestDocuments],
/// the field spellings live in [BloodRequestDocument], and this class only
/// decides what a window is and what to do about a document it cannot read. That
/// is deliberate — the truncation rule and the refusal count are the parts most
/// likely to be wrong and the parts hardest to test against a live project.
class FirestoreRequestRepository implements RequestRepository {
  FirestoreRequestRepository(this._documents);

  final RequestDocuments _documents;

  static const AppLogger _logger = AppLogger('requests');

  @override
  Future<Result<OpenRequests>> loadOpenRequests() async {
    // One extra document, so "did the window fill up?" is answered by the same
    // read that fills it rather than by a second query nobody asked for. This is
    // the feed's over-fetch-by-one, and it is what makes `truncated` exact: a
    // collection with exactly [RequestRepository.window] open requests does not
    // get a notice about requests that are not there.
    final Result<List<RequestDocument>> fetched = await _documents.fetch(
      limit: RequestRepository.window + 1,
    );

    final Failure? failure = fetched.failureOrNull;
    if (failure != null) {
      return FailureResult<OpenRequests>(failure);
    }

    final List<RequestDocument> documents = fetched.valueOrNull!;
    final bool truncated = documents.length > RequestRepository.window;
    final List<RequestDocument> window = truncated
        ? documents.sublist(0, RequestRepository.window)
        : documents;

    final List<BloodRequest> requests = <BloodRequest>[];
    int skipped = 0;

    for (final RequestDocument document in window) {
      final Result<BloodRequest> mapped = BloodRequestDocument.fromMap(
        id: document.id,
        data: Map<String, dynamic>.from(document.fields),
      );
      final BloodRequest? request = mapped.valueOrNull;
      if (request == null) {
        // Refused, not repaired. One document with a blood group this app does not
        // recognise must not cost the donor the twenty-four good requests around
        // it, so it is dropped and counted. The debug message carries only the
        // field name and the value's *type*, never its content, because the
        // document also holds a patient's name and phone number.
        skipped++;
        _logger.warning(
          'Skipped an unreadable request',
          error: mapped.failureOrNull,
        );
        continue;
      }
      requests.add(request);
    }

    return Success<OpenRequests>(
      OpenRequests(
        requests: orderRequests(requests),
        truncated: truncated,
        skipped: skipped,
      ),
    );
  }
}
