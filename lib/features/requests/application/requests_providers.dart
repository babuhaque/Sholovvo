import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/logging/app_logger.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/requests/application/requests_state.dart';
import 'package:sholovvo_app/features/requests/data/firestore_request_documents.dart';
import 'package:sholovvo_app/features/requests/data/firestore_request_repository.dart';
import 'package:sholovvo_app/features/requests/data/request_accept_service.dart';
import 'package:sholovvo_app/features/requests/data/request_cancel_service.dart';
import 'package:sholovvo_app/features/requests/data/request_contact_service.dart';
import 'package:sholovvo_app/features/requests/data/request_create_service.dart';
import 'package:sholovvo_app/features/requests/data/request_edit_service.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';
import 'package:sholovvo_app/features/requests/domain/open_requests.dart';
import 'package:sholovvo_app/features/requests/domain/request_repository.dart';

/// The requests backend.
///
/// The one seam every test of this feature overrides: the screen and the
/// controller depend on [RequestRepository], so no widget or controller test needs
/// a Firebase project. Constructed lazily, like `feedRepositoryProvider`, so a tree
/// that never asks for requests never touches `FirebaseFirestore.instance` either.
final Provider<RequestRepository> requestRepositoryProvider =
    Provider<RequestRepository>((Ref ref) {
      return FirestoreRequestRepository(
        FirestoreRequestDocuments(
          FirebaseAuth.instance,
          FirebaseFirestore.instance,
        ),
      );
    });

/// The signed-in user's uid, or null.
///
/// A separate provider within the requests layer so that widget tests can
/// override it without a full Firebase initialization, and so the detail
/// screen can answer "is this request mine" at build time.
///
/// Mirrors `authUidProvider` in `feed_providers.dart`. A future stage that
/// centralises uid access may collapse the two into a shared core provider;
/// duplicating eight lines now avoids a cross-feature import that would
/// violate the layering contract.
final Provider<String?> requestsAuthUidProvider = Provider<String?>((Ref ref) {
  try {
    return FirebaseAuth.instance.currentUser?.uid;
  } catch (_) {
    return null;
  }
});

/// The service that creates new blood requests.
final Provider<RequestCreateService> requestCreateServiceProvider =
    Provider<RequestCreateService>((Ref ref) {
  return FirestoreRequestCreateService(FirebaseFirestore.instance);
});

/// The service that cancels (withdraws) an open blood request.
final Provider<RequestCancelService> requestCancelServiceProvider =
    Provider<RequestCancelService>((Ref ref) {
  return FirestoreRequestCancelService(FirebaseFirestore.instance);
});

/// The service that accepts (claims) an open blood request as a donor.
///
/// The write is a single-document status transition (`open` → `accepted`) with
/// `assignedDonorId` and `acceptedAt`. Eligibility is enforced at the rules
/// layer and mirrored client-side by the detail screen's accept gate (profile
/// `isAvailable`, `bloodGroup` match, non-owner).
final Provider<RequestAcceptService> requestAcceptServiceProvider =
    Provider<RequestAcceptService>((Ref ref) {
  return FirestoreRequestAcceptService(FirebaseFirestore.instance);
});

/// The service that edits an open blood request while it is still open.
///
/// Sibling of the cancel service. The rules permit a same-user field-edit on
/// an `open` request that touches only the eight keys
/// `firestore.rules` L127-131 lists; this service mirrors that constraint
/// client-side and refuses a wider mutation before the write ever leaves the
/// app.
final Provider<RequestEditService> requestEditServiceProvider =
    Provider<RequestEditService>((Ref ref) {
  return FirestoreRequestEditService(FirebaseFirestore.instance);
});

/// The service that captures the owner's private contact record.
///
/// Sibling of the edit service, and the only write path in this app that touches
/// `blood_requests/{id}/private/contact`. The rules permit an owner to
/// create/update that document (`firestore.rules` L219-228); reading it back to a
/// matched donor stays blocked by the M3-C2 blocker, so the app never reads a
/// contact here — this is a pure owner capture, the prerequisite any future
/// donor-read story needs before it can show real data.
final Provider<RequestContactService> requestContactServiceProvider =
    Provider<RequestContactService>((Ref ref) {
  return FirestoreRequestContactService(FirebaseFirestore.instance);
});

