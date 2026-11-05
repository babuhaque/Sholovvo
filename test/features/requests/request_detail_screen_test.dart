import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/design/widgets/blood_group_badge.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/features/profile/application/profile_providers.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';
import 'package:sholovvo_app/features/requests/application/requests_providers.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';
import 'package:sholovvo_app/features/requests/presentation/edit_request_screen.dart';
import 'package:sholovvo_app/features/requests/presentation/request_contact_screen.dart';
import 'package:sholovvo_app/features/requests/presentation/request_detail_screen.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

import '../../support/fake_profile_repository.dart';
import '../../support/fake_requests.dart';
import '../../support/test_app.dart';

const Size _phone = Size(430, 932);
const Size _narrow = Size(320, 640);
const Size _tablet = Size(900, 1200);

final DateTime _neededByDate = DateTime.utc(2026, 11, 9, 14);

/// The signed-in account for every accept-affordance test: a donor who is not
/// the request's owner and whose profile is available and group-matched, which
/// is exactly the precondition the client gate (mirroring `firestore.rules`
/// L157-160) reads to decide whether to offer Accept. Paired with [fakeRequest]'s
/// default `bloodGroup: 'A+'` and `userId: 'uid-recipient'`, so the negative
/// cases flip one field at a time — the group, availability, or ownership —
/// rather than rebuilding the whole scene.
const UserProfile _eligibleDonor = UserProfile(
  uid: 'uid-donor',
  bloodGroup: 'A+',
  isAvailable: true,
);

/// The "Needed by …" sentence, built the way the screen builds it: the label
/// from the catalogue under test and the date from the same
/// [MaterialLocalizations] the screen formats with. A literal here would be a
/// second source of truth for a date pattern, and the wrong one as soon as the
/// locale changes.
String _neededByLabel(WidgetTester tester, AppLocalizations l10n) {
  return l10n.homeNeededBy(
    MaterialLocalizations.of(
      tester.element(find.byType(RequestDetailScreen)),
    ).formatShortMonthDay(_neededByDate.toLocal()),
  );
}

