import 'package:flutter/foundation.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';

/// The open requests one read returned, and how much of the collection it saw.
///
/// **This is a window, not a page.** There is no cursor in it and no "load
/// more", on purpose: the query that fills it has no sort field it can trust
/// (see [BloodRequest.neededBy] for why `requiredDateTime` cannot order a
/// Firestore query against this data), and a cursor needs an order to continue.
/// Asking for a page after an unordered window would be asking Firestore for
/// "whatever comes next in document-id order", which is a position nobody chose.
///
/// So [truncated] carries the honest version of the question paging usually
/// answers. Because the repository asks for one document more than it keeps,
/// `false` means this list is every open request the collection has, and `true`
/// means it is not — the two are never guessed at.
///
/// [skipped] counts the documents inside the window that the mapper refused.
/// A short list without that number is a list that claims the community is quiet
/// when the app could not read what is there; the feed learned this the hard way
/// and the same discipline applies here.
@immutable
final class OpenRequests {
  /// Not `const`, for the same reason `FeedPage` is not: the list is wrapped in
  /// [List.unmodifiable] here, so the constructor body has work to do.
  OpenRequests({
    required List<BloodRequest> requests,
    this.truncated = false,
    this.skipped = 0,
  }) : requests = List<BloodRequest>.unmodifiable(requests);

  /// Soonest needed first, with the undated ones after, in the order the read
  /// returned them. See `orderRequests`.
  final List<BloodRequest> requests;

  /// Whether the window filled up and there is at least one more open request
  /// behind it that this read did not look at.
  final bool truncated;

  /// How many documents the read returned that could not be turned into a
  /// request.
  final int skipped;

  bool get isEmpty => requests.isEmpty;

  @override
  String toString() =>
      'OpenRequests(${requests.length} requests, truncated: $truncated, '
      'skipped: $skipped)';
}
