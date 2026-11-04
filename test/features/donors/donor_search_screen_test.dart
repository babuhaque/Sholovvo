import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/design/widgets/error_banner.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/donors/application/donor_search_providers.dart';
import 'package:sholovvo_app/features/donors/domain/donor_repository.dart';
import 'package:sholovvo_app/features/donors/domain/entities/donor.dart';
import 'package:sholovvo_app/features/donors/presentation/donor_details_screen.dart';
import 'package:sholovvo_app/features/donors/presentation/donor_search_screen.dart';
import 'package:sholovvo_app/features/donors/presentation/widgets/donor_card.dart';

import '../../support/fake_donors.dart';
import '../../support/test_app.dart';

const Size _phone = Size(430, 932);

List<Donor> _donors(int count) {
  return <Donor>[
    for (int index = 0; index < count; index++)
      fakeDonor(
        uid: 'd-$index',
        displayName: 'Donor $index',
        isAvailable: true,
      ),
  ];
}

Future<FakeDonorRepository> _pumpDonors(
  WidgetTester tester, {
  List<Donor>? donors,
  bool truncated = false,
  int skipped = 0,
  Failure? failure,
  Completer<void>? gate,
  Locale locale = const Locale('en'),
  Size size = _phone,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final FakeDonorRepository repository = FakeDonorRepository(
    donors: donors,
    truncated: truncated,
    skipped: skipped,
  );
  repository.failure = failure;
  repository.gate = gate;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [donorRepositoryProvider.overrideWithValue(repository)],
      child: testApp(home: const DonorSearchScreen(), locale: locale),
    ),
  );
  await _settle(tester);
  return repository;
}

Future<void> _settle(WidgetTester tester, [int frames = 4]) async {
  for (int index = 0; index < frames; index++) {
    await tester.pump();
  }
}

Future<void> _pullToRefresh(WidgetTester tester) async {
  await tester.fling(
    find.byType(CustomScrollView),
    const Offset(0, 300),
    1000,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 800));
}

Finder get _retry => find.widgetWithText(SolovvoButton, 'Try again');

