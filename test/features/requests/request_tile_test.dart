import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/design/widgets/blood_group_badge.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';
import 'package:sholovvo_app/features/requests/presentation/widgets/request_tile.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

import '../../support/fake_requests.dart';
import '../../support/test_app.dart';

const Size _phone = Size(430, 932);

final DateTime _neededByDate = DateTime.utc(2026, 11, 9, 14);

/// The "Needed by …" sentence, built the way the row builds it: the label from the
/// catalogue under test and the date from the same [MaterialLocalizations] the row
/// formats with. A literal here would be a second source of truth for a date
/// pattern, and the wrong one as soon as the locale changes.
String _neededByLabel(WidgetTester tester, AppLocalizations l10n) {
  return l10n.homeNeededBy(
    MaterialLocalizations.of(
      tester.element(find.byType(RequestTile)),
    ).formatShortMonthDay(_neededByDate.toLocal()),
  );
}

Future<void> _pumpTile(
  WidgetTester tester,
  BloodRequest request, {
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
  Size size = _phone,
  VoidCallback? onTap,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    testApp(
      locale: locale,
      themeMode: themeMode,
      home: Scaffold(
        body: Center(child: RequestTile(request: request, onTap: onTap)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('RequestTile', () {
    testWidgets('shows the facts a donor decides on', (
      WidgetTester tester,
    ) async {
      await _pumpTile(
        tester,
        fakeRequest(
          bloodGroup: 'AB+',
          hospitalName: 'Dhaka Medical College',
          units: 3,
          neededBy: _neededByDate,
        ),
      );

      expect(find.byType(BloodGroupBadge), findsOneWidget);
      expect(find.text('AB+'), findsOneWidget);
      expect(find.text('Dhaka Medical College'), findsOneWidget);
      expect(find.textContaining(english.homeUnitsNeeded(3)), findsOneWidget);
      expect(find.textContaining(_neededByLabel(tester, english)), findsOneWidget);
    });

    testWidgets('keeps the units and the date in one statement', (
      WidgetTester tester,
    ) async {
      await _pumpTile(tester, fakeRequest(units: 1, neededBy: _neededByDate));

      // One text node, on purpose: read out, the row should say "1 unit needed,
      // needed by Nov 9" as the single fact it is. Two sibling lines are read as
      // two unrelated statements about different things.
      expect(
        find.text(
          '${english.homeUnitsNeeded(1)} · ${_neededByLabel(tester, english)}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('names the hospital once, and never an address', (
      WidgetTester tester,
    ) async {
      // Stage 9.5 (M3-C1): `hospitalAddress` left the public document for the
      // private/contact subcollection, so the row has one location line — the
      // hospital — and nothing below it that could carry a street.
      await _pumpTile(
        tester,
        fakeRequest(hospitalName: 'Islami Bank Hospital'),
      );

      expect(find.text('Islami Bank Hospital'), findsOneWidget);
    });

    testWidgets('is always three lines: badge, hospital, units with the date', (
      WidgetTester tester,
    ) async {
      // There is no longer an optional fourth line for an address, so the row's
      // height does not vary with a field the donor can no longer be shown.
      await _pumpTile(
        tester,
        fakeRequest(hospitalName: 'Rajshahi Medical'),
      );

      expect(find.text('Rajshahi Medical'), findsOneWidget);
      expect(tester.widgetList(find.byType(Text)).length, 3);
    });

    testWidgets('shows the words the requester typed when the date cannot be '
        'read', (WidgetTester tester) async {
      await _pumpTile(tester, fakeRequest(neededByText: 'রোগীর জন্য জরুরি'));

      expect(find.textContaining('রোগীর জন্য জরুরি'), findsOneWidget);
      // Matched as a fragment throughout this file: the row carries the units and
      // the date in one text node, so no label is ever a whole string on screen.
      expect(find.textContaining(english.homeNeededByUnknown), findsNothing);
    });

    testWidgets('says there is no date rather than implying none matters', (
      WidgetTester tester,
    ) async {
      await _pumpTile(tester, fakeRequest());

      // A row that silently dropped the date looks like a request nobody is in a
      // hurry about, and urgency is the only reason to read this list.
      expect(find.textContaining(english.homeNeededByUnknown), findsOneWidget);
    });

    testWidgets('is inert when the caller passes no onTap', (
      WidgetTester tester,
    ) async {
      // Stage 9.1 pinned this shape because there was nowhere to go. Stage 10
      // kept the invariant and moved the choice to the caller: with `onTap`
      // omitted, the row still carries no ripple, no chevron and no button, so
      // a hypothetical future caller without a destination cannot accidentally
      // look actionable. A caller that DOES have a destination passes a
      // callback, and the next test verifies the row becomes tappable.
      await _pumpTile(tester, fakeRequest());

      expect(find.byType(SolovvoCard), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(GestureDetector), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(SolovvoButton), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

      await tester.tap(find.byType(RequestTile));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('becomes tappable when the caller passes onTap', (
      WidgetTester tester,
    ) async {
      // The row's one affordance is a callback the caller supplies. SolovvoCard
      // wraps the content in an InkWell when (and only when) `onTap` is not
      // null, so the same widget can look inert on a hypothetical future caller
      // that has no destination and actionable on the two callers that do
      // (the dashboard preview and the requests screen).
      int taps = 0;
      await _pumpTile(
        tester,
        fakeRequest(),
        onTap: () => taps++,
      );

      expect(find.byType(InkWell), findsOneWidget);

      await tester.tap(find.byType(RequestTile));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('survives a hospital name nobody designed for', (
      WidgetTester tester,
    ) async {
      // 320 logical pixels is the narrowest phone still in use, and this field is
      // free text a stranger typed into a form.
      final BloodRequest long = fakeRequest(
        hospitalName:
            'Bangabandhu Sheikh Medical University Institute of Cardiac Disease',
        units: 12,
        neededBy: _neededByDate,
      );

      await _pumpTile(tester, long, size: const Size(320, 640));

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Text>(find.text(long.hospitalName)).maxLines,
        1,
        reason: 'ellipsised on one line rather than pushing the list apart',
      );
    });

    testWidgets('draws the same row in Bangla', (WidgetTester tester) async {
      await _pumpTile(
        tester,
        fakeRequest(units: 2, neededBy: _neededByDate),
        locale: const Locale('bn'),
      );

      expect(find.textContaining(bangla.homeUnitsNeeded(2)), findsOneWidget);
      expect(find.textContaining(_neededByLabel(tester, bangla)), findsOneWidget);
      // The group is a medical value, not a word: it is never translated.
      expect(find.text('A+'), findsOneWidget);
      expect(find.text(english.homeUnitsNeeded(2)), findsNothing);
    });

    testWidgets('reads the theme it is given', (WidgetTester tester) async {
      await _pumpTile(
        tester,
        fakeRequest(hospitalName: 'Cumilla Medical'),
        themeMode: ThemeMode.dark,
      );

      expect(find.text('Cumilla Medical'), findsOneWidget);
      final SolovvoCard card = tester.widget<SolovvoCard>(
        find.byType(SolovvoCard),
      );
      // The card takes its colour from the theme rather than carrying one, which
      // is what makes the dark run above need no second approved palette.
      expect(card.color, isNull);
    });
  });
}
