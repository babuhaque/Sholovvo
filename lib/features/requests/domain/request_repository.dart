import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/requests/domain/open_requests.dart';

/// The read side of `blood_requests`.
///
/// One method, and it writes nothing. Claiming a request is the transaction that
/// belongs to Stage 10 — `firestore.rules` already enforces it, through
/// `request_responses`, `response_claims` and the donor branch of the
/// `blood_requests` update rule — and putting a write on this port would make
/// every read fake answer a question it has no opinion about.
///
/// Returns `Result` rather than throwing, like every other repository in this
/// app: "there are no open requests" and "the requests could not be read" are
/// different sentences on screen, and an empty list cannot tell them apart.
abstract interface class RequestRepository {
  /// How many documents one read looks at.
  ///
  /// Twenty-five, and it is a window rather than a page: this read has no cursor
  /// (see [OpenRequests] for why an unordered window cannot be paged forward), so
  /// the number is the cost ceiling, not a chapter of a list. It is generous for
  /// the collection it addresses — an *open* request stops being open the moment
  /// somebody claims or cancels it, so the set is transient by design and does not
  /// grow the way `posts` does — and it bounds what one refresh can cost on the
  /// Spark plan's daily read quota, which the feed's page size exists for the same
  /// reason.
  ///
  /// The repository asks the database for one more than it keeps, so
  /// [OpenRequests.truncated] is measured rather than inferred, and a collection
  /// that happens to end exactly on this number does not produce a notice about
  /// requests that are not there.
  static const int window = 25;

  /// Reads the current window of requests whose `status` is `open`, soonest
  /// needed first.
  Future<Result<OpenRequests>> loadOpenRequests();
}