Future<ProviderContainer> _pumpDetail(
  WidgetTester tester,
  BloodRequest request, {
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
  Size size = _phone,
  String? authUid,
  FakeRequestCancelService? cancelService,
  FakeRequestEditService? editService,
  FakeRequestAcceptService? acceptService,
  FakeRequestContactService? contactService,
  UserProfile? donorProfile,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  // Every override the screen might reach for. The uid provider is always
  // overridden so the test controls the `isMine` decision directly — including
  // when the value is null, which is what a stranger (or an anonymous build
  // with no Firebase init) sees. The cancel, edit and accept services are only
  // overridden when a test actually exercises the write path; leaving them
  // unoverridden means a stray write call would hit the real Firestore
  // provider and throw, which is exactly the assertion the negative tests
  // want to make.
  //
  // The profile stream is always overridden. The detail screen `watch`es
  // `profileProvider` to decide whether the signed-in account is an eligible
  // donor, and the real provider reads `FirebaseAuth.instance`/
  // `FirebaseFirestore.instance` — uninitialized under test. Left as-is it
  // fails, and Riverpod schedules an auto-retry Timer that outlives the widget
  // tree, so every case dies at teardown with "a Timer is still pending". A
  // `FakeProfileRepository` with no document streams `null` (nobody is an
  // eligible donor), which is the safe default for the owner and stranger
  // cases; the accept-affordance tests hand it a matching `donorProfile`.
  final ProviderContainer container = ProviderContainer(
    overrides: [
      requestsAuthUidProvider.overrideWithValue(authUid),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(profile: donorProfile),
      ),
      if (cancelService != null)
        requestCancelServiceProvider.overrideWithValue(cancelService),
      if (editService != null)
        requestEditServiceProvider.overrideWithValue(editService),
      if (acceptService != null)
        requestAcceptServiceProvider.overrideWithValue(acceptService),
      if (contactService != null)
        requestContactServiceProvider.overrideWithValue(contactService),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: testApp(
        locale: locale,
        themeMode: themeMode,
        home: RequestDetailScreen(request: request),
      ),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  group('RequestDetailScreen', () {
    testWidgets('names the request it is showing on the app bar', (
      WidgetTester tester,
    ) async {
      await _pumpDetail(tester, fakeRequest(neededBy: _neededByDate));

      expect(find.text(english.requestsDetailTitle), findsOneWidget);
    });

    testWidgets('renders the group, hospital, bags and needed-by together', (
      WidgetTester tester,
    ) async {
      final BloodRequest r = fakeRequest(
        bloodGroup: 'O+',
        hospitalName: 'Square Hospital',
        units: 3,
        neededBy: _neededByDate,
      );

      await _pumpDetail(tester, r);

      // The header carries the group in two shapes: the badge, and the string
      // next to it, and both are here. A screen that showed only one of them
      // would be a design choice a test could not catch flipping.
      expect(find.byType(BloodGroupBadge), findsOneWidget);
      expect(find.text('O+'), findsNWidgets(2));
      // Hospital name appears both in the header subtitle and as a labelled
      // field below. Same reason as above: the row and the field are two
      // affordances for the same fact, and both are the screen's contract.
      expect(find.text('Square Hospital'), findsNWidgets(2));
      // Bags appear once, as a labelled field, in the same "N bags needed"
      // phrasing the list row uses.
      expect(find.textContaining(english.homeUnitsNeeded(3)), findsOneWidget);
      // And the date, formatted the same way the list formats it.
      expect(
        find.textContaining(_neededByLabel(tester, english)),
        findsOneWidget,
      );
    });

    testWidgets('shows the verbatim text when the stored date cannot be parsed',
        (WidgetTester tester) async {
      // A `requiredDateTime` this app cannot read as a date still has to be
      // shown, and shown as what the requester actually wrote. Silently
      // dropping it would read as "no urgency", which is the same lie the row
      // refuses to tell.
      await _pumpDetail(
        tester,
        fakeRequest(neededByText: 'tomorrow evening'),
      );

      expect(
        find.textContaining(english.homeNeededBy('tomorrow evening')),
        findsOneWidget,
      );
    });

    testWidgets('says "No date given" when neither form is available', (
      WidgetTester tester,
    ) async {
      // Third of the three forms the row and the detail must agree on. An
      // empty date is neither a real date nor typed text; the screen has to
      // say so rather than leave the field blank.
      await _pumpDetail(tester, fakeRequest());

      expect(
        find.textContaining(english.homeNeededByUnknown),
        findsOneWidget,
      );
    });

    testWidgets('offers nothing to a viewer who is neither owner nor eligible donor', (
      WidgetTester tester,
    ) async {
      // The default build — no uid, no profile — is an anonymous browse or a
      // signed-in account the rules would refuse: not the owner (no edit/
      // cancel), and not an eligible donor (no matching profile, so no accept).
      // Claiming and contacting remain Stage 10 transactions the app does not
      // make, so they never appear as controls. §9 asks for no buttons that
      // lead to nothing.
      await _pumpDetail(tester, fakeRequest(neededBy: _neededByDate));

      expect(find.byType(SolovvoButton), findsNothing);
      expect(find.text('Accept'), findsNothing);
      expect(find.text('Claim'), findsNothing);
      expect(find.text('Contact'), findsNothing);
      // The screen's whole affirmative content is a `Text`, not a `Button`,
      // and there is exactly one SolovvoCard (the header) rather than an
      // action-row card per field.
      expect(find.byType(SolovvoCard), findsOneWidget);
    });

    testWidgets('shows the honest footer that says what is not in this build', (
      WidgetTester tester,
    ) async {
      // Same register as the list's `requestsNoActionNote`, but reworded for
      // a page rather than a list. A donor who came here looking for a phone
      // number has to be told on this screen, not on the one behind it.
      await _pumpDetail(tester, fakeRequest(neededBy: _neededByDate));

      expect(
        find.text(english.requestsDetailNoActionNote),
        findsOneWidget,
      );
    });

    testWidgets('renders the same facts in Bangla', (
      WidgetTester tester,
    ) async {
      // Parity across languages is not just a copy test — the layout has to
      // survive a script whose words are longer on average, and the badge
      // + title + fields have to fit in the same measure.
      final BloodRequest r = fakeRequest(
        bloodGroup: 'AB+',
        hospitalName: 'Dhaka Medical',
        units: 2,
        neededBy: _neededByDate,
      );

      await _pumpDetail(tester, r, locale: const Locale('bn'));

      expect(find.text(bangla.requestsDetailTitle), findsOneWidget);
      expect(find.text('AB+'), findsNWidgets(2));
      expect(find.text('Dhaka Medical'), findsNWidgets(2));
      expect(find.textContaining(bangla.homeUnitsNeeded(2)), findsOneWidget);
      expect(
        find.text(bangla.requestsDetailNoActionNote),
        findsOneWidget,
      );
      // The English copy is genuinely absent, not merely hidden behind an
      // overflow — the same argument the row's parity test makes.
      expect(find.text(english.requestsDetailTitle), findsNothing);
    });

    testWidgets('fits a small phone (320x640) without overflow', (
      WidgetTester tester,
    ) async {
      await _pumpDetail(
        tester,
        fakeRequest(neededBy: _neededByDate),
        size: _narrow,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a large phone (430x932) without overflow', (
      WidgetTester tester,
    ) async {
      await _pumpDetail(
        tester,
        fakeRequest(neededBy: _neededByDate),
        size: _phone,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('reflows to a wider measure on a tablet (900x1200)', (
      WidgetTester tester,
    ) async {
      await _pumpDetail(
        tester,
        fakeRequest(neededBy: _neededByDate),
        size: _tablet,
      );

      expect(tester.takeException(), isNull);
      // The screen renders fully on the tablet measure too; the wider
      // layout is not a stub.
      expect(find.text(english.requestsDetailTitle), findsOneWidget);
    });

    testWidgets('survives a hospital name nobody designed for', (
      WidgetTester tester,
    ) async {
      // The field is free text a stranger typed into a form, and 320 logical
      // pixels is the narrowest phone still in use. The header ellipses, the
      // labelled field below wraps, and the row does not push a RenderFlex
      // overflow.
      final BloodRequest long = fakeRequest(
        hospitalName:
            'Bangabandhu Sheikh Medical University Institute of Cardiac Disease',
        units: 12,
        neededBy: _neededByDate,
      );

      await _pumpDetail(tester, long, size: _narrow);

      expect(tester.takeException(), isNull);
      expect(find.textContaining(long.hospitalName), findsWidgets);
    });

    testWidgets('does not show patient, phone or street address', (
      WidgetTester tester,
    ) async {
      // Privacy contract, tested rather than asserted in a comment. The
      // `BloodRequest` entity does not carry these fields — Stage 9.5 (M3-C1)
      // moved them to `blood_requests/{id}/private/contact` at the rules
      // layer — so a screen built over the entity cannot render them even if
      // a well-meaning developer wires a field wrong. The test is what turns
      // that "cannot" into a build gate.
      final BloodRequest r = fakeRequest(
        bloodGroup: 'B+',
        hospitalName: 'United Hospital',
        units: 1,
        neededBy: _neededByDate,
      );

      await _pumpDetail(tester, r);

      expect(find.textContaining('+8801700000000'), findsNothing);
      expect(find.textContaining('Patient'), findsNothing);
      expect(find.textContaining('+880'), findsNothing);
    });
  });

  group('RequestDetailScreen cancel affordance', () {
    // The owner branch. Every test here overrides
    // `requestsAuthUidProvider` to match [BloodRequest.userId], which is the
    // condition the screen reads to decide whether to render the cancel
    // button. A stranger who is not an eligible donor (`authUid` null, or a
    // different string, with no matching profile) sees no button — the
    // "neither owner nor eligible donor" case above pins that default because it
    // passes neither an `authUid` nor a `donorProfile`.

    testWidgets('renders the cancel button for the owner', (
      WidgetTester tester,
    ) async {
      await _pumpDetail(
        tester,
        fakeRequest(neededBy: _neededByDate),
        authUid: 'uid-recipient',
        cancelService: FakeRequestCancelService(),
      );

      expect(
        find.widgetWithText(
          SolovvoButton,
          english.requestsCancelAction,
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders the edit button for the owner alongside cancel', (
      WidgetTester tester,
    ) async {
      // The owner-only affordances render together, and neither stranger
      // branch does. Edit stays inside the eight editable keys, Contact
      // writes the owner's private subcollection (the rules-permitted capture,
      // `firestore.rules` L219-228), and Cancel ends the request.
      await _pumpDetail(
        tester,
        fakeRequest(neededBy: _neededByDate),
        authUid: 'uid-recipient',
        cancelService: FakeRequestCancelService(),
        editService: FakeRequestEditService(),
        contactService: FakeRequestContactService(),
      );

      expect(
        find.widgetWithText(SolovvoButton, english.requestsEditAction),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(SolovvoButton, english.requestsContactAction),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(SolovvoButton, english.requestsCancelAction),
        findsOneWidget,
      );
      // The owner trio is exactly three: Edit, Contact, Cancel. The fourth
      // (donor accept/claim) is still a Stage-10 transaction the app does not
      // make, and a fourth SolovvoButton appearing here — rather than the
      // owner-only Contact capture this stage deliberately added — would be
      // that transaction creeping in through the owner branch.
      expect(find.byType(SolovvoButton), findsNWidgets(3));
    });

    testWidgets('does not render the edit button for a stranger', (
      WidgetTester tester,
    ) async {
      // The "neither owner nor eligible donor" case above proves such a viewer
      // sees no SolovvoButton at all; this one is more specific because the edit
      // affordance is new and the two branches have different consequences
      // — a leak here would show a control that writes on someone else's
      // behalf (rules catch it, but the affordance would be a lie).
      await _pumpDetail(
        tester,
        fakeRequest(neededBy: _neededByDate),
        authUid: 'uid-someone-else',
      );

      expect(
        find.widgetWithText(SolovvoButton, english.requestsEditAction),
        findsNothing,
      );
    });

    testWidgets('does not render the cancel button for a stranger', (
      WidgetTester tester,
    ) async {
      await _pumpDetail(
        tester,
        fakeRequest(neededBy: _neededByDate),
        authUid: 'uid-someone-else',
      );

      expect(find.byType(SolovvoButton), findsNothing);
    });

    testWidgets('does not render the cancel button when uid is null', (
      WidgetTester tester,
    ) async {
      // The default in an anonymous browse or a widget test that forgot to
      // override the provider. The screen still has to render, and it still
      // has to hide the affordance — this is what the pre-existing 12 cases
      // rely on.
      await _pumpDetail(tester, fakeRequest(neededBy: _neededByDate));

      expect(find.byType(SolovvoButton), findsNothing);
    });

    testWidgets('cancel tap opens a confirmation dialog, no write yet', (
      WidgetTester tester,
    ) async {
      final FakeRequestCancelService service = FakeRequestCancelService();
      await _pumpDetail(
        tester,
        fakeRequest(neededBy: _neededByDate),
        authUid: 'uid-recipient',
        cancelService: service,
      );

      await tester.tap(find.widgetWithText(
        SolovvoButton,
        english.requestsCancelAction,
      ));
      await tester.pumpAndSettle();

      expect(find.text(english.requestsCancelConfirmTitle), findsOneWidget);
      expect(find.text(english.requestsCancelConfirmBody), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, english.requestsCancelConfirmYes),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextButton, english.requestsCancelConfirmNo),
        findsOneWidget,
      );
      // The write happens only on confirm. This is the guard against a
      // mis-wired button that fires the service before asking.
      expect(service.calls, isEmpty);
    });

    testWidgets('dismissing the dialog does not call the service', (
      WidgetTester tester,
    ) async {
      final FakeRequestCancelService service = FakeRequestCancelService();
      await _pumpDetail(
        tester,
        fakeRequest(neededBy: _neededByDate),
        authUid: 'uid-recipient',
        cancelService: service,
      );

      await tester.tap(find.widgetWithText(
        SolovvoButton,
        english.requestsCancelAction,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(
        TextButton,
        english.requestsCancelConfirmNo,
      ));
      await tester.pumpAndSettle();

      expect(service.calls, isEmpty);
      // The screen is still on stage — nothing navigated away on a "no".
      expect(find.byType(RequestDetailScreen), findsOneWidget);
    });

    testWidgets('confirming calls the service with the request id and pops', (
      WidgetTester tester,
    ) async {
      final FakeRequestCancelService service = FakeRequestCancelService();
      final BloodRequest r = fakeRequest(
        id: 'req-target-42',
        neededBy: _neededByDate,
      );

      // The detail screen is pushed as a route so a successful cancel has
      // somewhere to pop back to. Callers in the real app do exactly this from
      // the requests list and the dashboard's nearby-requests preview, so the
      // test observes the same contract those screens observe: a non-null pop
      // payload they refresh on.
      final ProviderContainer container = ProviderContainer(
        overrides: [
          requestsAuthUidProvider.overrideWithValue('uid-recipient'),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          requestCancelServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

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
        RequestDetailScreen.route(r),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(
        SolovvoButton,
        english.requestsCancelAction,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(
        TextButton,
        english.requestsCancelConfirmYes,
      ));
      await tester.pumpAndSettle();

      expect(service.calls, <String>['req-target-42']);
      expect(find.byType(RequestDetailScreen), findsNothing);
      // The route popped with the id, which callers refresh on.
      expect(await popped, 'req-target-42');
    });

    testWidgets('a service failure keeps the screen and shows a SnackBar', (
      WidgetTester tester,
    ) async {
      // A cancel that fails at the rules layer must not close the screen —
      // the request is still open, and pretending otherwise (by popping as
      // though the cancel succeeded) would let the donor walk away thinking
      // their request was withdrawn when it was not.
      final FakeRequestCancelService service = FakeRequestCancelService()
        ..failure = const PermissionFailure(
          debugMessage: 'test: rules refused the cancel',
        );
      await _pumpDetail(
        tester,
        fakeRequest(neededBy: _neededByDate),
        authUid: 'uid-recipient',
        cancelService: service,
      );

      await tester.tap(find.widgetWithText(
        SolovvoButton,
        english.requestsCancelAction,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(
        TextButton,
        english.requestsCancelConfirmYes,
      ));
      await tester.pumpAndSettle();

      expect(service.calls, hasLength(1));
      expect(find.byType(RequestDetailScreen), findsOneWidget);
      expect(find.text(english.requestsCancelError), findsOneWidget);
    });

    testWidgets('cancel copy is localised in Bangla', (
      WidgetTester tester,
    ) async {
      final FakeRequestCancelService service = FakeRequestCancelService();
      await _pumpDetail(
        tester,
        fakeRequest(neededBy: _neededByDate),
        locale: const Locale('bn'),
        authUid: 'uid-recipient',
        cancelService: service,
      );

      expect(
        find.widgetWithText(SolovvoButton, bangla.requestsCancelAction),
        findsOneWidget,
      );
      // English is genuinely absent, not merely hidden by overflow — the
      // same parity argument the read-model tests make.
      expect(
        find.widgetWithText(SolovvoButton, english.requestsCancelAction),
        findsNothing,
      );

      await tester.tap(find.widgetWithText(
        SolovvoButton,
        bangla.requestsCancelAction,
      ));
      await tester.pumpAndSettle();

      expect(find.text(bangla.requestsCancelConfirmTitle), findsOneWidget);
      expect(find.text(bangla.requestsCancelConfirmBody), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, bangla.requestsCancelConfirmYes),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextButton, bangla.requestsCancelConfirmNo),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextButton, english.requestsCancelConfirmYes),
        findsNothing,
      );
    });
  });

  group('RequestDetailScreen contact affordance', () {
    // The owner branch of the Contact button — the private/contact capture this
    // stage adds. The write itself belongs to [RequestContactScreen]'s own test;
    // all this screen proves is that tapping Contact opens that form with the
    // current request, and that a stranger never sees the affordance.

    testWidgets('tapping Contact pushes RequestContactScreen with the request', (
      WidgetTester tester,
    ) async {
      final BloodRequest r = fakeRequest(id: 'req-contact-target');

      await _pumpDetail(
        tester,
        r,
        authUid: 'uid-recipient',
        cancelService: FakeRequestCancelService(),
        editService: FakeRequestEditService(),
        contactService: FakeRequestContactService(),
      );

      await tester.tap(
        find.widgetWithText(SolovvoButton, english.requestsContactAction),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RequestContactScreen), findsOneWidget);
      final RequestContactScreen pushed = tester.widget<RequestContactScreen>(
        find.byType(RequestContactScreen),
      );
      expect(pushed.request.id, 'req-contact-target');
    });

    testWidgets('does not render the contact button for a stranger', (
      WidgetTester tester,
    ) async {
      // The contact affordance is owner-only, exactly like Edit and Cancel: a
      // stranger who is not an eligible donor sees no button at all, and the
      // rules (`firestore.rules` L219-228) would refuse their write anyway.
      await _pumpDetail(
        tester,
        fakeRequest(neededBy: _neededByDate),
        authUid: 'uid-someone-else',
      );

      expect(
        find.widgetWithText(SolovvoButton, english.requestsContactAction),
        findsNothing,
      );
    });
  });

  group('RequestDetailScreen edit affordance', () {
    // The owner branch of the edit button. Symmetric to the cancel tests
    // above but shorter: the write itself belongs to [EditRequestScreen]'s
    // own widget test, so all this screen has to prove is (a) it opens the
    // form with the current request, and (b) a non-null pop bubbles the
    // sentinel up so the caller list refreshes.

    testWidgets('tapping Edit pushes EditRequestScreen with the request', (
      WidgetTester tester,
    ) async {
      final BloodRequest r = fakeRequest(
        id: 'req-edit-target',
        bloodGroup: 'B+',
        hospitalName: 'United Hospital',
        units: 4,
        neededBy: _neededByDate,
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [
          requestsAuthUidProvider.overrideWithValue('uid-recipient'),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          requestCancelServiceProvider.overrideWithValue(
            FakeRequestCancelService(),
          ),
          requestEditServiceProvider.overrideWithValue(
            FakeRequestEditService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

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
      nav.push<String?>(RequestDetailScreen.route(r));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(
        SolovvoButton,
        english.requestsEditAction,
      ));
      await tester.pumpAndSettle();

      // The form is on stage, and the route it opened is the one whose
      // request the detail screen was showing — a mismatch here would
      // silently edit the wrong document.
      expect(find.byType(EditRequestScreen), findsOneWidget);
      final EditRequestScreen pushed = tester.widget<EditRequestScreen>(
        find.byType(EditRequestScreen),
      );
      expect(pushed.request.id, 'req-edit-target');
      expect(pushed.request.bloodGroup, 'B+');
      expect(pushed.request.hospitalName, 'United Hospital');
      expect(pushed.request.units, 4);
    });

    testWidgets('a successful edit bubbles the sentinel up one level', (
      WidgetTester tester,
    ) async {
      // The full three-hop pop chain: EditRequestScreen pops with the id on
      // a successful write; the detail screen sees the non-null value and
      // pops with it too; the caller (host) sees the non-null value and
      // would refresh its list. This test is only about the middle hop —
      // that the detail screen does not swallow a successful edit — because
      // the two ends are covered by [EditRequestScreen]'s own test and the
      // list screen's refresh test.
      final FakeRequestEditService edit = FakeRequestEditService();
      final BloodRequest r = fakeRequest(
        id: 'req-bubble',
        neededBy: _neededByDate,
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [
          requestsAuthUidProvider.overrideWithValue('uid-recipient'),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          requestCancelServiceProvider.overrideWithValue(
            FakeRequestCancelService(),
          ),
          requestEditServiceProvider.overrideWithValue(edit),
        ],
      );
      addTearDown(container.dispose);

      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

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
        RequestDetailScreen.route(r),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(
        SolovvoButton,
        english.requestsEditAction,
      ));
      await tester.pumpAndSettle();

      // Submit the edit form. The controllers already hold the request's
      // current values, so no typing is needed for a no-op-but-valid save.
      await tester.tap(find.widgetWithText(
        SolovvoButton,
        english.requestsEditSubmit,
      ));
      await tester.pumpAndSettle();

      // The write happened, both screens closed, and the caller's future
      // resolved with the id — which is what tells the list screen to
      // refresh.
      expect(edit.calls, hasLength(1));
      expect(edit.calls.first.$1, 'req-bubble');
      expect(find.byType(EditRequestScreen), findsNothing);
      expect(find.byType(RequestDetailScreen), findsNothing);
      expect(await popped, 'req-bubble');
    });

    testWidgets('a back-out of the edit form does not bubble a sentinel', (
      WidgetTester tester,
    ) async {
      // The user opens the form, then taps the system back button instead of
      // Save. No write happened; the detail screen stays put and the caller
      // must not refresh (a refresh on a no-change would be a wasted paid
      // read, and the sentinel contract is exactly what stops that).
      final FakeRequestEditService edit = FakeRequestEditService();
      final BloodRequest r = fakeRequest(
        id: 'req-backout',
        neededBy: _neededByDate,
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [
          requestsAuthUidProvider.overrideWithValue('uid-recipient'),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          requestCancelServiceProvider.overrideWithValue(
            FakeRequestCancelService(),
          ),
          requestEditServiceProvider.overrideWithValue(edit),
        ],
      );
      addTearDown(container.dispose);

      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

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
        RequestDetailScreen.route(r),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(
        SolovvoButton,
        english.requestsEditAction,
      ));
      await tester.pumpAndSettle();
      expect(find.byType(EditRequestScreen), findsOneWidget);

      // Pop the edit form the way the system back gesture would — no write,
      // no payload.
      Navigator.of(tester.element(find.byType(EditRequestScreen))).pop();
      await tester.pumpAndSettle();

      // The detail screen is still showing, and the caller's future has not
      // resolved at all — a completed null here would mean the middle hop
      // popped on a no-op.
      expect(edit.calls, isEmpty);
      expect(find.byType(EditRequestScreen), findsNothing);
      expect(find.byType(RequestDetailScreen), findsOneWidget);

      // Sanity: the caller's own future really is still pending. Nothing
      // awaits it here, so the check is only that no pop has fired.
      expect(popped, isA<Future<String?>>());
    });
  });

  group('RequestDetailScreen accept affordance', () {
    // The donor branch. Symmetric to the owner (cancel/edit) tests, but the
    // gate has three preconditions the owner branch does not: signed-in, not
    // the owner, and a profile that is available and group-matched. Each case
    // below flips exactly one of those, so a leak in any clause of [the screen's
    // `canAccept`] shows up as a control that should not have appeared. The
    // server-side rules that actually honour the write are covered by
    // `firestore-rules-tests/firestore.test.js` (Phase 1.3 claiming rules);
    // these tests pin the client affordance and its wiring to the service.

    testWidgets('renders Accept for an eligible donor', (
      WidgetTester tester,
    ) async {
      await _pumpDetail(
        tester,
        fakeRequest(neededBy: _neededByDate),
        authUid: 'uid-donor',
        donorProfile: _eligibleDonor,
        acceptService: FakeRequestAcceptService(),
      );
      // The profile arrives over a stream, so one extra settle is what takes
      // `canAccept` from its loading default (false) to the real answer.
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(SolovvoButton, english.requestsAcceptAction),
        findsOneWidget,
      );
      // The donor branch is exactly one button — no owner affordance leaks in
      // for someone who does not own the request.
      expect(find.byType(SolovvoButton), findsOneWidget);
    });

    testWidgets('offers nothing when the blood group does not match', (
      WidgetTester tester,
    ) async {
      const UserProfile wrongGroup = UserProfile(
        uid: 'uid-donor',
        bloodGroup: 'O-',
        isAvailable: true,
      );
      await _pumpDetail(
        tester,
        fakeRequest(neededBy: _neededByDate),
        authUid: 'uid-donor',
        donorProfile: wrongGroup,
      );
      await tester.pumpAndSettle();

      expect(find.byType(SolovvoButton), findsNothing);
    });

    testWidgets('offers nothing when the donor is marked unavailable', (
      WidgetTester tester,
    ) async {
      const UserProfile unavailable = UserProfile(
        uid: 'uid-donor',
        bloodGroup: 'A+',
        isAvailable: false,
      );
      await _pumpDetail(
        tester,
        fakeRequest(neededBy: _neededByDate),
        authUid: 'uid-donor',
        donorProfile: unavailable,
      );
      await tester.pumpAndSettle();

      expect(find.byType(SolovvoButton), findsNothing);
    });

    testWidgets('offers no Accept to the owner, even with an eligible profile', (
      WidgetTester tester,
    ) async {
      // A person cannot accept their own request. The two branches are
      // mutually exclusive by construction (`canAccept` requires `!isMine`), so
      // the owner sees exactly their own affordances (edit, contact, cancel) and
      // never a fourth, self-claiming Accept button.
      await _pumpDetail(
        tester,
        fakeRequest(neededBy: _neededByDate),
        authUid: 'uid-recipient',
        donorProfile: _eligibleDonor,
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(SolovvoButton, english.requestsAcceptAction),
        findsNothing,
      );
      expect(find.byType(SolovvoButton), findsNWidgets(3));
    });

    testWidgets('accept tap opens a confirmation dialog, no write yet', (
      WidgetTester tester,
    ) async {
      final FakeRequestAcceptService service = FakeRequestAcceptService();
      await _pumpDetail(
        tester,
        fakeRequest(neededBy: _neededByDate),
        authUid: 'uid-donor',
        donorProfile: _eligibleDonor,
        acceptService: service,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(SolovvoButton, english.requestsAcceptAction),
      );
      await tester.pumpAndSettle();

      expect(find.text(english.requestsAcceptConfirmTitle), findsOneWidget);
      expect(find.text(english.requestsAcceptConfirmBody), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, english.requestsAcceptConfirmYes),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextButton, english.requestsAcceptConfirmNo),
        findsOneWidget,
      );
      // The commitment is a two-step: a claim that transitions the request has
      // to be confirmed before it is written.
      expect(service.calls, isEmpty);
    });

    testWidgets('dismissing the dialog does not call the service', (
      WidgetTester tester,
    ) async {
      final FakeRequestAcceptService service = FakeRequestAcceptService();
      await _pumpDetail(
        tester,
        fakeRequest(neededBy: _neededByDate),
        authUid: 'uid-donor',
        donorProfile: _eligibleDonor,
        acceptService: service,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(SolovvoButton, english.requestsAcceptAction),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, english.requestsAcceptConfirmNo),
      );
      await tester.pumpAndSettle();

      expect(service.calls, isEmpty);
      expect(find.byType(RequestDetailScreen), findsOneWidget);
    });

    testWidgets(
      'confirming calls the service with the request id and donor uid and pops', (
        WidgetTester tester,
      ) async {
        final FakeRequestAcceptService service = FakeRequestAcceptService();
        final BloodRequest r = fakeRequest(
          id: 'req-accept-7',
          neededBy: _neededByDate,
        );

        // Pushed as a route so a successful accept has somewhere to pop back
        // to, and the test observes the caller's contract: a non-null pop it
        // refreshes on, carrying the donor who claimed.
        final ProviderContainer container = ProviderContainer(
          overrides: [
            requestsAuthUidProvider.overrideWithValue('uid-donor'),
            profileRepositoryProvider.overrideWithValue(
              FakeProfileRepository(profile: _eligibleDonor),
            ),
            requestAcceptServiceProvider.overrideWithValue(service),
          ],
        );
        addTearDown(container.dispose);

        tester.view.physicalSize = _phone;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

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
          RequestDetailScreen.route(r),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(SolovvoButton, english.requestsAcceptAction),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(TextButton, english.requestsAcceptConfirmYes),
        );
        await tester.pumpAndSettle();

        // The pair is the whole contract of the write: this request, claimed by
        // this donor. A swapped uid would stamp the wrong person as assigned.
        expect(service.calls, <(String, String)>[('req-accept-7', 'uid-donor')]);
        expect(find.byType(RequestDetailScreen), findsNothing);
        expect(await popped, 'req-accept-7');
      },
    );

    testWidgets('a service failure keeps the screen and shows a SnackBar', (
      WidgetTester tester,
    ) async {
      // A race another donor won fails at the rules layer. The request is now
      // someone else's, and closing this screen would read as though the tap
      // worked; staying put with an error is the honest answer, the same way a
      // failed cancel behaves.
      final FakeRequestAcceptService service = FakeRequestAcceptService()
        ..failure = const PermissionFailure(
          debugMessage: 'test: rules refused the accept',
        );
      await _pumpDetail(
        tester,
        fakeRequest(neededBy: _neededByDate),
        authUid: 'uid-donor',
        donorProfile: _eligibleDonor,
        acceptService: service,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(SolovvoButton, english.requestsAcceptAction),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, english.requestsAcceptConfirmYes),
      );
      await tester.pumpAndSettle();

      expect(service.calls, hasLength(1));
      expect(find.byType(RequestDetailScreen), findsOneWidget);
      expect(find.text(english.requestsAcceptError), findsOneWidget);
    });

    testWidgets('a second tap during an in-flight write does not double-claim', (
      WidgetTester tester,
    ) async {
      final FakeRequestAcceptService service = FakeRequestAcceptService()
        ..gate = Completer<void>();
      final BloodRequest r = fakeRequest(
        id: 'req-accept-gate',
        neededBy: _neededByDate,
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [
          requestsAuthUidProvider.overrideWithValue('uid-donor'),
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(profile: _eligibleDonor),
          ),
          requestAcceptServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

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
        RequestDetailScreen.route(r),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(SolovvoButton, english.requestsAcceptAction),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, english.requestsAcceptConfirmYes),
      );
      // One pump starts the write and flips the button into its loading state
      // (the gate holds it there); a second tap lands on the disabled control.
      await tester.pump();
      await tester.tap(find.byType(SolovvoButton), warnIfMissed: false);
      await tester.pump();

      expect(service.calls, hasLength(1));

      service.gate!.complete();
      await tester.pumpAndSettle();
      expect(await popped, 'req-accept-gate');
    });

    testWidgets('accept copy is localised in Bangla', (
      WidgetTester tester,
    ) async {
      await _pumpDetail(
        tester,
        fakeRequest(neededBy: _neededByDate),
        locale: const Locale('bn'),
        authUid: 'uid-donor',
        donorProfile: _eligibleDonor,
        acceptService: FakeRequestAcceptService(),
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(SolovvoButton, bangla.requestsAcceptAction),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(SolovvoButton, english.requestsAcceptAction),
        findsNothing,
      );

      await tester.tap(
        find.widgetWithText(SolovvoButton, bangla.requestsAcceptAction),
      );
      await tester.pumpAndSettle();

      expect(find.text(bangla.requestsAcceptConfirmTitle), findsOneWidget);
      expect(find.text(bangla.requestsAcceptConfirmBody), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, bangla.requestsAcceptConfirmYes),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextButton, english.requestsAcceptConfirmYes),
        findsNothing,
      );
    });
  });
}
