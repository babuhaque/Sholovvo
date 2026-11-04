import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/requests/data/firestore_request_repository.dart';
import 'package:sholovvo_app/features/requests/data/request_documents.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';
import 'package:sholovvo_app/features/requests/domain/open_requests.dart';
import 'package:sholovvo_app/features/requests/domain/request_repository.dart';

import '../../support/fake_requests.dart';

/// `count` readable documents, ids `r1` … `rn`, the first the latest and the last
/// the soonest: the read order is the reverse of urgency, so a window that came
/// back unsorted is visible in the ids alone.
List<RequestDocument> _documents(int count) {
  final DateTime soonest = DateTime.utc(2026, 11, 10, 10);
  return <RequestDocument>[
    for (int index = 1; index <= count; index++)
      requestDocument(
        'r$index',
        fields: requestFields(
          hospitalName: 'Hospital $index',
          requiredDateTime: _requiredText(
            soonest.add(Duration(days: count - index)),
          ),
        ),
      ),
  ];
}

/// The shape the rules-test seed writes: a date, a space, a clock time, a marker.
/// Built from a real [DateTime] rather than spelled out, because a window of
/// twenty-five documents one day apart runs past the end of the month, and
/// `2026-11-34` is a date the mapper refuses on purpose.
String _requiredText(DateTime when) {
  final DateTime utc = when.toUtc();
  return '${utc.year.toString().padLeft(4, '0')}-'
      '${utc.month.toString().padLeft(2, '0')}-'
      '${utc.day.toString().padLeft(2, '0')} 10:00 AM';
}

/// A document the mapper refuses: a ninth blood-group spelling.
RequestDocument _unreadable(String id) {
  return requestDocument(id, fields: requestFields(bloodGroup: 'O -'));
}

/// The repository under the fake database, plus the fake itself.
({FirestoreRequestRepository repository, FakeRequestDocuments documents})
_build(List<RequestDocument> documents) {
  final FakeRequestDocuments fake = FakeRequestDocuments(documents);
  return (repository: FirestoreRequestRepository(fake), documents: fake);
}

OpenRequests _window(Result<OpenRequests> result) {
  final OpenRequests? window = result.valueOrNull;
  expect(
    window,
    isNotNull,
    reason: 'expected a window, got ${result.failureOrNull}',
  );
  return window!;
}

List<String> _ids(List<BloodRequest> requests) =>
    requests.map((BloodRequest request) => request.id).toList();

