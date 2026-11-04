import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/logging/app_logger.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/donors/data/donor_documents.dart';
import 'package:sholovvo_app/features/donors/data/models/donor_profile_document.dart';
import 'package:sholovvo_app/features/donors/domain/discovered_donors.dart';
import 'package:sholovvo_app/features/donors/domain/donor_ordering.dart';
import 'package:sholovvo_app/features/donors/domain/donor_query.dart';
import 'package:sholovvo_app/features/donors/domain/donor_repository.dart';
import 'package:sholovvo_app/features/donors/domain/entities/donor.dart';

/// Turns raw public `users` documents into a [DiscoveredDonors] window.
///
/// It holds no Firestore type: the query lives in [FirestoreDonorDocuments], the
/// field spellings live in [DonorProfileDocument], and this class only decides what
/// a window is and what to do about a document it cannot read. That keeps the
/// truncation rule, the refusal count and the ordering — the parts most likely to be
/// wrong and hardest to test against a live project — exercisable against literal
/// maps with no emulator.
class FirestoreDonorRepository implements DonorRepository {
  FirestoreDonorRepository(this._documents);

  final DonorDocuments _documents;

  static const AppLogger _logger = AppLogger('donors');

  @override
  Future<Result<DiscoveredDonors>> search(DonorQuery query) async {
    // One extra document, so "did the window fill up?" is answered by the same read
    // that fills it rather than by a second query: the over-fetch-by-one that makes
    // `truncated` a measurement, as in the requests and feed repositories.
    final Result<List<DonorDocument>> fetched = await _documents.fetch(
      query: query,
      limit: DonorRepository.window + 1,
    );

    final Failure? failure = fetched.failureOrNull;
    if (failure != null) {
      return FailureResult<DiscoveredDonors>(failure);
    }

    final List<DonorDocument> documents = fetched.valueOrNull!;
    final bool truncated = documents.length > DonorRepository.window;
    final List<DonorDocument> window = truncated
        ? documents.sublist(0, DonorRepository.window)
        : documents;

    final List<Donor> donors = <Donor>[];
    int skipped = 0;

    for (final DonorDocument document in window) {
      final Result<Donor> mapped = DonorProfileDocument.fromUserDoc(
        id: document.id,
        data: Map<String, Object?>.from(document.fields),
      );
      final Donor? donor = mapped.valueOrNull;
      if (donor == null) {
        // Refused, not repaired. One profile whose group is a stray spelling must
        // not cost the searcher the good donors around it, so it is dropped and
        // counted. The debug line carries only the failure, which names a field and
        // a value *type* — never a donor's name or area.
        skipped++;
        _logger.warning('Skipped an unreadable donor profile', error: mapped.failureOrNull);
        continue;
      }
      donors.add(donor);
    }

    return Success<DiscoveredDonors>(
      DiscoveredDonors(
        donors: orderDonors(donors),
        truncated: truncated,
        skipped: skipped,
      ),
    );
  }
}
