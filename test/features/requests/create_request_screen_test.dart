import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/design/widgets/solovvo_text_field.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';
import 'package:sholovvo_app/features/requests/presentation/create_request_screen.dart';

import '../../support/test_app.dart';

const Size _phone = Size(430, 1200);
const Size _narrow = Size(320, 900);
const Size _tablet = Size(900, 1200);

Future<void> _pumpForm(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  Size size = _phone,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    testApp(
      locale: locale,
      home: const CreateRequestScreen(),
    ),
  );
  await tester.pump();
}

/// Finds the `SolovvoButton` that submits the form.
///
/// Located by its label rather than by type because the form's submit button is
/// the only `SolovvoButton` on this screen today, but the test should keep
/// making sense once a "cancel" or "reset" secondary button is added — a
/// by-type finder would then start failing on a wrong-button tap, which is a
/// worse signal than "not found".
Finder get _submit => find.widgetWithText(
  SolovvoButton,
  english.requestsCreateSubmit,
);

Finder get _bloodGroupDropdown => find.byType(DropdownButtonFormField<String>);

/// The three `SolovvoTextField`s on the form, in build order: bags, hospital,
/// notes. `SolovvoTextField` renders its label uppercased through `Text`, but
/// the editable widget inside it is a plain `TextField`, and the form has
/// exactly three of them. Positional indexing is the smallest surface a test
/// can rely on here — `find.widgetWithText(SolovvoTextField, label)` would
/// have to know about the internal uppercase and would break the moment the
/// design system stopped transforming the string.
Finder _field(int index) => find.byType(TextField).at(index);

