import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/design/widgets/solovvo_text_field.dart';
import 'package:sholovvo_app/features/requests/application/requests_providers.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';
import 'package:sholovvo_app/features/requests/domain/entities/request_contact.dart';
import 'package:sholovvo_app/features/requests/presentation/request_contact_screen.dart';

import '../../support/fake_requests.dart';
import '../../support/test_app.dart';

const Size _phone = Size(430, 1200);
const Size _narrow = Size(320, 900);
const Size _tablet = Size(900, 1200);

/// Three `SolovvoTextField`s on the form, in build order: patient name, phone,
/// hospital address. Positional indexing because `SolovvoTextField` uppercases
/// its own label inside its `Text` child, so `find.widgetWithText` against the
/// raw l10n label would fail on a case mismatch the design system owns.
Finder _field(int index) => find.byType(TextField).at(index);

Finder get _submit => find.widgetWithText(
  SolovvoButton,
  english.requestsContactSubmit,
);

Future<void> _pumpForm(
  WidgetTester tester,
  BloodRequest request, {
  Locale locale = const Locale('en'),
  Size size = _phone,
  FakeRequestContactService? contactService,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  // Always overridden: unlike the pure-write sibling forms, this screen reads
  // the contact provider on open (initState), so a test that left it
  // unoverridden would resolve the real Firestore-backed default and throw
  // "No Firebase App". The default fake returns no saved contact, i.e. the
  // first-capture blank form, which is what the tests that pass no service want.
  final ProviderContainer container = ProviderContainer(
    overrides: [
      requestContactServiceProvider.overrideWithValue(
        contactService ?? FakeRequestContactService(),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: testApp(
        locale: locale,
        home: RequestContactScreen(request: request),
      ),
    ),
  );
  // Settle the opening load. With the default fake (no `loadGate`) the read
  // resolves immediately, so this lands in the ready form rather than the
  // transient loading spinner. The loading-state test passes `settle: false`,
  // because an indeterminate progress indicator animates forever and would
  // hang `pumpAndSettle`.
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  group('RequestContactScreen', () {
    testWidgets('titles the app bar with the contact copy', (
      WidgetTester tester,
    ) async {
      await _pumpForm(tester, fakeRequest());

      expect(find.text(english.requestsContactTitle), findsOneWidget);
    });

    testWidgets('shows a loading state while the contact read is in flight', (
      WidgetTester tester,
    ) async {
      // The read must be observable: the form is a read-then-write, and the
      // safety of the whole increment depends on the save being unavailable
      // until the read has landed.
      final FakeRequestContactService service = FakeRequestContactService()
        ..loadGate = Completer<void>();
      await _pumpForm(
        tester,
        fakeRequest(),
        contactService: service,
        settle: false,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // No save affordance yet — the owner cannot overwrite what has not been
      // read back.
      expect(_submit, findsNothing);

      service.loadGate!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(_submit, findsOneWidget);
    });

    testWidgets('opens blank when there is no saved contact yet', (
      WidgetTester tester,
    ) async {
      // The first-capture case: `loadContact` returns a null value (document
      // absent), which is a ready-and-blank form, not a failure.
      final FakeRequestContactService service = FakeRequestContactService();
      await _pumpForm(
        tester,
        fakeRequest(id: 'req-blank', hospitalName: 'Not Shown Here'),
        contactService: service,
      );

      expect(tester.widget<TextField>(_field(0)).controller!.text, isEmpty);
      expect(tester.widget<TextField>(_field(1)).controller!.text, isEmpty);
      expect(tester.widget<TextField>(_field(2)).controller!.text, isEmpty);
      // The public hospital name is not echoed into a PII field, and the read
      // targeted this request's id.
      expect(find.text('Not Shown Here'), findsNothing);
      expect(service.loadCalls, <String>['req-blank']);
    });

    testWidgets('pre-fills the three fields from the owner saved contact', (
      WidgetTester tester,
    ) async {
      // The point of this increment: the owner can now see what they stored,
      // not only write it. A bug that dropped the pre-fill would let a save
      // silently blank a real phone number, so each field is asserted against
      // the fetched value.
      final FakeRequestContactService service = FakeRequestContactService()
        ..nextContact = const RequestContact(
          patientName: 'Rahim Uddin',
          phoneNumber: '+8801700000000',
          hospitalAddress: 'Dhaka Medical, Room 12',
        );
      await _pumpForm(tester, fakeRequest(id: 'req-fill'), contactService: service);

      expect(tester.widget<TextField>(_field(0)).controller!.text, 'Rahim Uddin');
      expect(
        tester.widget<TextField>(_field(1)).controller!.text,
        '+8801700000000',
      );
      expect(
        tester.widget<TextField>(_field(2)).controller!.text,
        'Dhaka Medical, Room 12',
      );
    });

    testWidgets('a read failure offers retry and no save', (
      WidgetTester tester,
    ) async {
      // The safety story of the increment: `saveContact` replaces all three keys,
      // so a blank form over a contact the read merely *failed to fetch* would
      // erase real PII. A failure therefore blocks the save and offers a retry.
      final FakeRequestContactService service = FakeRequestContactService()
        ..loadFailure = const PermissionFailure(
          debugMessage: 'test: rules refused the contact read',
        );
      await _pumpForm(tester, fakeRequest(), contactService: service);

      expect(find.text(english.requestsContactLoadError), findsOneWidget);
      expect(_submit, findsNothing);
      expect(
        find.widgetWithText(SolovvoButton, english.requestsContactRetry),
        findsOneWidget,
      );
      expect(service.calls, isEmpty);
    });

    testWidgets('retry re-reads and, once it succeeds, opens the form', (
      WidgetTester tester,
    ) async {
      final FakeRequestContactService service = FakeRequestContactService()
        ..loadFailure = const NetworkFailure(
          debugMessage: 'test: first read failed',
        );
      await _pumpForm(tester, fakeRequest(), contactService: service);
      expect(service.loadCalls, hasLength(1));

      // The transient failure clears; a retry should land in the ready form.
      service.loadFailure = null;
      service.nextContact = const RequestContact(
        patientName: 'Karim',
        phoneNumber: '01700',
        hospitalAddress: '',
      );

      await tester.tap(
        find.widgetWithText(SolovvoButton, english.requestsContactRetry),
      );
      await tester.pumpAndSettle();

      expect(service.loadCalls, hasLength(2));
      expect(_submit, findsOneWidget);
      expect(tester.widget<TextField>(_field(0)).controller!.text, 'Karim');
    });

    testWidgets('renders the three fields and the privacy intro', (
      WidgetTester tester,
    ) async {
      await _pumpForm(tester, fakeRequest());

      expect(find.byType(SolovvoTextField), findsNWidgets(3));
      expect(
        find.text(english.requestsPatientName.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(english.requestsPhoneNumber.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(english.requestsHospitalAddress.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text(english.requestsContactIntro), findsOneWidget);
      expect(_submit, findsOneWidget);
    });

    testWidgets('a submit sends all three keys, empty address included', (
      WidgetTester tester,
    ) async {
      // The rule requires the three keys present (`hasAll`) but lets the address
      // be an empty string. Omitting a blank address would produce a two-key
      // document the rules refuse, so the empty field must still be sent.
      final FakeRequestContactService service = FakeRequestContactService();
      await _pumpForm(
        tester,
        fakeRequest(id: 'req-send'),
        contactService: service,
      );

      await tester.enterText(_field(0), 'Rahim Uddin');
      await tester.enterText(_field(1), '+8801700000000');
      await tester.enterText(_field(2), '');
      await tester.pump();

      await tester.tap(_submit);
      await tester.pumpAndSettle();

      expect(service.calls, hasLength(1));
      final (String requestId, String name, String phone, String address) =
          service.calls.first;
      expect(requestId, 'req-send');
      expect(name, 'Rahim Uddin');
      expect(phone, '+8801700000000');
      expect(address, '');
    });

    testWidgets('an empty patient name fails validation, not the network', (
      WidgetTester tester,
    ) async {
      final FakeRequestContactService service = FakeRequestContactService();
      await _pumpForm(tester, fakeRequest(), contactService: service);

      await tester.enterText(_field(1), '01700');
      await tester.pump();
      await tester.tap(_submit);
      await tester.pump();

      expect(
        find.text(
          '${english.requestsPatientName}: ${english.requestsRequired}',
        ),
        findsOneWidget,
      );
      expect(service.calls, isEmpty);
    });

    testWidgets('an empty phone fails validation once the name is filled', (
      WidgetTester tester,
    ) async {
      final FakeRequestContactService service = FakeRequestContactService();
      await _pumpForm(tester, fakeRequest(), contactService: service);

      await tester.enterText(_field(0), 'Karim');
      await tester.enterText(_field(1), '   ');
      await tester.pump();
      await tester.tap(_submit);
      await tester.pump();

      expect(
        find.text(
          '${english.requestsPhoneNumber}: ${english.requestsRequired}',
        ),
        findsOneWidget,
      );
      expect(service.calls, isEmpty);
    });

    testWidgets('a save failure surfaces the copy and keeps the form open', (
      WidgetTester tester,
    ) async {
      final FakeRequestContactService service = FakeRequestContactService()
        ..failure = const PermissionFailure(
          debugMessage: 'test: rules refused the contact write',
        );
      await _pumpForm(tester, fakeRequest(), contactService: service);

      await tester.enterText(_field(0), 'A');
      await tester.enterText(_field(1), '1');
      await tester.pump();
      await tester.tap(_submit);
      await tester.pumpAndSettle();

      expect(find.byType(RequestContactScreen), findsOneWidget);
      expect(find.text(english.requestsContactError), findsOneWidget);
      expect(service.calls, hasLength(1));
    });

    testWidgets('a successful submit pops with the request id', (
      WidgetTester tester,
    ) async {
      final FakeRequestContactService service = FakeRequestContactService();
      final BloodRequest r = fakeRequest(id: 'req-pop');

      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final ProviderContainer container = ProviderContainer(
        overrides: [
          requestContactServiceProvider.overrideWithValue(service),
        ],
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
        RequestContactScreen.route(r),
      );
      await tester.pumpAndSettle();

      await tester.enterText(_field(0), 'A');
      await tester.enterText(_field(1), '1');
      await tester.pump();
      await tester.tap(_submit);
      await tester.pumpAndSettle();

      expect(await popped, 'req-pop');
      expect(find.byType(RequestContactScreen), findsNothing);
    });

    testWidgets('a submit in flight disables the button and shows "Saving…"', (
      WidgetTester tester,
    ) async {
      final FakeRequestContactService service = FakeRequestContactService()
        ..gate = Completer<void>();
      await _pumpForm(tester, fakeRequest(), contactService: service);

      await tester.enterText(_field(0), 'A');
      await tester.enterText(_field(1), '1');
      await tester.pump();

      final Finder submitButton = find.byType(SolovvoButton);
      await tester.tap(submitButton);
      await tester.pump();

      expect(find.text(english.requestsContactSaving), findsOneWidget);
      expect(service.calls, hasLength(1));

      await tester.tap(submitButton);
      await tester.pump();
      expect(service.calls, hasLength(1));

      service.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('renders the whole form in Bangla', (
      WidgetTester tester,
    ) async {
      await _pumpForm(tester, fakeRequest(), locale: const Locale('bn'));

      expect(find.text(bangla.requestsContactTitle), findsOneWidget);
      expect(
        find.text(bangla.requestsPatientName.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(SolovvoButton, bangla.requestsContactSubmit),
        findsOneWidget,
      );
      expect(find.text(english.requestsContactTitle), findsNothing);
    });

    testWidgets('a validation error is worded in Bangla too', (
      WidgetTester tester,
    ) async {
      await _pumpForm(tester, fakeRequest(), locale: const Locale('bn'));

      await tester.tap(
        find.widgetWithText(SolovvoButton, bangla.requestsContactSubmit),
      );
      await tester.pump();

      expect(
        find.text('${bangla.requestsPatientName}: ${bangla.requestsRequired}'),
        findsOneWidget,
      );
    });

    testWidgets('a read failure is worded in Bangla too', (
      WidgetTester tester,
    ) async {
      final FakeRequestContactService service = FakeRequestContactService()
        ..loadFailure = const NetworkFailure(debugMessage: 'test');
      await _pumpForm(
        tester,
        fakeRequest(),
        locale: const Locale('bn'),
        contactService: service,
      );

      expect(find.text(bangla.requestsContactLoadError), findsOneWidget);
      expect(
        find.widgetWithText(SolovvoButton, bangla.requestsContactRetry),
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
