import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';

/// The order a donor is shown open requests in: soonest needed first.
///
/// **Why the sort happens here rather than in the query.** Firestore can only
/// order a collection by a field whose values are all of one type, and
/// `requiredDateTime` in `blood_requests` is free text — the create rule requires
/// the key and constrains nothing about it, and the project's own rules-test seed
/// stores `'2026-11-10 10:00 AM'`. `DateTime.now()` as a query bound against
/// string-valued documents matches nothing, because Firestore orders by type
/// before value: a screen built on that query would print "no open requests" over
/// a collection full of them. Sorting the window here is the version that cannot
/// lie, and it is exact for what was read.
///
/// **A request whose date is in the past sorts first, not last.** That is what
/// "soonest needed" means, and it is deliberately not filtered out: this app did
/// not raise the request and cannot decide it is stale. The row shows the date, so
/// the donor is the one who sees it is overdue.
///
/// **Undated requests go after the dated ones**, in the order the read returned
/// them. They are not dropped and not interleaved on a guess: a request nobody
/// could put a date on is still a request, and inventing a position for it among
/// the dated ones would be inventing a date.
int compareByUrgency(BloodRequest a, BloodRequest b) {
  final DateTime? left = a.neededBy;
  final DateTime? right = b.neededBy;

  if (left != null && right != null) {
    return left.compareTo(right);
  }
  if (left != null) {
    return -1;
  }
  if (right != null) {
    return 1;
  }
  return 0;
}

/// [compareByUrgency] made stable and total.
///
/// `List.sort` is not stable in Dart, so two requests the comparator calls equal
/// — every undated pair, and any two documents with the same instant — would come
/// out in an order that can change between rebuilds. The read order is therefore
/// carried in as a tiebreak, which makes the result a total order over the window
/// and the list repaintable: the same documents in, the same list out, so a
/// donor's thumb does not land on a different request after a refresh.
///
/// Returns a new list; the input is not touched, because the repository hands the
/// caller an unmodifiable one.
List<BloodRequest> orderRequests(List<BloodRequest> requests) {
  final List<_Indexed> decorated = <_Indexed>[
    for (int index = 0; index < requests.length; index++)
      _Indexed(requests[index], index),
  ];

  decorated.sort((_Indexed a, _Indexed b) {
    final int byUrgency = compareByUrgency(a.request, b.request);
    return byUrgency != 0 ? byUrgency : a.index.compareTo(b.index);
  });

  return <BloodRequest>[
    for (final _Indexed entry in decorated) entry.request,
  ];
}

final class _Indexed {
  const _Indexed(this.request, this.index);

  final BloodRequest request;
  final int index;
}
