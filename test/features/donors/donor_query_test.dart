import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/features/donors/domain/donor_query.dart';

void main() {
  group('DonorQuery defaults', () {
    test('opens asking for available donors, any group, any area', () {
      const DonorQuery query = DonorQuery.any;

      expect(query.bloodGroup, isNull);
      expect(query.area, isNull);
      expect(query.availableOnly, isTrue);
      expect(query.isDefault, isTrue);
    });
  });

  group('DonorQuery.normalised', () {
    test('drops a blood group that is not one of the eight', () {
      // A free-text ninth spelling is a typo, not a search; firing it would return
      // nothing and the screen would report "nobody matches" for a query that could
      // never have matched. Dropping to null keeps the search honest.
      const DonorQuery query = DonorQuery(bloodGroup: 'B+ ');

      expect(query.normalised().bloodGroup, 'B+');

      const DonorQuery stray = DonorQuery(bloodGroup: 'Z+');
      expect(stray.normalised().bloodGroup, isNull);
    });

    test('collapses a blank area to null but keeps a real one, trimmed', () {
      const DonorQuery blank = DonorQuery(area: '   ');
      expect(blank.normalised().area, isNull);

      const DonorQuery spaced = DonorQuery(area: '  Mirpur  ');
      expect(spaced.normalised().area, 'Mirpur');
    });

    test('is idempotent', () {
      const DonorQuery query = DonorQuery(
        bloodGroup: 'A+',
        area: 'Dhanmondi',
        availableOnly: false,
      );

      final DonorQuery once = query.normalised();
      final DonorQuery twice = once.normalised();

      expect(twice, once);
    });

    test('preserves the availability switch untouched', () {
      const DonorQuery widened = DonorQuery(availableOnly: false);

      expect(widened.normalised().availableOnly, isFalse);
    });
  });

  group('DonorQuery.isDefault', () {
    test('a group narrows it', () {
      expect(const DonorQuery(bloodGroup: 'A+').isDefault, isFalse);
    });

    test('an area narrows it', () {
      expect(const DonorQuery(area: 'Dhanmondi').isDefault, isFalse);
    });

    test('the widening alone still counts as the default question', () {
      // availableOnly is a switch, not a narrowing of *who exists*; the empty state
      // reads isDefault to choose between "nobody matches your filters" and the
      // quieter truth that the directory is genuinely empty.
      expect(const DonorQuery(availableOnly: false).isDefault, isTrue);
    });
  });

  group('DonorQuery.copyWith', () {
    test('sets a group and clears it', () {
      const DonorQuery start = DonorQuery.any;

      final DonorQuery withGroup = start.copyWith(bloodGroup: 'O-');
      expect(withGroup.bloodGroup, 'O-');

      final DonorQuery cleared = withGroup.copyWith(clearBloodGroup: true);
      expect(cleared.bloodGroup, isNull);
    });

    test('clears the area', () {
      const DonorQuery start = DonorQuery(area: 'Mirpur');

      expect(start.copyWith(clearArea: true).area, isNull);
    });

    test('leaves untouched fields in place', () {
      const DonorQuery start = DonorQuery(
        bloodGroup: 'A+',
        area: 'Uttra',
        availableOnly: false,
      );

      final DonorQuery flipped = start.copyWith(availableOnly: true);
      expect(flipped.bloodGroup, 'A+');
      expect(flipped.area, 'Uttra');
      expect(flipped.availableOnly, isTrue);
    });
  });

  group('DonorQuery equality', () {
    test('two queries asking the same question compare equal', () {
      const DonorQuery a = DonorQuery(bloodGroup: 'A+', area: 'Mirpur');
      const DonorQuery b = DonorQuery(bloodGroup: 'A+', area: 'Mirpur');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a changed filter is a different question', () {
      const DonorQuery a = DonorQuery(bloodGroup: 'A+');
      const DonorQuery b = DonorQuery(bloodGroup: 'B+');

      expect(a, isNot(b));
    });

    test('its summary names what is being asked, including any area', () {
      // The query is the searcher's own filter, not another person's data, so the
      // area is theirs to name back; the point is a readable debug line.
      const DonorQuery query = DonorQuery(bloodGroup: 'A+', area: 'Dhanmondi');

      expect(query.toString(), contains('A+'));
      expect(query.toString(), contains('Dhanmondi'));

      const DonorQuery any = DonorQuery.any;
      expect(any.toString(), contains('any'));
    });
  });
}