/// Owns the open-requests window.
///
/// Two operations, and they are the same request under two names — [load] is what
/// the screen calls on mount and what "Try again" calls after a failure, and
/// [refresh] is the pull gesture's word for it. Keeping one code path is what makes
/// a refresh and a first load answer identically, including the cursor neither of
/// them has.
///
/// **One read at a time.** A pull-to-refresh landing on top of a read in flight
/// would produce two overlapping writes to the same state, and a list whose second
/// half belongs to a different window. Prevented by one flag rather than by
/// disabling buttons, because the gesture is not a button. It also means a donor
/// who taps "Try again" four times in a row pays for one read.
///
/// **A failed refresh keeps the list.** The requests on screen were true a moment
/// ago; replacing them with an error page throws away the only useful thing the
/// donor has. The banner above the list says the picture may be old, which is the
/// whole message.
class RequestsController extends Notifier<RequestsState> {
  bool _fetching = false;

  static const AppLogger _logger = AppLogger('requests.read');

  /// Whether a read is in flight. Exposed for tests and for the screen's footer,
  /// which must not offer a second one while a read is running.
  bool get isFetching => _fetching;

  @override
  RequestsState build() => const RequestsState();

  /// Reads the window, replacing whatever is on screen.
  Future<void> load() {
    if (_fetching) {
      return Future<void>.value();
    }
    return _read();
  }

  /// The pull-to-refresh request. Identical to [load] by construction.
  Future<void> refresh() => load();

  Future<void> _read() async {
    if (_fetching) {
      return;
    }
    _fetching = true;

    // A refresh with requests on screen keeps them: the list is still true, and
    // blanking it for a spinner is a worse answer than showing stale-but-real
    // requests for another second.
    state = state.requests.isEmpty
        ? state.copyWith(status: RequestsStatus.loading, clearFailure: true)
        : state.copyWith(clearFailure: true);

    try {
      final Result<OpenRequests> result = await ref
          .read(requestRepositoryProvider)
          .loadOpenRequests();
      final OpenRequests? window = result.valueOrNull;

      if (window == null) {
        // Nothing is consumed and no list is dropped: the retry re-asks the same
        // question, and a page already on screen survives a failure to refresh it.
        state = state.copyWith(
          status: state.requests.isEmpty
              ? RequestsStatus.failure
              : RequestsStatus.ready,
          failure: result.failureOrNull,
        );
        return;
      }

      state = RequestsState(
        status: RequestsStatus.ready,
        requests: window.requests,
        truncated: window.truncated,
        loaded: true,
        skipped: window.skipped,
      );

      // The operator-facing half of the count, for the same reason the feed logs
      // its own: a screen can only say "some requests could not be shown" to the
      // person standing in front of it, and a mapper that is refusing documents
      // means the stored data has drifted from the rules. The line names the
      // number and never a document id, because these documents carry a patient's
      // name and phone number.
      if (window.skipped > 0) {
        _logger.warning(
          'Open-requests read skipped ${window.skipped} unreadable '
          'request document(s)',
        );
      }
    } finally {
      _fetching = false;
    }
  }
}

final NotifierProvider<RequestsController, RequestsState>
    requestsControllerProvider =
    NotifierProvider<RequestsController, RequestsState>(
      RequestsController.new,
    );

/// The open requests raised by the signed-in account.
///
/// A *projection*, not a second read. The [requestsControllerProvider] window
/// is shared with the all-requests screen and the dashboard preview; filtering
/// that list by [BloodRequest.userId] here means one paid Firestore read per
/// refresh covers every consumer, and "my requests" stays consistent with
/// "all requests" by construction (the two cannot disagree about what is
/// open, because they see the same snapshot).
///
/// **What this projection can miss, and why that is honest.** If the shared
/// window is truncated — [RequestsState.truncated] true because more open
/// requests exist than [RequestRepository.window] can hold — and one of the
/// ones that stayed behind is *mine*, this list is empty or short and the
/// reason is the window, not the filter. The My Requests screen surfaces
/// [RequestsState.truncated] with its own copy for exactly that reason, and
/// the fix (narrowing the query by userId at the database layer) is a
/// composite-index decision, which is a deployment step this stage does not
/// take.
///
/// [requestsAuthUidProvider] null means the app cannot answer "whose", which
/// is not the same as "nobody has any" — the screen reads the uid provider
/// directly and says so rather than showing an empty list.
final Provider<List<BloodRequest>> myOpenRequestsProvider =
    Provider<List<BloodRequest>>((Ref ref) {
  final RequestsState state = ref.watch(requestsControllerProvider);
  final String? uid = ref.watch(requestsAuthUidProvider);
  if (uid == null) {
    return const <BloodRequest>[];
  }
  return state.requests
      .where((BloodRequest r) => r.userId == uid)
      .toList(growable: false);
});
