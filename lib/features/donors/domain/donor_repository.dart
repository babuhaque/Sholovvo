import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/donors/domain/discovered_donors.dart';
import 'package:sholovvo_app/features/donors/domain/donor_query.dart';

/// The read side of donor discovery.
///
/// One method, and it writes nothing — the same shape [RequestRepository] takes.
/// Contacting a donor, responding to their availability, or requesting blood from
/// them is Stage 10's transaction, and putting a write on this port would make
/// every read fake answer a question it has no opinion about. It would also be the
/// first place a phone number could leak: this repository reads only the public
/// profile document, which holds none.
///
/// Returns `Result` rather than throwing, like every other repository here, so the
/// screen can tell "no donors match" from "the directory could not be read". An
/// empty list cannot tell those two apart, and only one of them means the person
/// should stop looking.
abstract interface class DonorRepository {
  /// How many documents one search looks at.
  ///
  /// A window rather than a page: there is no cursor and no trusted sort field at
  /// the database level (see `DiscoveredDonors` for why), so this number is a cost
  /// ceiling, not a chapter. It exists to bound what one filter change can cost on
  /// the Spark plan's daily read quota — the same reason [RequestRepository.window]
  /// and the feed's page size exist. Thirty because a donor directory is browsed
  /// more than it is hunted, and the rows are cheap.
  ///
  /// The repository asks for one more than it keeps, so `DiscoveredDonors.truncated`
  /// is measured rather than inferred, and a directory that happens to end exactly
  /// on this number does not produce a notice about donors that are not there.
  static const int window = 30;

  /// Reads the current window of consented donors matching [query].
  Future<Result<DiscoveredDonors>> search(DonorQuery query);
}