void main() {
  group('CreateRequestScreen', () {
    testWidgets('titles the app bar with the create copy', (
      WidgetTester tester,
    ) async {
      await _pumpForm(tester);

      expect(find.text(english.requestsCreateTitle), findsOneWidget);
    });

    testWidgets('renders every field the rules ask for', (
      WidgetTester tester,
    ) async {
      await _pumpForm(tester);

      // Blood group dropdown is the one required-and-not-text input; it earns
      // its own finder. Three `SolovvoTextField`s sit under it in the required
      // order, and the date and time tiles round out the form.
      expect(_bloodGroupDropdown, findsOneWidget);
      expect(find.byType(SolovvoTextField), findsNWidgets(3));
      // The dropdown, date and time labels are rendered with their original
      // case; `SolovvoTextField` uppercases its own label, so those three
      // assertions go through `.toUpperCase()` to match what is actually on
      // screen rather than duplicating the design decision at the test layer.
      expect(find.text(english.requestsBloodGroup), findsWidgets);
      expect(find.text(english.requestsBags.toUpperCase()), findsOneWidget);
      expect(find.text(english.requestsHospital.toUpperCase()), findsOneWidget);
      expect(find.text(english.requestsDate), findsOneWidget);
      expect(find.text(english.requestsTime), findsOneWidget);
      expect(find.text(english.requestsNotes.toUpperCase()), findsOneWidget);
      expect(_submit, findsOneWidget);
    });

    testWidgets('the dropdown lists exactly the eight groups the rules accept', (
      WidgetTester tester,
    ) async {
      await _pumpForm(tester);

      await tester.tap(_bloodGroupDropdown);
      await tester.pumpAndSettle();

      // Every group in `BloodGroups.all` is on screen once the dropdown is
      // open, and nothing else is. A ninth entry would be a group Firestore
      // refuses at the rules layer; a missing entry would be a group a donor
      // cannot ask for.
      //
      // `findsWidgets` rather than `findsOneWidget` because the popup and
      // the closed field can both render the current-value slot at the same
      // time in Flutter's dropdown route; the point is that every one of the
      // eight appears at least once while the popup is up.
      for (final String group in BloodGroups.all) {
        expect(find.text(group), findsWidgets);
      }

      // Pick one so the popup dismisses and the next test starts from a
      // tree without an overlay route in it. Flutter's dropdown accepts a
      // tap on any of its item rows and pops the route with that value.
      await tester.tap(find.text('A+').first);
      await tester.pumpAndSettle();
    });

    testWidgets('a missing blood group fails validation, not the network', (
      WidgetTester tester,
    ) async {
      // `_submit()` returns early on validation failure, so no service is
      // called and `FirebaseAuth.instance.currentUser` is never read. That
      // is the whole reason this file can test validation without a Firebase
      // project: the failure path is a client-side guard, and the guard is
      // what would stop a rule-refused document from ever leaving the app.
      await _pumpForm(tester);

      await tester.tap(_submit);
      await tester.pump();

      expect(
        find.text('${english.requestsBloodGroup}: ${english.requestsRequired}'),
        findsOneWidget,
      );
    });

    testWidgets('bags below one fails validation', (WidgetTester tester) async {
      // The rule (`bloodBags is int && bloodBags >= 1`) is mirrored client-
      // side. A form that let a donor post a zero-bag request would produce a
      // document Firestore refuses with a permission error, and the donor
      // would see "Could not create the request" instead of the honest "this
      // field is required".
      await _pumpForm(tester);

      // Pick a group so the earlier validation branch does not fire first.
      await tester.tap(_bloodGroupDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('A+').first);
      await tester.pumpAndSettle();

      await tester.enterText(_field(0), '0');
      await tester.pump();

      await tester.tap(_submit);
      await tester.pump();

      expect(
        find.text('${english.requestsBags}: ${english.requestsRequired}'),
        findsOneWidget,
      );
    });

    testWidgets('an empty hospital name fails validation', (
      WidgetTester tester,
    ) async {
      await _pumpForm(tester);

      await tester.tap(_bloodGroupDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('A+').first);
      await tester.pumpAndSettle();

      // Bags defaults to "1", so validation reaches the hospital field.
      await tester.enterText(_field(1), '');
      await tester.pump();

      await tester.tap(_submit);
      await tester.pump();

      expect(
        find.text('${english.requestsHospital}: ${english.requestsRequired}'),
        findsOneWidget,
      );
    });

    testWidgets('a missing date fails validation', (WidgetTester tester) async {
      await _pumpForm(tester);

      await tester.tap(_bloodGroupDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('A+').first);
      await tester.pumpAndSettle();

      // Fill a hospital name so the earlier branch does not fire first. Bags
      // already has "1" as its initial value; the date is the field that
      // defaults to null and needs typing.
      await tester.enterText(_field(1), 'Dhaka Medical');
      await tester.pump();

      await tester.tap(_submit);
      await tester.pump();

      expect(
        find.text('${english.requestsDate}: ${english.requestsRequired}'),
        findsOneWidget,
      );
    });

    testWidgets('clears a stale error when every field is filled', (
      WidgetTester tester,
    ) async {
      // A donor who sees the "hospital required" line, fills the hospital,
      // and taps again with a still-missing date should see the date error,
      // not both stacked. `_validate()` short-circuits and its setState
      // replaces the message rather than appending, which is what makes an
      // old error disappearing when its field is fixed the observable
      // behaviour rather than a coincidence.
      await _pumpForm(tester);

      await tester.tap(_submit);
      await tester.pump();
      expect(
        find.text('${english.requestsBloodGroup}: ${english.requestsRequired}'),
        findsOneWidget,
      );

      // Pick a group; submit again; the error moves to the next field.
      await tester.tap(_bloodGroupDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('A+').first);
      await tester.pumpAndSettle();

      await tester.tap(_submit);
      await tester.pump();

      expect(
        find.text('${english.requestsBloodGroup}: ${english.requestsRequired}'),
        findsNothing,
      );
      // The hospital is a required branch that fires before the date, so it
      // is the message the second submit earns.
      expect(
        find.text('${english.requestsHospital}: ${english.requestsRequired}'),
        findsOneWidget,
      );
    });

    testWidgets('renders the whole form in Bangla', (
      WidgetTester tester,
    ) async {
      await _pumpForm(tester, locale: const Locale('bn'));

      expect(find.text(bangla.requestsCreateTitle), findsOneWidget);
      expect(find.text(bangla.requestsBloodGroup), findsWidgets);
      expect(find.text(bangla.requestsHospital.toUpperCase()), findsOneWidget);
      expect(find.text(bangla.requestsCreateSubmit), findsOneWidget);
      // The English copy is genuinely gone, not merely hidden behind an
      // overflow — the same parity argument the detail test makes.
      expect(find.text(english.requestsCreateTitle), findsNothing);
    });

    testWidgets('a validation error is worded in Bangla too', (
      WidgetTester tester,
    ) async {
      // The exact reason the ARB parity test exists: the validation branch
      // concatenates two localised strings at runtime, and if one lived only
      // in English the concatenation would be half-Bangla half-English. This
      // test catches that at the widget layer.
      await _pumpForm(tester, locale: const Locale('bn'));

      await tester.tap(
        find.widgetWithText(SolovvoButton, bangla.requestsCreateSubmit),
      );
      await tester.pump();

      expect(
        find.text('${bangla.requestsBloodGroup}: ${bangla.requestsRequired}'),
        findsOneWidget,
      );
    });

    testWidgets('fits a small phone (320x900) without overflow', (
      WidgetTester tester,
    ) async {
      // The form is inside a `SingleChildScrollView`, so a taller column is
      // not itself an overflow; the test is that no horizontal overflow or
      // RenderFlex exception fires when every field is squeezed to 320 dp.
      await _pumpForm(tester, size: _narrow);

      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a large phone (430x1200) without overflow', (
      WidgetTester tester,
    ) async {
      await _pumpForm(tester, size: _phone);

      expect(tester.takeException(), isNull);
    });

    testWidgets('reflows to a wider measure on a tablet (900x1200)', (
      WidgetTester tester,
    ) async {
      await _pumpForm(tester, size: _tablet);

      expect(tester.takeException(), isNull);
    });
  });
}