void main() {
  group('FirestoreRequestRepository asks the database', () {
    test('for one document more than it keeps', () async {
      // The over-fetch-by-one is what makes `truncated` a measurement instead of a
      // guess, so the size of the ask is part of the contract, not an optimisation.
      final harness = _build(_documents(3));

      _window(await harness.repository.loadOpenRequests());

      expect(harness.documents.lastLimit, RequestRepository.window + 1);
      expect(harness.documents.calls, 1);
    });

    test('once per load, and never with a cursor', () async {
      // There is nothing to resume after: the read is a window. A second call is a
      // fresh ask for the same window, paid for twice.
      final harness = _build(_documents(2));

      _window(await harness.repository.loadOpenRequests());
      _window(await harness.repository.loadOpenRequests());

      expect(harness.documents.calls, 2);
      expect(harness.documents.lastLimit, RequestRepository.window + 1);
    });
  });

  group('FirestoreRequestRepository reports the window it read', () {
    test('maps every readable document, in the order it decided', () async {
      final harness = _build(<RequestDocument>[
        requestDocument(
          'late',
          fields: requestFields(
            bloodGroup: 'B+',
            bloodBags: 3,
            hospitalName: 'Sheikh Kamal',
            hospitalAddress: 'Mirpur',
            requiredDateTime: _requiredText(DateTime.utc(2026, 11, 20, 10)),
          ),
        ),
        requestDocument(
          'soon',
          fields: requestFields(
            requiredDateTime: _requiredText(DateTime.utc(2026, 11, 11, 10)),
          ),
        ),
      ]);

      final OpenRequests window = _window(
        await harness.repository.loadOpenRequests(),
      );

      expect(_ids(window.requests), <String>['soon', 'late']);
      final BloodRequest soonest = window.requests.first;
      expect(soonest.bloodGroup, 'A+');
      expect(soonest.hospitalName, 'Dhaka Medical College');
      expect(soonest.hospitalAddress, 'Dhaka');
      expect(window.truncated, isFalse);
      expect(window.skipped, 0);
    });

    test('says a short window is the whole collection', () async {
      final harness = _build(_documents(4));

      final OpenRequests window = _window(
        await harness.repository.loadOpenRequests(),
      );

      expect(window.requests, hasLength(4));
      // The sentence the screen draws from this: "these are all the open
      // requests", which it may only say when the extra document did not arrive.
      expect(window.truncated, isFalse);
    });

    test('says nothing stayed behind when the extra document arrives', () async {
      final List<RequestDocument> full = _documents(RequestRepository.window);
      full.add(requestDocument('behind', fields: requestFields()));
      final harness = _build(full);

      final OpenRequests window = _window(
        await harness.repository.loadOpenRequests(),
      );

      expect(window.truncated, isTrue);
      expect(window.requests, hasLength(RequestRepository.window));
      expect(_ids(window.requests).contains('behind'), isFalse);
    });

    test('does not claim requests that are not there', () async {
      // A collection of exactly the window size is the case the over-fetch exists
      // for: the read kept all twenty-five and looked at none more, so a notice
      // about requests "still behind them" would be a fiction.
      final harness = _build(_documents(RequestRepository.window));

      final OpenRequests window = _window(
        await harness.repository.loadOpenRequests(),
      );

      expect(window.requests, hasLength(RequestRepository.window));
      expect(window.truncated, isFalse);
    });

    test('answers an empty collection with an empty, honest window', () async {
      final harness = _build(<RequestDocument>[]);

      final OpenRequests window = _window(
        await harness.repository.loadOpenRequests(),
      );

      expect(window.requests, isEmpty);
      expect(window.isEmpty, isTrue);
      expect(window.truncated, isFalse);
      expect(window.skipped, 0);
    });

    test('hands back a list nobody can sort in place', () async {
      // The controller keeps this list in its state and the dashboard shows the
      // head of it; a caller reordering it would rewrite both.
      final harness = _build(_documents(2));

      final OpenRequests window = _window(
        await harness.repository.loadOpenRequests(),
      );

      expect(
        () => window.requests.add(fakeRequest()),
        throwsUnsupportedError,
      );
    });
  });

  group('FirestoreRequestRepository counts what it could not read', () {
    test('refuses a malformed document and counts it', () async {
      final harness = _build(<RequestDocument>[
        _unreadable('bad-1'),
        requestDocument('good-1'),
      ]);

      final OpenRequests window = _window(
        await harness.repository.loadOpenRequests(),
      );

      expect(window.skipped, 1);
      expect(_ids(window.requests), <String>['good-1']);
    });

    test('lets one bad document keep the good ones around it', () async {
      // The reason this is refuse-and-count rather than refuse-the-window: a
      // single stray spelling must not cost a donor the twenty-four real requests
      // written around it.
      final List<RequestDocument> mixed = _documents(RequestRepository.window);
      mixed.insert(0, _unreadable('bad'));
      final harness = _build(mixed);

      final OpenRequests window = _window(
        await harness.repository.loadOpenRequests(),
      );

      expect(window.requests, hasLength(RequestRepository.window - 1));
      expect(window.skipped, 1);
      expect(window.truncated, isTrue, reason: 'the extra document was read');
    });

    test('counts only the documents it looked at', () async {
      // The extra document decides whether the window filled up and is then
      // dropped. Counting it as skipped would tell the donor the app could not
      // read something it never tried to.
      final List<RequestDocument> full = _documents(RequestRepository.window);
      full.add(_unreadable('behind'));
      final harness = _build(full);

      final OpenRequests window = _window(
        await harness.repository.loadOpenRequests(),
      );

      expect(window.skipped, 0);
      expect(window.truncated, isTrue);
      expect(window.requests, hasLength(RequestRepository.window));
    });

    test('keeps a request whose date it could not read', () async {
      // An unparseable `requiredDateTime` is the mapper's most common real-world
      // refusal and is deliberately not one: the text is what the person wrote, and
      // the request is still a request. It sorts after the dated ones.
      final harness = _build(<RequestDocument>[
        requestDocument(
          'typed',
          fields: requestFields(requiredDateTime: 'শুক্রবার'),
        ),
        requestDocument(
          'dated',
          fields: requestFields(
            requiredDateTime: _requiredText(DateTime.utc(2026, 11, 11, 10)),
          ),
        ),
      ]);

      final OpenRequests window = _window(
        await harness.repository.loadOpenRequests(),
      );

      expect(window.skipped, 0);
      expect(_ids(window.requests), <String>['dated', 'typed']);
      final BloodRequest typed = window.requests.last;
      expect(typed.neededBy, isNull);
      expect(typed.neededByText, 'শুক্রবার');
    });

    test('reports a window of nothing but refusals as unreadable, not empty', () async {
      // The distinction the whole skip count exists for: an empty list that came
      // from refused documents must not be able to be read as a quiet community.
      final harness = _build(
        <RequestDocument>[_unreadable('bad-1'), _unreadable('bad-2')],
      );

      final OpenRequests window = _window(
        await harness.repository.loadOpenRequests(),
      );

      expect(window.requests, isEmpty);
      expect(window.isEmpty, isTrue);
      expect(window.skipped, 2);
      expect(window.truncated, isFalse);
    });
  });

  group('FirestoreRequestRepository when the read fails', () {
    test('passes the failure through and invents no window', () async {
      const NetworkFailure failure = NetworkFailure();
      final harness = _build(_documents(3));
      harness.documents.failure = failure;

      final Result<OpenRequests> result = await harness.repository
          .loadOpenRequests();

      expect(result.valueOrNull, isNull);
      expect(
        result.failureOrNull,
        same(failure),
        reason: 'the same failure, not a new one',
      );
    });

    test('names no request and no hospital in its own summary', () async {
      // `OpenRequests.toString` ends up in log lines and in test failure output,
      // and these documents carry a patient's name, a phone number and an address.
      final harness = _build(_documents(2));

      final String printed = _window(
        await harness.repository.loadOpenRequests(),
      ).toString();

      expect(printed.contains('Patient'), isFalse, reason: printed);
      expect(printed.contains('Hospital'), isFalse, reason: printed);
      expect(printed.contains('+8801700000000'), isFalse, reason: printed);
    });
  });
}
