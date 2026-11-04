import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/logging/app_logger.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/requests/application/requests_state.dart';
import 'package:sholovvo_app/features/requests/data/firestore_request_documents.dart';
import 'package:sholovvo_app/features/requests/data/firestore_request_repository.dart';
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
