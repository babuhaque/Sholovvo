import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/features/donors/domain/donor_ordering.dart';
import 'package:sholovvo_app/features/donors/domain/entities/donor.dart';

import '../../support/fake_donors.dart';

List<String> _ids(List<Donor> donors) =>
    donors.map((Donor donor) => donor.uid).toList();

void main() {
  group('compareDonors', () {
    test('puts an available donor before one who is not', () {
      final Donor available = fakeDonor(uid: 'a', isAvailable: true);
      final Donor notAvailable = fakeDonor(uid: 'b', isAvailable: false);

      expect(compareDonors(available, notAvailable), lessThan(0));
      expect(compareDonors(notAvailable, available), greaterThan(0));
    });

    test('within the same availability, orders by name', () {
      final Donor alice = fakeDonor(uid: 'a', displayName: 'Alice');
      final Donor bob = fakeDonor(uid: 'b', displayName: 'Bob');

      expect(compareDonors(alice, bob), lessThan(0));
    });

    test('is case-insensitive on the name', () {
      final Donor lower = fakeDonor(uid: 'a', displayName: 'ayesha');
      final Donor upper = fakeDonor(uid: 'b', displayName: 'Bilal');

      expect(compareDonors(lower, upper), lessThan(0));
    });

    test('sorts a blank display name last, not first', () {
      // A donor who has not named themselves is not more important for being blank,
      // and a blank line at the head of a directory reads as a bug.
      final Donor blank = fakeDonor(uid: 'a', displayName: '');
      final Donor named = fakeDonor(uid: 'b', displayName: 'Zara');

      expect(compareDonors(blank, named), greaterThan(0));
    });

    test('an available donor still outranks a named unavailable one', () {
      // Availability is the primary key: someone in a hurry sees who is offering now
      // before anyone, whatever the alphabetical order of the names.
      final Donor available = fakeDonor(
        uid: 'a',
        displayName: 'Zara',
        isAvailable: true,
      );
      final Donor unavailable = fakeDonor(
        uid: 'b',
        displayName: 'Alice',
        isAvailable: false,
      );

      expect(compareDonors(available, unavailable), lessThan(0));
    });
  });

  group('orderDonors', () {
    test('returns a new list and leaves the input untouched', () {
      final List<Donor> input = <Donor>[
        fakeDonor(uid: 'z', displayName: 'Zara', isAvailable: true),
        fakeDonor(uid: 'a', displayName: 'Alice', isAvailable: true),
      ];
      final List<String> before = _ids(input);

      final List<Donor> ordered = orderDonors(input);

      expect(_ids(ordered), <String>['a', 'z']);
      expect(_ids(input), before, reason: 'the caller keeps its own order');
    });

    test('is stable: same-name donors keep their read order', () {
      // List.sort is not stable in Dart, so two donors the comparator calls equal
      // would otherwise land in an order that can shift between rebuilds.
      final List<Donor> input = <Donor>[
        fakeDonor(uid: 'first', displayName: 'Same Name'),
        fakeDonor(uid: 'second', displayName: 'Same Name'),
        fakeDonor(uid: 'third', displayName: 'Same Name'),
      ];

      final List<Donor> ordered = orderDonors(input);

      expect(_ids(ordered), <String>['first', 'second', 'third']);
    });

    test('groups all available before all unavailable, each by name', () {
      final List<Donor> input = <Donor>[
        fakeDonor(uid: 'ua', displayName: 'Alice', isAvailable: false),
        fakeDonor(uid: 'ab', displayName: 'Bob', isAvailable: true),
        fakeDonor(uid: 'uz', displayName: 'Zara', isAvailable: false),
        fakeDonor(uid: 'aa', displayName: 'Amir', isAvailable: true),
      ];

      final List<Donor> ordered = orderDonors(input);

      expect(_ids(ordered), <String>['aa', 'ab', 'ua', 'uz']);
    });

    test('an empty input orders to an empty list', () {
      expect(orderDonors(<Donor>[]), isEmpty);
    });
  });
}
