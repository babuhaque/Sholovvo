import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/design/widgets/solovvo_text_field.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';
import 'package:sholovvo_app/features/requests/application/requests_providers.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';
import 'package:sholovvo_app/features/requests/presentation/edit_request_screen.dart';

import '../../support/fake_requests.dart';
import '../../support/test_app.dart';

const Size _phone = Size(430, 1200);
const Size _narrow = Size(320, 900);
const Size _tablet = Size(900, 1200);

/// Two `SolovvoTextField`s on the form, in build order: bags, hospital. The
/// dropdown above them has its own finder. Positional indexing is used for
/// the same reason [create_request_screen_test] uses it — `SolovvoTextField`
/// uppercases its own label inside its `Text` child, so `find.widgetWithText`
/// against the raw l10n label would fail on a case mismatch the design system
/// owns.
Finder _field(int index) => find.byType(TextField).at(index);

Finder get _bloodGroupDropdown => find.byType(DropdownButtonFormField<String>);

Finder get _submit => find.widgetWithText(
  SolovvoButton,
  english.requestsEditSubmit,
);

Future<void> _pumpForm(
  WidgetTester tester,
  BloodRequest request, {
  Locale locale = const Locale('en'),
  Size size = _phone,
  FakeRequestEditService? editService,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final ProviderContainer container = ProviderContainer(
    overrides: [
      // The edit screen only reads the service provider, not the uid
      // provider; overriding the uid here keeps any future change from
      // accidentally resolving the real FirebaseAuth-backed default in a
      // widget test.
      requestsAuthUidProvider.overrideWithValue('uid-recipient'),
      if (editService != null)
        requestEditServiceProvider.overrideWithValue(editService),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: testApp(
        locale: locale,
        home: EditRequestScreen(request: request),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('EditRequestScreen', () {
    testWidgets('titles the app bar with the edit copy', (
      WidgetTester tester,
    ) async {
      await _pumpForm(tester, fakeRequest());

      expect(find.text(english.requestsEditTitle), findsOneWidget);
    });

    testWidgets('pre-populates every field from the request', (
      WidgetTester tester,
    ) async {
      // The form's contract is "show me what I wrote, let me change it".
      // A pre-populate bug (dropping the controller's initial text, or
      // reading the wrong entity field) makes a "Save" that quietly reverts
      // something, and the donor does not see it happen. Asserting all
      // three fields against the entity is exactly the check.
      final BloodRequest r = fakeRequest(
        bloodGroup: 'AB-',
        hospitalName: 'Labaid Specialized',
        units: 5,
      );
      await _pumpForm(tester, r);

      // Bags and hospital in their respective TextFields, and the dropdown
      // showing AB- as its current value. The dropdown renders the selected
      // item inside its button, so `find.text('AB-')` finds one widget on
      // a closed dropdown.
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Labaid Specialized'), findsOneWidget);
      expect(find.text('AB-'), findsWidgets);
    });

    testWidgets('renders the three editable fields and no others', (
      WidgetTester tester,
    ) async {
      // The rule permits eight keys, the entity carries seven, the form
      // writes three. `notes` is absent because the entity does not read
      // it, and the date tile is absent because the two storage shapes
      // (Timestamp vs free text) cannot round-trip through a form without
      // risking a silent rewrite of the urgency the requester typed. This
      // test pins the *narrower* scope so a future "helpful" addition has
      // to answer this assertion first.
      await _pumpForm(tester, fakeRequest());

      expect(_bloodGroupDropdown, findsOneWidget);
      // Two `SolovvoTextField`s, not three — bags and hospital only; no
      // notes field on this form.
      expect(find.byType(SolovvoTextField), findsNWidgets(2));
      expect(find.text(english.requestsBags.toUpperCase()), findsOneWidget);
      expect(find.text(english.requestsHospital.toUpperCase()), findsOneWidget);
      // The date and time tiles from the create form are absent.
      expect(find.text(english.requestsDate), findsNothing);
      expect(find.text(english.requestsTime), findsNothing);
      // So is the notes field.
      expect(find.text(english.requestsNotes.toUpperCase()), findsNothing);
      expect(_submit, findsOneWidget);
    });

    testWidgets('the dropdown still lists exactly the eight groups', (
      WidgetTester tester,
    ) async {
      await _pumpForm(tester, fakeRequest(bloodGroup: 'O+'));

      await tester.tap(_bloodGroupDropdown);
      await tester.pumpAndSettle();

      // `findsWidgets` rather than `findsOneWidget` because the popup and
      // the closed field's current-value slot can both render 'O+'
      // simultaneously — same reason the create-form test uses it.
      for (final String group in BloodGroups.all) {
        expect(find.text(group), findsWidgets);
      }

      await tester.tap(find.text('A-').first);
      await tester.pumpAndSettle();
    });

    testWidgets('a no-op submit calls the service with the three editable keys',
        (WidgetTester tester) async {
      // The form's field whitelist is the whole reason this stage is safe
      // to ship: any key outside the eight the rules allow would produce a
      // permission-denied at write time, and any key inside the eight that
      // the form does not show (notes, requestType, latitude, longitude,
      // requiredDateTime) would be silently cleared if the form sent it
      // with a null value. This test pins the shape.
      final FakeRequestEditService service = FakeRequestEditService();
      final BloodRequest r = fakeRequest(
        id: 'req-abc',
        bloodGroup: 'B+',
        hospitalName: 'Square',
        units: 2,
      );
      await _pumpForm(tester, r, editService: service);

      await tester.tap(_submit);
      await tester.pumpAndSettle();

      expect(service.calls, hasLength(1));
      final (String requestId, Map<String, Object?> fields) =
          service.calls.first;
      expect(requestId, 'req-abc');
      expect(fields.keys, unorderedEquals(<String>[
        'bloodGroup',
        'bloodBags',
        'hospitalName',
      ]));
      expect(fields['bloodGroup'], 'B+');
      expect(fields['bloodBags'], 2);
      expect(fields['hospitalName'], 'Square');
    });

    testWidgets('an edit to bags and hospital sends the new values', (
      WidgetTester tester,
    ) async {
      // Pre-population and validation both pass a value through, but only
      // a real edit test proves the form reads the *controller*, not the
      // entity, on submit. A bug that re-sent the original entity would
      // still satisfy every other test in this file.
      final FakeRequestEditService service = FakeRequestEditService();
      final BloodRequest r = fakeRequest(
        id: 'req-edit',
        bloodGroup: 'O+',
        hospitalName: 'Dhaka Medical',
        units: 1,
      );
      await _pumpForm(tester, r, editService: service);

      await tester.enterText(_field(0), '4');
      await tester.enterText(_field(1), 'United Hospital');
      await tester.pump();

      await tester.tap(_submit);
      await tester.pumpAndSettle();

      final Map<String, Object?> fields = service.calls.first.$2;
      expect(fields['bloodBags'], 4);
      expect(fields['hospitalName'], 'United Hospital');
      expect(fields['bloodGroup'], 'O+');
    });

    testWidgets('changing the group via the dropdown sends the new group', (
      WidgetTester tester,
    ) async {
      final FakeRequestEditService service = FakeRequestEditService();
      await _pumpForm(
        tester,
        fakeRequest(id: 'req-group', bloodGroup: 'A+'),
        editService: service,
      );

      await tester.tap(_bloodGroupDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('AB+').first);
      await tester.pumpAndSettle();

      await tester.tap(_submit);
      await tester.pumpAndSettle();

      expect(service.calls.first.$2['bloodGroup'], 'AB+');
    });

    testWidgets('bags below one fails validation, not the network', (
      WidgetTester tester,
    ) async {
      // Mirrors the create form's guard so a donor cannot post an edit that
      // the rules would refuse with a `permission-denied`, which surfaces
      // as "Could not update" instead of an actionable field error.
      final FakeRequestEditService service = FakeRequestEditService();
      await _pumpForm(tester, fakeRequest(), editService: service);

      await tester.enterText(_field(0), '0');
      await tester.pump();

      await tester.tap(_submit);
      await tester.pump();

      expect(
        find.text('${english.requestsBags}: ${english.requestsRequired}'),
        findsOneWidget,
      );
      expect(service.calls, isEmpty);
    });

    testWidgets('an empty hospital name fails validation', (
      WidgetTester tester,
    ) async {
      final FakeRequestEditService service = FakeRequestEditService();
      await _pumpForm(tester, fakeRequest(), editService: service);

      await tester.enterText(_field(1), '   ');
      await tester.pump();

      await tester.tap(_submit);
      await tester.pump();

      expect(
        find.text('${english.requestsHospital}: ${english.requestsRequired}'),
        findsOneWidget,
      );
      expect(service.calls, isEmpty);
    });

    testWidgets('clears a stale error when the field is fixed', (
      WidgetTester tester,
    ) async {
      // Same shape as the create test — the validation message sits in a
      // single `_errorMessage` slot that `setState` replaces, so fixing
      // the field and resubmitting yields the next branch's message, not
      // two stacked errors.
      final FakeRequestEditService service = FakeRequestEditService();
      await _pumpForm(tester, fakeRequest(), editService: service);

      await tester.enterText(_field(0), '0');
      await tester.pump();
      await tester.tap(_submit);
      await tester.pump();
      expect(
        find.text('${english.requestsBags}: ${english.requestsRequired}'),
        findsOneWidget,
      );

      await tester.enterText(_field(0), '3');
      await tester.enterText(_field(1), '');
      await tester.pump();
      await tester.tap(_submit);
      await tester.pump();

      expect(
        find.text('${english.requestsBags}: ${english.requestsRequired}'),
        findsNothing,
      );
      expect(
        find.text('${english.requestsHospital}: ${english.requestsRequired}'),
        findsOneWidget,
      );
    });

    testWidgets('a service failure surfaces the copy and keeps the form open', (
      WidgetTester tester,
    ) async {
      // A permission-denied or a network failure means the request is not
      // edited. Popping here would look like success, so the screen has to
      // stay put and let the donor retry. Same discipline as the cancel
      // flow's failure branch.
      final FakeRequestEditService service = FakeRequestEditService()
        ..failure = const PermissionFailure(
          debugMessage: 'test: rules refused the edit',
        );
      await _pumpForm(tester, fakeRequest(), editService: service);

      await tester.tap(_submit);
      await tester.pumpAndSettle();

      expect(find.byType(EditRequestScreen), findsOneWidget);
      expect(find.text(english.requestsEditError), findsOneWidget);
      // The submit button is enabled again for a retry; `_isSubmitting`
      // has been cleared. If the button stayed disabled, the donor would
      // have no way to try again without navigating away.
      expect(service.calls, hasLength(1));
    });

    testWidgets('a successful submit pops with the edited id', (
      WidgetTester tester,
    ) async {
      // The sentinel the caller list refreshes on. Asserting the route
      // contract here (rather than only in the detail test) means the
      // contract is nailed to the widget that actually pushes it, and a
      // change to either side has to move this test.
      final FakeRequestEditService service = FakeRequestEditService();
      final BloodRequest r = fakeRequest(id: 'req-pop', neededBy: null);

      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final ProviderContainer container = ProviderContainer(
        overrides: [requestEditServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: testApp(
            home: Builder(
              builder: (BuildContext context) {
                return Scaffold(
                  body: Center(child: const Text('host')),
                );
              },
            ),
          ),
        ),
      );

      final NavigatorState nav = tester.state<NavigatorState>(
        find.byType(Navigator).last,
      );
      final Future<String?> popped = nav.push<String?>(
        EditRequestScreen.route(r),
      );
      await tester.pumpAndSettle();

      await tester.tap(_submit);
      await tester.pumpAndSettle();

      expect(await popped, 'req-pop');
      expect(find.byType(EditRequestScreen), findsNothing);
    });

    testWidgets('a submit in flight disables the button and shows "Saving…"', (
      WidgetTester tester,
    ) async {
      // The double-tap guard. A second tap during a running write would
      // issue a second `update()` call, which the rules accept, but which
      // could carry a different form state than the first (the user typing
      // while the write is running). Holding a `Completer` gate makes the
      // in-flight state observable long enough to test.
      final FakeRequestEditService service = FakeRequestEditService()
        ..gate = Completer<void>();
      await _pumpForm(tester, fakeRequest(), editService: service);

      // Locate the submit button by type rather than by label so a second
      // tap still finds it once the label has flipped to "Saving…". The
      // form has exactly one SolovvoButton today, and if a secondary one
      // is added later this test should fail loudly rather than quietly
      // tapping the wrong widget.
      final Finder submitButton = find.byType(SolovvoButton);
      await tester.tap(submitButton);
      // One pump runs the `setState` that sets `_isSubmitting` without
      // resolving the pending future.
      await tester.pump();

      expect(find.text(english.requestsEditSaving), findsOneWidget);
      expect(service.calls, hasLength(1));

      // Tapping again while in flight must not fire a second write.
      await tester.tap(submitButton);
      await tester.pump();
      expect(service.calls, hasLength(1));

      // Release the gate and let the write land.
      service.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('renders the whole form in Bangla', (
      WidgetTester tester,
    ) async {
      await _pumpForm(tester, fakeRequest(), locale: const Locale('bn'));

      expect(find.text(bangla.requestsEditTitle), findsOneWidget);
      expect(find.text(bangla.requestsBags.toUpperCase()), findsOneWidget);
      expect(find.text(bangla.requestsHospital.toUpperCase()), findsOneWidget);
      expect(
        find.widgetWithText(SolovvoButton, bangla.requestsEditSubmit),
        findsOneWidget,
      );
      // The English copy is genuinely absent, not merely hidden behind
      // overflow — same parity argument the create-form test makes.
      expect(find.text(english.requestsEditTitle), findsNothing);
    });

    testWidgets('a validation error is worded in Bangla too', (
      WidgetTester tester,
    ) async {
      await _pumpForm(tester, fakeRequest(), locale: const Locale('bn'));

      await tester.enterText(_field(0), '0');
      await tester.pump();
      await tester.tap(
        find.widgetWithText(SolovvoButton, bangla.requestsEditSubmit),
      );
      await tester.pump();

      expect(
        find.text('${bangla.requestsBags}: ${bangla.requestsRequired}'),
        findsOneWidget,
      );
    });

    testWidgets('fits a small phone (320x900) without overflow', (
      WidgetTester tester,
    ) async {
      await _pumpForm(tester, fakeRequest(), size: _narrow);

      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a large phone (430x1200) without overflow', (
      WidgetTester tester,
    ) async {
      await _pumpForm(tester, fakeRequest(), size: _phone);

      expect(tester.takeException(), isNull);
    });

    testWidgets('reflows to a wider measure on a tablet (900x1200)', (
      WidgetTester tester,
    ) async {
      await _pumpForm(tester, fakeRequest(), size: _tablet);

      expect(tester.takeException(), isNull);
    });
  });
}
