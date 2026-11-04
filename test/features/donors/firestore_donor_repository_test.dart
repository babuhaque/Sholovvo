import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/donors/data/donor_documents.dart';
import 'package:sholovvo_app/features/donors/data/firestore_donor_repository.dart';
import 'package:sholovvo_app/features/donors/domain/discovered_donors.dart';
import 'package:sholovvo_app/features/donors/domain/donor_query.dart';
import 'package:sholovvo_app/features/donors/domain/donor_repository.dart';
import 'package:sholovvo_app/features/donors/domain/entities/donor.dart';

import '../../support/fake_donors.dart';

/// `count` readable donor documents, ids `d1` … `dn`, alternating availability so a
/// window that came back un-ordered is visible in the ids alone.
List<DonorDocument> _documents(int count) {
  return <DonorDocument>[
    for (int index = 1; index <= count; index++)
      donorDocument(
        'd$index',
        fields: donorFields(
          displayName: 'Donor $index',
          isAvailable: index.isOdd,
        ),
      ),
  ];
}

/// A document the mapper refuses: a role that is not `donor`.
DonorDocument _unreadable(String id) {
  return donorDocument(id, fields: donorFields(role: 'recipient'));
}

/// A Stage 9.5 consent refusal: a real donor whose `allowDonorDiscovery` is
/// explicitly off. The live Firestore query filters these out at the database
/// (see `FirestoreDonorDocuments.fetch`), so a well-behaved read never returns
/// one, but the mapper still refuses them and the repository still counts them.
DonorDocument _notDiscoverable(String id) {
  return donorDocument(id, fields: donorFields(allowDonorDiscovery: false));
}

({FirestoreDonorRepository repository, FakeDonorDocuments documents}) _build(
  List<DonorDocument> documents,
) {
  final FakeDonorDocuments fake = FakeDonorDocuments(documents);
  return (repository: FirestoreDonorRepository(fake), documents: fake);
}

DiscoveredDonors _window(Result<DiscoveredDonors> result) {
  final DiscoveredDonors? window = result.valueOrNull;
  expect(
    window,
    isNotNull,
    reason: 'expected a window, got ${result.failureOrNull}',
  );
  return window!;
}

List<String> _uids(List<Donor> donors) =>
    donors.map((Donor donor) => donor.uid).toList();

