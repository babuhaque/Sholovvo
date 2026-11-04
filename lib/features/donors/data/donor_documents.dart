import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/donors/domain/donor_query.dart';

/// One `users/{uid}` public profile document exactly as the database returned it.
///
/// The fields are left unreconstructed — a plain map with the wire's own spellings
/// — so that `DonorProfileDocument` stays the only thing that knows how a donor is
/// written down. There is no cursor here, unlike the feed's equivalent, because this
/// read is a window with no order to continue from; see `DiscoveredDonors`.
final class DonorDocument {
  const DonorDocument({required this.id, required this.fields});

  /// The document id, which is the donor's uid.
  final String id;
  final Map<String, Object?> fields;
}

/// The one thing [FirestoreDonorRepository] needs from the database.
///
/// It exists so the window, the mapping, the refusal count and the ordering can be
/// tested against literal maps and no Firebase app, in the same style as the rest of
/// the app's repository tests. [FirestoreDonorDocuments] is the only class in the
/// feature that holds a `Query`.
abstract interface class DonorDocuments {
  /// Reads at most [limit] public donor profiles matching [query].
  ///
  /// Returns a failure rather than throwing, so the caller can tell "the read was
  /// refused" from "nobody has consented to be found".
  Future<Result<List<DonorDocument>>> fetch({
    required DonorQuery query,
    required int limit,
  });
}
