import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';
import 'package:sholovvo_app/features/requests/domain/request_ordering.dart';
import 'package:sholovvo_app/features/requests/domain/request_repository.dart';

import '../../support/fake_requests.dart';

/// A dated request, [days] after the seed instant, so the arithmetic in the
/// expectations below is about order rather than about the clock. The id carries
/// the offset, which makes an ordering assertion readable as a list of ids.
BloodRequest _on(int days, {String id = 'req'}) {
  final DateTime neededBy = DateTime.utc(2026, 11, 10, 10).add(
    Duration(days: days),
  );
  return fakeRequest(id: '$id-$days', neededBy: neededBy);
}

/// An undated request that carries only the text nobody could parse.
BloodRequest _undated(String id, {String text = 'শুক্রবার'}) {
  return fakeRequest(id: id, neededByText: text);
}

List<String> _ids(List<BloodRequest> requests) =>
    requests.map((BloodRequest request) => request.id).toList();

void main() {
  group('compareByUrgency', () {
    test('puts the earlier instant first, in both directions', () {
      final BloodRequest soon = _on(0, id: 'soon');
      final BloodRequest later = _on(2, id: 'later');

      expect(compareByUrgency(soon, later), isNegative);
      expect(compareByUrgency(later, soon), isPositive);
      expect(compareByUrgency(soon, _on(0, id: 'twin')), isZero);
    });

    test('says a dated request is more urgent than an undated one', () {
      // Not "less" and not equal: a request somebody could put a time on is the
      // one a donor can act on, and the comparator is what decides that.
      final BloodRequest dated = _on(5);
      final BloodRequest unknown = _undated('undated');

      expect(compareByUrgency(dated, unknown), -1);
      expect(compareByUrgency(unknown, dated), 1);
    });

    test('calls two undated requests equal, because it has no basis not to', () {
      // The tie is broken by read order in `orderRequests`, not here — inventing a
      // preference between two requests with no date would be inventing a date.
      expect(
        compareByUrgency(_undated('a'), _undated('b', text: 'আগামীকাল')),
        isZero,
      );
    });

    test('treats text as no date, since text cannot be ordered', () {
      // The mapper keeps verbatim text precisely because it could not read a date
      // out of it. A row that shows "শুক্রবার" has no position in time this list
      // can rank it by.
      expect(
        compareByUrgency(_on(0), _undated('undated')).isNegative,
        isTrue,
      );
    });
  });

  group('orderRequests', () {
    test('sorts a mixed window soonest needed first', () {
      final List<BloodRequest> ordered = orderRequests(<BloodRequest>[
        _on(3, id: 'c'),
        _on(1, id: 'a'),
        _on(2, id: 'b'),
      ]);

      expect(_ids(ordered), <String>['a-1', 'b-2', 'c-3']);
    });

    test('leaves a request whose date has passed at the front', () {
      // A request overdue is the most urgent thing on the list, not the least.
      // This app did not raise it and cannot decide it is stale; the row shows the
      // date, so the donor is the one who sees it is overdue.
      final List<BloodRequest> ordered = orderRequests(<BloodRequest>[
        _on(1, id: 'tomorrow'),
        _on(-2, id: 'three-days-ago'),
        _on(0, id: 'today'),
      ]);

      expect(_ids(ordered), <String>[
        'three-days-ago--2',
        'today-0',
        'tomorrow-1',
      ]);
    });

    test('puts every undated request after every dated one', () {
      final List<BloodRequest> ordered = orderRequests(<BloodRequest>[
        _undated('quiet-a'),
        _on(9, id: 'far'),
        _undated('quiet-b'),
        _on(1, id: 'near'),
      ]);

      expect(_ids(ordered), <String>[
        'near-1',
        'far-9',
        'quiet-a',
        'quiet-b',
      ]);
    });

    test('keeps the read order among the undated ones', () {
      // Dart's `List.sort` is not stable, so without the index tiebreak this
      // assertion could pass today and fail after a Dart SDK change — and on screen
      // it would mean a donor's thumb landing on a different request after a
      // refresh.
      final List<BloodRequest> ordered = orderRequests(<BloodRequest>[
        _undated('first'),
        _undated('second'),
        _undated('third'),
      ]);

      expect(_ids(ordered), <String>['first', 'second', 'third']);
    });

    test('keeps the read order among requests sharing one instant', () {
      final DateTime same = DateTime.utc(2026, 11, 10, 10);
      final List<BloodRequest> ordered = orderRequests(<BloodRequest>[
        fakeRequest(id: 'x', neededBy: same),
        fakeRequest(id: 'y', neededBy: same),
        fakeRequest(id: 'z', neededBy: same),
      ]);

      expect(_ids(ordered), <String>['x', 'y', 'z']);
    });

    test('is a total order, so the same documents in give the same list out', () {
      final List<BloodRequest> window = <BloodRequest>[
        _undated('u-1'),
        _on(4, id: 'd'),
        _on(-1, id: 'p'),
        _undated('u-2'),
        _on(4, id: 'd-twin'),
      ];

      expect(orderRequests(orderRequests(window)), orderRequests(window));
      expect(_ids(orderRequests(window)), <String>[
        'p--1',
        'd-4',
        'd-twin-4',
        'u-1',
        'u-2',
      ]);
    });

    test('does not touch the list it was given', () {
      // The repository hands the caller an unmodifiable window, and the controller
      // keeps that list alive in its own state — sorting in place would rewrite the
      // requests on screen from inside a comparison.
      final List<BloodRequest> window = <BloodRequest>[
        _on(2, id: 'b'),
        _on(1, id: 'a'),
      ];
      final List<String> before = _ids(window);

      final List<BloodRequest> ordered = orderRequests(window);

      expect(_ids(window), before);
      expect(_ids(ordered), <String>['a-1', 'b-2']);
      expect(ordered, isNot(same(window)));
    });

    test('answers an empty window with an empty list', () {
      expect(orderRequests(<BloodRequest>[]), isEmpty);
    });

    test('orders a full window without losing or duplicating a request', () {
      // Twenty-five is the repository's ceiling, so this is the largest the sort
      // ever has to be right. The input is in reverse urgency, which is the shape a
      // sort most often gets wrong: nothing is already in place to anchor it.
      final List<BloodRequest> window = <BloodRequest>[
        for (int index = 0; index < RequestRepository.window; index++)
          _on(RequestRepository.window - 1 - index, id: 'w$index'),
      ];

      final List<BloodRequest> ordered = orderRequests(window);

      expect(ordered, hasLength(RequestRepository.window));
      expect(_ids(ordered).toSet(), hasLength(RequestRepository.window));
      for (int index = 1; index < ordered.length; index++) {
        expect(
          compareByUrgency(ordered[index - 1], ordered[index]).sign,
          lessThanOrEqualTo(0),
          reason: 'index $index is out of order in ${_ids(ordered)}',
        );
      }
      // Reversed all the way in means the last document read is the first shown.
      expect(_ids(ordered).first, 'w${RequestRepository.window - 1}-0');
      expect(_ids(ordered).last, 'w0-${RequestRepository.window - 1}');
    });
  });
}