void main() {
  group('FirestoreDonorRepository asks the database', () {
    test('for one document more than it keeps', () async {
      // The over-fetch-by-one makes `truncated` a measurement instead of a guess.
      final harness = _build(_documents(3));

      _window(await harness.repository.search(DonorQuery.any));

      expect(harness.documents.lastLimit, DonorRepository.window + 1);
      expect(harness.documents.calls, 1);
    });

    test('passes the query straight through to the data source', () async {
      // The repository does not re-filter; filtering is the query's job. What it
      // forwards is exactly what the caller asked for.
      final harness = _build(_documents(2));
      const DonorQuery query = DonorQuery(bloodGroup: 'A+', availableOnly: false);

      await harness.repository.search(query);

      expect(harness.documents.lastQuery, query);
    });
  });

  group('FirestoreDonorRepository reports the window it read', () {
    test('maps and orders every readable document', () async {
      final harness = _build(<DonorDocument>[
        donorDocument('unavailable', fields: donorFields(
          displayName: 'Zara',
          isAvailable: false,
        )),
        donorDocument('available', fields: donorFields(
          displayName: 'Amir',
          isAvailable: true,
        )),
      ]);

      final DiscoveredDonors window = _window(
        await harness.repository.search(DonorQuery.any),
      );

      expect(_uids(window.donors), <String>['available', 'unavailable']);
      expect(window.truncated, isFalse);
      expect(window.skipped, 0);
    });

    test('says a short window is the whole directory', () async {
      final harness = _build(_documents(4));

      final DiscoveredDonors window = _window(
        await harness.repository.search(DonorQuery.any),
      );

      expect(window.donors, hasLength(4));
      expect(window.truncated, isFalse);
    });

    test('says nothing stayed behind when the extra document arrives', () async {
      final List<DonorDocument> full = _documents(DonorRepository.window);
      full.add(donorDocument('behind'));
      final harness = _build(full);

      final DiscoveredDonors window = _window(
        await harness.repository.search(DonorQuery.any),
      );

      expect(window.truncated, isTrue);
      expect(window.donors, hasLength(DonorRepository.window));
      expect(_uids(window.donors).contains('behind'), isFalse);
    });

    test('does not claim donors that are not there', () async {
      // A directory of exactly the window size: all were kept, none looked at past
      // it, so a "more behind them" notice would be a fiction.
      final harness = _build(_documents(DonorRepository.window));

      final DiscoveredDonors window = _window(
        await harness.repository.search(DonorQuery.any),
      );

      expect(window.donors, hasLength(DonorRepository.window));
      expect(window.truncated, isFalse);
    });

    test('answers an empty directory with an empty, honest window', () async {
      final harness = _build(<DonorDocument>[]);

      final DiscoveredDonors window = _window(
        await harness.repository.search(DonorQuery.any),
      );

      expect(window.donors, isEmpty);
      expect(window.isEmpty, isTrue);
      expect(window.truncated, isFalse);
      expect(window.skipped, 0);
    });

    test('hands back a list nobody can sort in place', () async {
      final harness = _build(_documents(2));

      final DiscoveredDonors window = _window(
        await harness.repository.search(DonorQuery.any),
      );

      expect(() => window.donors.add(fakeDonor()), throwsUnsupportedError);
    });
  });

  group('FirestoreDonorRepository counts what it could not read', () {
    test('refuses a non-donor document and counts it', () async {
      final harness = _build(<DonorDocument>[
        _unreadable('bad-1'),
        donorDocument('good-1'),
      ]);

      final DiscoveredDonors window = _window(
        await harness.repository.search(DonorQuery.any),
      );

      expect(window.skipped, 1);
      expect(_uids(window.donors), <String>['good-1']);
    });

    test('lets one bad document keep the good ones around it', () async {
      final List<DonorDocument> mixed = _documents(DonorRepository.window);
      mixed.insert(0, _unreadable('bad'));
      final harness = _build(mixed);

      final DiscoveredDonors window = _window(
        await harness.repository.search(DonorQuery.any),
      );

      expect(window.donors, hasLength(DonorRepository.window - 1));
      expect(window.skipped, 1);
      expect(window.truncated, isTrue, reason: 'the extra document was read');
    });

    test('counts only the documents it looked at', () async {
      // The extra document decides whether the window filled and is then dropped;
      // counting it as skipped would report an unread that was never attempted.
      final List<DonorDocument> full = _documents(DonorRepository.window);
      full.add(_unreadable('behind'));
      final harness = _build(full);

      final DiscoveredDonors window = _window(
        await harness.repository.search(DonorQuery.any),
      );

      expect(window.skipped, 0);
      expect(window.truncated, isTrue);
      expect(window.donors, hasLength(DonorRepository.window));
    });

    test('a window of nothing but refusals is unreadable, not empty', () async {
      final harness = _build(
        <DonorDocument>[_unreadable('bad-1'), _unreadable('bad-2')],
      );

      final DiscoveredDonors window = _window(
        await harness.repository.search(DonorQuery.any),
      );

      expect(window.donors, isEmpty);
      expect(window.isEmpty, isTrue);
      expect(window.skipped, 2);
    });

    test('Stage 9.5: an opted-out donor is refused and counted, not listed', () async {
      // Defence in depth: the live query already excludes opted-out documents
      // (`where('allowDonorDiscovery', isEqualTo: true)`), but a test seam, a
      // cache, or a manually seeded row could hand one to the repository. The
      // mapper refuses it; the operator sees the skip count.
      final harness = _build(<DonorDocument>[
        _notDiscoverable('opted-out'),
        donorDocument('consented'),
      ]);

      final DiscoveredDonors window = _window(
        await harness.repository.search(DonorQuery.any),
      );

      expect(_uids(window.donors), <String>['consented']);
      expect(window.skipped, 1);
    });

    test('Stage 9.5: a legacy document with no consent key is refused', () async {
      // Absent and false are the same thing to the mapper: an upgrade never
      // silently re-lists someone whose document predates the field.
      final Map<String, Object?> legacy = donorFields()..remove('allowDonorDiscovery');
      final harness = _build(<DonorDocument>[
        donorDocument('legacy', fields: legacy),
        donorDocument('consented'),
      ]);

      final DiscoveredDonors window = _window(
        await harness.repository.search(DonorQuery.any),
      );

      expect(_uids(window.donors), <String>['consented']);
      expect(window.skipped, 1);
    });

    test('Stage 9.5: consent refusal does not disturb the truncation over-count', () async {
      // The extra document that decides truncation is not scored as skipped, so
      // a window that filled and then hit an opted-out row still reports the
      // opted-out row as refused rather than quietly rolling it into the count.
      final List<DonorDocument> full = _documents(DonorRepository.window);
      full.add(_notDiscoverable('opted-out-behind'));
      final harness = _build(full);

      final DiscoveredDonors window = _window(
        await harness.repository.search(DonorQuery.any),
      );

      expect(window.truncated, isTrue);
      expect(window.skipped, 0);
      expect(window.donors, hasLength(DonorRepository.window));
    });
  });

  group('FirestoreDonorRepository privacy', () {
    test('a phone key on the document never reaches the donor list', () async {
      final Map<String, Object?> fields = donorFields();
      fields['phone'] = '+8801700000000';
      final harness = _build(<DonorDocument>[donorDocument('d1', fields: fields)]);

      final String printed = _window(
        await harness.repository.search(DonorQuery.any),
      ).toString();

      expect(printed.contains('+8801700000000'), isFalse);
    });

    test('passes a read failure through and invents no window', () async {
      const PermissionFailure failure = PermissionFailure(debugMessage: 'rules');
      final harness = _build(_documents(3));
      harness.documents.failure = failure;

      final Result<DiscoveredDonors> result = await harness.repository
          .search(DonorQuery.any);

      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, same(failure));
    });
  });
}
