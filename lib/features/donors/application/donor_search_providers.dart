import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/logging/app_logger.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/donors/application/donor_search_state.dart';
import 'package:sholovvo_app/features/donors/data/firestore_donor_documents.dart';
import 'package:sholovvo_app/features/donors/data/firestore_donor_repository.dart';
import 'package:sholovvo_app/features/donors/domain/discovered_donors.dart';
import 'package:sholovvo_app/features/donors/domain/donor_query.dart';
import 'package:sholovvo_app/features/donors/domain/donor_repository.dart';

/// The donor-search backend.
///
/// The one seam every test of this feature overrides: the screen and the controller
/// depend on [DonorRepository], so no widget or controller test needs a Firebase
/// project. Constructed lazily, like `requestRepositoryProvider`, so a tree that never
/// asks for donors never touches `FirebaseFirestore.instance` either.
///
/// **This points at the real Firestore read, and that read is not certified against
/// the live project yet.** It queries the public `users/{uid}` profiles, which
/// `firestore.rules` opens to any signed-in user — so no *new* rule has to be deployed
/// for it to work. It does NOT read the `donors` collection, which holds phone numbers
/// and which Stage 9.4 closes back to owner-only. What is still blocked on the owner is
/// the deployment of the held working-tree ruleset (documented in `docs/PROJECT_STATE.md`
/// and the Stage 9.4 report); until that lands, the widget and controller tests override
/// this provider with an isolated fake, and the feature ships as implemented-and-tested,
/// not as live-verified.
final Provider<DonorRepository> donorRepositoryProvider =
    Provider<DonorRepository>((Ref ref) {
      return FirestoreDonorRepository(
        FirestoreDonorDocuments(
          FirebaseAuth.instance,
          FirebaseFirestore.instance,
        ),
      );
    });

/// Owns the donor-search window.
///
/// Three operations over one code path. [search] is what a filter change calls — it
/// applies a normalised query and re-reads. [load] and [refresh] re-run the query
/// already on the state, which is what mounting the screen and the pull gesture and
/// "Try again" all mean. Keeping one [_read] is what makes a refresh, a retry and a
/// first load answer identically.
///
/// **One read at a time.** A filter tapped twice in a second, or a pull landing on a
/// read in flight, would otherwise produce two overlapping writes to the same list.
/// A single flag prevents it, because the refresh is a gesture and the group chips are
/// buttons, and neither can be reliably disabled mid-flight.
///
/// **A failed refresh keeps the donors.** The rows on screen were true a moment ago;
/// replacing them with an error page is worse than showing stale-but-real donors and a
/// banner. A *new* search (a changed filter), though, replaces the list, because the
/// old rows were answers to a different question.
class DonorSearchController extends Notifier<DonorSearchState> {
  bool _fetching = false;

  static const AppLogger _logger = AppLogger('donors.search');

  /// Whether a read is in flight. Exposed for tests and for the screen, which must not
  /// start a second one while a read is running.
  bool get isFetching => _fetching;

  @override
  DonorSearchState build() => const DonorSearchState();

  /// Applies [query] and reads the window it asks for.
  Future<void> search(DonorQuery query) => _read(query.normalised());

  /// Re-runs the query already in force. What the screen calls on mount.
  Future<void> load() => _read(state.query);

  /// The pull-to-refresh request. Identical to [load] by construction.
  Future<void> refresh() => load();

  Future<void> _read(DonorQuery query) async {
    if (_fetching) {
      return;
    }
    _fetching = true;

    final bool sameQuery = query == state.query;
    // A refresh of the query already on screen keeps the list; a new filter drops it,
    // because those rows answered a different question. The spinner is only earned
    // when there is nothing to keep.
    state = state.copyWith(
      query: query,
      status: state.donors.isEmpty || !sameQuery
          ? DonorSearchStatus.loading
          : state.status,
      clearFailure: true,
    );

    try {
      final Result<DiscoveredDonors> result = await ref
          .read(donorRepositoryProvider)
          .search(query);
      final DiscoveredDonors? window = result.valueOrNull;

      if (window == null) {
        // Nothing is consumed and no list is dropped: the retry re-asks the same
        // question, and a page already on screen survives a failure to refresh it.
        state = state.copyWith(
          status: state.donors.isEmpty
              ? DonorSearchStatus.failure
              : DonorSearchStatus.ready,
          failure: result.failureOrNull,
        );
        return;
      }

      state = DonorSearchState(
        status: DonorSearchStatus.ready,
        donors: window.donors,
        query: query,
        truncated: window.truncated,
        loaded: true,
        skipped: window.skipped,
      );

      // The operator-facing half of the count, as the feed and requests log theirs: a
      // mapper refusing documents means stored profiles have drifted from the shape the
      // profile layer writes. The line names the number and never a uid or a name.
      if (window.skipped > 0) {
        _logger.warning(
          'Donor search skipped ${window.skipped} unreadable profile document(s)',
        );
      }
    } finally {
      _fetching = false;
    }
  }
}

final NotifierProvider<DonorSearchController, DonorSearchState>
    donorSearchControllerProvider =
    NotifierProvider<DonorSearchController, DonorSearchState>(
      DonorSearchController.new,
    );