void main() {
  group('DonorSearchScreen while it reads', () {
    testWidgets('asks for the window once, on opening', (
      WidgetTester tester,
    ) async {
      final FakeDonorRepository repository = await _pumpDonors(
        tester,
        donors: _donors(2),
        gate: Completer<void>(),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(DonorCard), findsNothing);
      expect(repository.calls, 1);

      repository.gate!.complete();
      await _settle(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(DonorCard), findsNWidgets(2));
    });

    testWidgets('shows the filter bar it opens with', (WidgetTester tester) async {
      await _pumpDonors(tester, donors: _donors(1));

      expect(find.text('Find donors'), findsOneWidget);
      expect(find.text('All groups'), findsOneWidget);
      expect(find.text('Available donors only'), findsOneWidget);
      // A real blood-group chip among the eight.
      expect(find.text('AB+'), findsOneWidget);
    });

    testWidgets('says there is no contact control here', (
      WidgetTester tester,
    ) async {
      await _pumpDonors(tester, donors: _donors(1));

      expect(
        find.textContaining('contact details are not shown'),
        findsOneWidget,
      );
    });
  });

  group('DonorSearchScreen with nothing to show', () {
    testWidgets('an empty unfiltered directory says none are listed', (
      WidgetTester tester,
    ) async {
      await _pumpDonors(tester, donors: <Donor>[]);

      expect(find.text('No donors are listed yet'), findsOneWidget);
      expect(find.text('No donors match your filters'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('an empty *filtered* directory says nobody matches', (
      WidgetTester tester,
    ) async {
      await _pumpDonors(tester, donors: <Donor>[]);
      // A group chip narrows the query; the empty copy switches to the filtered one.
      await tester.tap(find.text('A+'));
      await _settle(tester);

      expect(find.text('No donors match your filters'), findsOneWidget);
      expect(find.text('No donors are listed yet'), findsNothing);
    });

    testWidgets('a failed first read is an error, not an empty directory', (
      WidgetTester tester,
    ) async {
      await _pumpDonors(tester, failure: const NetworkFailure());

      expect(find.text('The donors could not be loaded'), findsOneWidget);
      expect(find.text(english.donorEmptyAllTitle), findsNothing);
      expect(_retry, findsOneWidget);
    });

    testWidgets('retries from the error card and shows the donors', (
      WidgetTester tester,
    ) async {
      final FakeDonorRepository repository = await _pumpDonors(
        tester,
        failure: const NetworkFailure(),
      );
      expect(repository.calls, 1);

      repository.failure = null;
      repository.donors = _donors(2);
      await tester.tap(_retry);
      await _settle(tester);

      expect(repository.calls, 2);
      expect(find.text('The donors could not be loaded'), findsNothing);
      expect(find.byType(DonorCard), findsNWidgets(2));
    });

    testWidgets('reports unreadable refusals with a count, no button', (
      WidgetTester tester,
    ) async {
      await _pumpDonors(tester, donors: <Donor>[], skipped: 2);

      expect(find.text('The donors could not be fully read'), findsOneWidget);
      expect(find.text('2 donors could not be shown'), findsOneWidget);
      expect(_retry, findsNothing);
    });
  });

  group('DonorSearchScreen caveats over a list', () {
    testWidgets('names the window size when the list filled up', (
      WidgetTester tester,
    ) async {
      await _pumpDonors(tester, donors: _donors(2), truncated: true);

      expect(
        find.textContaining('Only the first ${DonorRepository.window} donors'),
        findsOneWidget,
      );
    });

    testWidgets('keeps the list and banners a refresh that failed', (
      WidgetTester tester,
    ) async {
      final FakeDonorRepository repository = await _pumpDonors(
        tester,
        donors: _donors(2),
      );
      repository.failure = const NetworkFailure();

      await _pullToRefresh(tester);

      expect(find.byType(DonorCard), findsNWidgets(2));
      expect(find.byType(ErrorBanner), findsOneWidget);
      expect(find.text('The donors could not be loaded'), findsNothing);
    });

    testWidgets('does not start a second read while one is running', (
      WidgetTester tester,
    ) async {
      final FakeDonorRepository repository = await _pumpDonors(
        tester,
        donors: _donors(1),
        gate: Completer<void>(),
      );
      expect(repository.calls, 1);

      repository.gate!.complete();
      await _settle(tester);
      repository.gate = Completer<void>();
      await _pullToRefresh(tester);
      final int during = repository.calls;
      await _pullToRefresh(tester);

      expect(repository.calls, during, reason: 'the second pull was refused');
      repository.gate!.complete();
      await _settle(tester);
    });
  });

  group('DonorSearchScreen navigation', () {
    testWidgets('tapping a card opens that donor\'s public profile', (
      WidgetTester tester,
    ) async {
      await _pumpDonors(tester, donors: <Donor>[
        fakeDonor(uid: 'x', displayName: 'Nadia Islam', isAvailable: true),
      ]);

      await tester.tap(find.byType(DonorCard));
      await _settle(tester, 6);

      expect(find.byType(DonorDetailsScreen), findsOneWidget);
      expect(find.text('Donor profile'), findsOneWidget);
      // The name appears on the pushed profile; the card behind it still holds its
      // own copy, so scope the check to the details screen rather than the tree.
      expect(
        find.descendant(
          of: find.byType(DonorDetailsScreen),
          matching: find.text('Nadia Islam'),
        ),
        findsOneWidget,
      );
    });
  });

  group('DonorSearchScreen in Bangla', () {
    testWidgets('titles, filter labels and empty card', (
      WidgetTester tester,
    ) async {
      await _pumpDonors(
        tester,
        donors: <Donor>[],
        locale: const Locale('bn'),
      );

      expect(find.text(bangla.donorSearchTitle), findsOneWidget);
      expect(find.text(bangla.donorEmptyAllTitle), findsOneWidget);
      expect(find.text(english.donorEmptyAllTitle), findsNothing);
    });

    testWidgets('says an unreadable window in Bangla, with the count', (
      WidgetTester tester,
    ) async {
      await _pumpDonors(
        tester,
        donors: <Donor>[],
        skipped: 2,
        locale: const Locale('bn'),
      );

      expect(find.text(bangla.donorUnreadableTitle), findsOneWidget);
      expect(find.text(bangla.donorSkippedNotice(2)), findsOneWidget);
      expect(find.text(english.donorSkippedNotice(2)), findsNothing);
    });
  });

  group('DonorSearchScreen layout', () {
    testWidgets('stays inside its measure on a wide window', (
      WidgetTester tester,
    ) async {
      await _pumpDonors(
        tester,
        donors: _donors(4),
        size: const Size(1200, 900),
      );

      expect(find.byType(DonorCard), findsNWidgets(4));
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(DonorCard).first).width,
        lessThanOrEqualTo(DonorSearchScreen.wideMaxWidth),
      );
    });

    testWidgets('is pullable at a phone width with a short list', (
      WidgetTester tester,
    ) async {
      await _pumpDonors(tester, donors: _donors(1));

      final CustomScrollView scroll = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(scroll.physics, isA<AlwaysScrollableScrollPhysics>());
    });
  });
}
