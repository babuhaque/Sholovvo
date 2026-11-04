import 'package:sholovvo_app/features/donors/domain/entities/donor.dart';

/// The order a donor is listed in: available first, then by name.
///
/// **Why the sort happens here rather than in the query.** Ordering the `users`
/// collection by display name would need a composite index (equality on `role`
/// plus an `orderBy` on `displayName`), and creating an index means deploying
/// configuration the owner has to approve — so the read stays a bounded window and
/// the ordering is done on the decoded list, exactly as `orderRequests` does for
/// `blood_requests`. It is also the order the screen actually wants: someone in a
/// hurry should see the donors who are offering blood now before the ones marked
/// unavailable, which a name sort alone would not give them.
///
/// **An empty display name sorts last, not first.** A donor who has not named
/// themselves yet is not more important for being blank, and a blank line at the
/// head of a directory reads as a bug rather than as a real profile.
int compareDonors(Donor a, Donor b) {
  if (a.isAvailable != b.isAvailable) {
    return a.isAvailable ? -1 : 1;
  }
  return _byName(a.displayName, b.displayName);
}

int _byName(String left, String right) {
  final String a = left.trim();
  final String b = right.trim();
  if (a.isEmpty && b.isEmpty) {
    return 0;
  }
  if (a.isEmpty) {
    return 1;
  }
  if (b.isEmpty) {
    return -1;
  }
  return a.toLowerCase().compareTo(b.toLowerCase());
}

/// [compareDonors] made stable and total.
///
/// `List.sort` is not stable in Dart, so two donors the comparator calls equal —
/// every same-name pair — would come out in an order that can shift between
/// rebuilds. The read order is carried in as a tiebreak, so the same documents
/// produce the same list every time and a thumb does not land on a different donor
/// after a refresh.
///
/// Returns a new list; the input is not touched, because the repository hands the
/// caller an unmodifiable one.
List<Donor> orderDonors(List<Donor> donors) {
  final List<_Indexed> decorated = <_Indexed>[
    for (int index = 0; index < donors.length; index++)
      _Indexed(donors[index], index),
  ];

  decorated.sort((_Indexed a, _Indexed b) {
    final int byComparator = compareDonors(a.donor, b.donor);
    return byComparator != 0 ? byComparator : a.index.compareTo(b.index);
  });

  return <Donor>[
    for (final _Indexed entry in decorated) entry.donor,
  ];
}

final class _Indexed {
  const _Indexed(this.donor, this.index);

  final Donor donor;
  final int index;
}
