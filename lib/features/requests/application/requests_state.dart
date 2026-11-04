import 'package:flutter/foundation.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';

/// What the open-requests read is doing right now.
///
/// There is no `loadingMore`: this window is read whole and re-read on refresh
/// (`OpenRequests` explains why it is not paged), so one spinner covers every
/// load the screen can start.
enum RequestsStatus { initial, loading, ready, failure }

/// Everything the requests screen and the dashboard's nearby section draw, in one
/// immutable value.
///
/// The list, [truncated] and [skipped] travel together because they are one
/// answer. On their own each is a claim that can be wrong: a short list *looks*
/// like a quiet collection, and a window that filled up *looks* like a long one.
/// Read together they are the only set of statements the screen is allowed to make
/// about `blood_requests`, which matters more here than in the feed — a donor who
/// believes there is no open request in their group stops looking.
@immutable
final class RequestsState {
  const RequestsState({
    this.status = RequestsStatus.initial,
    this.requests = const <BloodRequest>[],
    this.truncated = false,
    this.failure,
    this.loaded = false,
    this.skipped = 0,
  });

  final RequestsStatus status;

  /// Soonest needed first, as the repository ordered them.
  final List<BloodRequest> requests;

  /// Whether the window was full and at least one open request stayed behind it.
  final bool truncated;

  /// Why the last read failed, or `null`.
  ///
  /// It survives alongside the list on purpose: a refresh that fails should not
  /// throw away the requests the donor is reading, and should not pretend the
  /// failure did not happen either. The screen shows the list *and* a banner.
  final Failure? failure;

  /// Whether a read has ever resolved. Distinguishes "no open requests" (empty and
  /// loaded) from "nothing has been asked for" (empty and untouched), which are the
  /// same list but different sentences.
  final bool loaded;

  /// How many documents inside the window could not be turned into a request.
  final int skipped;

  bool get isEmpty => requests.isEmpty;

  /// A first load or retry with nothing on screen — the one case that earns a
  /// full-height spinner.
  bool get isInitialLoading =>
      requests.isEmpty &&
      (status == RequestsStatus.loading || status == RequestsStatus.initial);

  /// Nothing to show, nothing pending, the window was not full, and nothing was
  /// refused: the honest empty state.
  ///
  /// All four terms are load-bearing. `!truncated` says there was nothing behind
  /// the window; `skipped == 0` says the window was not *full of documents this
  /// app could not read*. Without the second one, a collection of three open
  /// requests written in a shape the mapper refuses would be reported to the donor
  /// as a collection with none — the same false "nobody needs blood" that the feed
  /// had to grow [isUnreadableResult] to avoid.
  bool get isEmptyResult =>
      requests.isEmpty &&
      loaded &&
      !truncated &&
      skipped == 0 &&
      status != RequestsStatus.loading;

  /// Nothing to show, and the collection is *not* empty as far as this read can
  /// tell: documents stayed behind the window, or the ones it did look at could
  /// not be read.
  ///
  /// The mirror image of [isEmptyResult], and the reason both exist: "no open
  /// requests" is a fact about the community, and "this app could not read the
  /// ones that are there" is a fact about the app. They are one empty list apart
  /// and completely different claims.
  bool get isUnreadableResult =>
      requests.isEmpty &&
      loaded &&
      (truncated || skipped > 0) &&
      status != RequestsStatus.loading;

  /// An error with nothing behind it, so the screen has to say so in place of the
  /// list rather than above it.
  bool get isFatalError =>
      requests.isEmpty && status == RequestsStatus.failure && failure != null;

  RequestsState copyWith({
    RequestsStatus? status,
    List<BloodRequest>? requests,
    bool? truncated,
    Failure? failure,
    bool clearFailure = false,
    bool? loaded,
    int? skipped,
  }) {
    return RequestsState(
      status: status ?? this.status,
      requests: requests ?? this.requests,
      truncated: truncated ?? this.truncated,
      failure: clearFailure ? null : (failure ?? this.failure),
      loaded: loaded ?? this.loaded,
      skipped: skipped ?? this.skipped,
    );
  }

  @override
  String toString() =>
      'RequestsState($status, ${requests.length} requests, '
      'truncated: $truncated, skipped: $skipped)';
}
