import 'package:flutter/foundation.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/features/donors/domain/donor_query.dart';
import 'package:sholovvo_app/features/donors/domain/entities/donor.dart';

/// What the donor search is doing right now.
///
/// There is no `loadingMore`: the directory is read as a window and re-read when a
/// filter changes, so one spinner covers every read the screen can start — the same
/// four states the requests read uses.
enum DonorSearchStatus { initial, loading, ready, failure }

/// Everything the donor search screen draws, in one immutable value.
///
/// The list, [query], [truncated] and [skipped] travel together because they are one
/// answer to one question. On their own each can be read wrongly: a short list *looks*
/// like a small directory, and an empty list under a filter *looks* like "no donors
/// exist" when it means "no donors match this search". [query] is carried in the state
/// precisely so the empty state can tell those two apart and say the honest one.
@immutable
final class DonorSearchState {
  const DonorSearchState({
    this.status = DonorSearchStatus.initial,
    this.donors = const <Donor>[],
    this.query = DonorQuery.any,
    this.truncated = false,
    this.failure,
    this.loaded = false,
    this.skipped = 0,
  });

  final DonorSearchStatus status;

  /// Available first, then by name, as the repository ordered them.
  final List<Donor> donors;

  /// The query this window was read with. The filter bar reflects what has actually
  /// been searched, not what the widgets currently show, so a half-typed area that
  /// was never submitted does not make the empty state claim "no donors match" for a
  /// filter that is not in force.
  final DonorQuery query;

  /// Whether the window was full and at least one matching donor stayed behind it.
  final bool truncated;

  /// Why the last read failed, or `null`. Survives alongside the list on purpose: a
  /// refresh that fails should not throw away the donors on screen and should not
  /// pretend the failure did not happen either.
  final Failure? failure;

  /// Whether a read has ever resolved. Distinguishes "no donors match" (empty and
  /// loaded) from "nothing has been asked for" (empty and untouched).
  final bool loaded;

  /// How many documents inside the window could not be turned into a donor.
  final int skipped;

  bool get isEmpty => donors.isEmpty;

  /// The list of search refinements currently in force — a group, an area, or a
  /// "show unavailable too" widening. Drives the empty-state copy: an empty *filtered*
  /// search says "nobody matches", an empty *unfiltered* one says the consented
  /// directory is empty. Different sentences, and only one of them should nudge the
  /// person to change the filters.
  bool get hasActiveFilters => !query.normalised().isDefault;

  /// A first load or retry with nothing on screen — the one case that earns a
  /// full-height spinner.
  bool get isInitialLoading =>
      donors.isEmpty &&
      (status == DonorSearchStatus.loading ||
          status == DonorSearchStatus.initial);

  /// Nothing to show, nothing pending, the window was not full, and nothing was
  /// refused: the honest empty state. Every term is load-bearing for the same reason
  /// `RequestsState.isEmptyResult`'s are.
  bool get isEmptyResult =>
      donors.isEmpty &&
      loaded &&
      !truncated &&
      skipped == 0 &&
      status != DonorSearchStatus.loading;

  /// Nothing to show, and the directory is *not* empty as far as this read can tell:
  /// documents stayed behind the window, or the ones it looked at could not be read.
  bool get isUnreadableResult =>
      donors.isEmpty &&
      loaded &&
      (truncated || skipped > 0) &&
      status != DonorSearchStatus.loading;

  /// An error with nothing behind it, so the screen says so in place of the list.
  bool get isFatalError =>
      donors.isEmpty &&
      status == DonorSearchStatus.failure &&
      failure != null;

  DonorSearchState copyWith({
    DonorSearchStatus? status,
    List<Donor>? donors,
    DonorQuery? query,
    bool? truncated,
    Failure? failure,
    bool clearFailure = false,
    bool? loaded,
    int? skipped,
  }) {
    return DonorSearchState(
      status: status ?? this.status,
      donors: donors ?? this.donors,
      query: query ?? this.query,
      truncated: truncated ?? this.truncated,
      failure: clearFailure ? null : failure ?? this.failure,
      loaded: loaded ?? this.loaded,
      skipped: skipped ?? this.skipped,
    );
  }

  @override
  String toString() =>
      'DonorSearchState($status, ${donors.length} donors, '
      'truncated: $truncated, skipped: $skipped)';
}
