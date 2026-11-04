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
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    testApp(
      locale: locale,
      themeMode: themeMode,
      home: Scaffold(body: Center(child: RequestTile(request: request))),
    ),
  );
  await tester.pump();
}

void main() {
  group('RequestTile', () {
    testWidgets('shows the four facts a donor decides on', (
      WidgetTester tester,
    ) async {
      await _pumpTile(
        tester,
        fakeRequest(
          bloodGroup: 'AB+',
          hospitalName: 'Dhaka Medical College',
          hospitalAddress: 'Dhaka',
          units: 3,
          neededBy: _neededByDate,
        ),
      );

      expect(find.byType(BloodGroupBadge), findsOneWidget);
      expect(find.text('AB+'), findsOneWidget);
      expect(find.text('Dhaka Medical College'), findsOneWidget);
      expect(find.text('Dhaka'), findsOneWidget);
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

    testWidgets('repeats the hospital name in one place only', (
      WidgetTester tester,
    ) async {
      // Plenty of these documents type the same district into both fields. A second
      // line saying what the first already said costs vertical space in a list the
      // donor scrolls looking for their group.
      await _pumpTile(
        tester,
        fakeRequest(
          hospitalName: 'Islami Bank Hospital',
          hospitalAddress: 'Islami Bank Hospital',
        ),
      );

      expect(find.text('Islami Bank Hospital'), findsOneWidget);
    });

    testWidgets('says nothing when there is no address to add', (
      WidgetTester tester,
    ) async {
      await _pumpTile(
        tester,
        fakeRequest(hospitalName: 'Rajshahi Medical', hospitalAddress: ''),
      );

      expect(find.text('Rajshahi Medical'), findsOneWidget);
      // Three lines of text, not four: the badge, the hospital, and the units with
      // the date. An absent address is not a fact worth its height in the list.
      expect(tester.widgetList(find.byType(Text)).length, 3);

      await _pumpTile(
        tester,
        fakeRequest(hospitalName: 'Rajshahi Medical', hospitalAddress: 'Rajshahi'),
      );
      expect(tester.widgetList(find.byType(Text)).length, 4);
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

    testWidgets('offers nothing to tap, because there is nowhere to go', (
      WidgetTester tester,
    ) async {
      // Stage 9.1 reads requests; Stage 10 answers them. Until a row has a
      // destination, it must not look tappable — no ripple, no chevron, no button.
      // This is the assertion that fails the moment somebody adds an `onTap` to a
      // card that goes nowhere.
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

    testWidgets('survives a hospital name nobody designed for', (
      WidgetTester tester,
    ) async {
      // 320 logical pixels is the narrowest phone still in use, and this field is
      // free text a stranger typed into a form.
      final BloodRequest long = fakeRequest(
        hospitalName:
            'Bangabandhu Sheikh Medical University Institute of Cardiac Disease',
        hospitalAddress: 'Shahbag, Dhaka 1000, Bangladesh',
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
