import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/design/widgets/error_banner.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/design/widgets/solovvo_text_field.dart';
import 'package:sholovvo_app/features/profile/application/profile_providers.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';
import 'package:sholovvo_app/features/profile/presentation/profile_edit_screen.dart';
import 'package:sholovvo_app/features/profile/presentation/widgets/profile_privacy_card.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_profile_repository.dart';
import '../../support/test_app.dart';

/// Tall enough that the whole form is laid out in one frame, so a tap on the
/// save button lands on the save button.
const Size _tallPhone = Size(430, 2400);

/// Mounts the form behind a host route.
///
/// Pushing it rather than making it the home route is what lets a test see the
/// save actually return to the screen underneath.
Future<FakeProfileRepository> _pumpEditor(
  WidgetTester tester, {
  UserProfile initial = partialProfile,
  FakeProfileRepository? repository,
  ThemeMode themeMode = ThemeMode.light,
  Locale locale = const Locale('en'),
  Size size = _tallPhone,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final FakeProfileRepository repo =
      repository ?? FakeProfileRepository(profile: initial);
  addTearDown(repo.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [profileRepositoryProvider.overrideWithValue(repo)],
      child: testApp(
        home: _EditorHost(initial: initial),
        themeMode: themeMode,
        locale: locale,
      ),
    ),
  );
  await tester.pump();

  await tester.tap(find.text('open editor'));
  // The route transition, without `pumpAndSettle` (the destination animates).
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return repo;
}

/// A screen with one button, so the form has somewhere to return to.
class _EditorHost extends StatelessWidget {
  const _EditorHost({required this.initial});

  final UserProfile initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) =>
                  ProfileEditScreen(user: verifiedUser, initial: initial),
            ),
          ),
          child: const Text('open editor'),
        ),
      ),
    );
  }
}

/// The text field under a given label.
///
/// The label is rendered upper-case by [SolovvoTextField], which is also what
/// makes it unambiguous: no value in these fixtures is upper-case only.
Finder _field(String label) => find.descendant(
  of: find.widgetWithText(SolovvoTextField, label.toUpperCase()),
  matching: find.byType(TextField),
);

/// The form's only button, and therefore the save action in either language.
Finder get _save => find.byType(SolovvoButton);

Finder get _dateField => find.byIcon(Icons.cake_outlined);

Future<void> _enterText(
  WidgetTester tester,
  Finder field,
  String text,
) async {
  await tester.ensureVisible(field);
  await tester.pump();
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('ProfileEditScreen', () {
    testWidgets('starts from what the profile already holds', (
      WidgetTester tester,
    ) async {
      await _pumpEditor(tester, initial: filledProfile);

      expect(find.text('Ayesha Rahman'), findsOneWidget);
      expect(find.text('01712345678'), findsOneWidget);
      expect(find.text('Dhanmondi, Dhaka'), findsOneWidget);
      expect(find.text('House 12, Road 5'), findsOneWidget);
      // The address is the sign-in account's and is shown as unchangeable.
      expect(
        tester.widget<SolovvoTextField>(
          find.widgetWithText(SolovvoTextField, english.emailLabel.toUpperCase()),
        ).enabled,
        isFalse,
      );
      expect(find.text(verifiedUser.email!), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the chosen switches and chips as chosen', (
      WidgetTester tester,
    ) async {
      await _pumpEditor(tester, initial: filledProfile);

      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'O+'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, english.profileGenderFemale),
            )
            .selected,
        isTrue,
      );
      expect(tester.widget<Switch>(find.byKey(ProfilePrivacyCard.publishAreaSwitchKey)).value, isTrue);
      // The Stage 9.5 discovery consent defaults off on a profile that never
      // opted in. `filledProfile` has no `allowDonorDiscovery: true`, so the
      // switch on screen has to read that as off too — silently opt-in on
      // mount would defeat the whole point of the flag.
      expect(
        tester
            .widget<Switch>(find.byKey(ProfilePrivacyCard.discoverableSwitchKey))
            .value,
        isFalse,
      );
    });
  });

  group('ProfileEditScreen validation', () {
    testWidgets('an empty name is rejected and nothing is written', (
      WidgetTester tester,
    ) async {
      final FakeProfileRepository repo = await _pumpEditor(
        tester,
        initial: filledProfile,
      );

      await _enterText(tester, _field(english.fullNameLabel), '');
      await _tapVisible(tester, _save);

      expect(find.text(english.errorNameRequired), findsOneWidget);
      expect(repo.saveCalls, 0);
      // Still on the form, with the value it was given.
      expect(find.byType(ProfileEditScreen), findsOneWidget);
    });

    testWidgets('a phone number that could not be dialled is rejected', (
      WidgetTester tester,
    ) async {
      final FakeProfileRepository repo = await _pumpEditor(
        tester,
        initial: filledProfile,
      );

      await _enterText(tester, _field(english.profilePhoneLabel), '12345');
      await _tapVisible(tester, _save);

      expect(find.text(english.errorPhoneInvalid), findsOneWidget);
      expect(repo.saveCalls, 0);

      // Fixing it clears the message without a second save attempt.
      await _enterText(
        tester,
        _field(english.profilePhoneLabel),
        '+8801712345678',
      );
      expect(find.text(english.errorPhoneInvalid), findsNothing);
    });

    testWidgets('an untouched field does not turn red while typing', (
      WidgetTester tester,
    ) async {
      await _pumpEditor(tester, initial: filledProfile);

      await _enterText(tester, _field(english.profilePhoneLabel), '1');
      await _enterText(tester, _field(english.profilePhoneLabel), '12');

      // The rule only speaks once the donor has tried to save.
      expect(find.text(english.errorPhoneInvalid), findsNothing);
    });

    testWidgets('an over-long area is rejected', (WidgetTester tester) async {
      final FakeProfileRepository repo = await _pumpEditor(
        tester,
        initial: filledProfile,
      );

      await _enterText(tester, _field(english.profileAreaLabel), 'A' * 81);
      await _tapVisible(tester, _save);

      expect(find.text(english.errorAreaTooLong(80)), findsOneWidget);
      expect(repo.saveCalls, 0);
    });
  });

  group('ProfileEditScreen save', () {
    testWidgets('writes every edited field to this account', (
      WidgetTester tester,
    ) async {
      final FakeProfileRepository repo = await _pumpEditor(
        tester,
        initial: filledProfile,
      );

      await _enterText(tester, _field(english.fullNameLabel), 'Ayesha R.');
      await _enterText(
        tester,
        _field(english.profilePhoneLabel),
        '+8801712345678',
      );
      await _enterText(
        tester,
        _field(english.profileAddressLabel),
        'House 9, Road 2',
      );
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'AB-'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'AB-'));
      await tester.pump();
      await _tapVisible(tester, _save);

      final UserProfile? saved = repo.lastSaved;
      expect(repo.saveCalls, 1);
      expect(saved, isNotNull);
      expect(saved!.uid, filledProfile.uid);
      expect(saved.displayName, 'Ayesha R.');
      expect(saved.bloodGroup, 'AB-');
      expect(saved.phone, '+8801712345678');
      expect(saved.addressLine, 'House 9, Road 2');
      expect(saved.area, 'Dhanmondi, Dhaka');
      expect(saved.gender, ProfileGender.female);
      // Not editable here: carried across unchanged.
      expect(saved.photoUrl, filledProfile.photoUrl);
      expect(saved.isAvailable, filledProfile.isAvailable);
    });

    testWidgets('confirms and returns to the screen underneath', (
      WidgetTester tester,
    ) async {
      await _pumpEditor(tester, initial: filledProfile);

      await _tapVisible(tester, _save);
      // The pop transition has to finish before the form leaves the tree.
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(english.profileSaved), findsOneWidget);
      expect(find.byType(ProfileEditScreen), findsNothing);
      expect(find.text('open editor'), findsOneWidget);
    });

    testWidgets('a rejected save stays on the form and reports why', (
      WidgetTester tester,
    ) async {
      final FakeProfileRepository repo = await _pumpEditor(
        tester,
        initial: filledProfile,
      );
      repo.saveFailure = const PermissionFailure(debugMessage: 'not the owner');

      await _tapVisible(tester, _save);

      expect(find.byType(ErrorBanner), findsOneWidget);
      expect(
        find.text(english.failurePermission),
        findsOneWidget,
        reason: 'a rules refusal means the write named another account',
      );
      expect(find.byType(ProfileEditScreen), findsOneWidget);
      expect(find.text(english.profileSaved), findsNothing);
    });

    testWidgets('the stream never overwrites what is being typed', (
      WidgetTester tester,
    ) async {
      final FakeProfileRepository repo = FakeProfileRepository(
        profile: filledProfile,
      );
      await _pumpEditor(tester, initial: filledProfile, repository: repo);

      await _enterText(
        tester,
        _field(english.fullNameLabel),
        'Ayesha is typing',
      );

      // A write from elsewhere lands while the form is open.
      repo.emit(filledProfile.copyWith(isAvailable: false));
      await tester.pump();

      expect(find.text('Ayesha is typing'), findsOneWidget);
      expect(find.text(filledProfile.displayName), findsNothing);
    });
  });

  group('ProfileEditScreen date of birth', () {
    testWidgets('is optional until it is picked, and can be cleared again', (
      WidgetTester tester,
    ) async {
      await _pumpEditor(tester, initial: filledProfile);

      expect(find.text(english.profilePickerDate), findsOneWidget);

      await _tapVisible(tester, _dateField);
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // The picker confirms the month it opened on.
      await tester.tap(find.text('OK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.text(english.profilePickerDate), findsNothing);

      await _tapVisible(tester, find.byTooltip(english.profilePickerClear));

      expect(find.text(english.profilePickerDate), findsOneWidget);
    });

    testWidgets('saves the day that was picked, not an instant', (
      WidgetTester tester,
    ) async {
      final FakeProfileRepository repo = await _pumpEditor(
        tester,
        initial: filledProfile,
      );

      await _tapVisible(tester, _dateField);
      await tester.tap(find.text('OK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _tapVisible(tester, _save);

      // The picker opens 20 years back, on the first of that month.
      final DateTime expected = DateTime(DateTime.now().year - 20);
      expect(repo.lastSaved?.dateOfBirth, expected);
    });
  });

  group('ProfileEditScreen privacy switch', () {
    testWidgets('needs an area before it can publish one', (
      WidgetTester tester,
    ) async {
      // partialProfile has no area at all.
      await _pumpEditor(tester, initial: partialProfile);
      expect(
        tester
            .widget<Switch>(find.byKey(ProfilePrivacyCard.publishAreaSwitchKey))
            .onChanged,
        isNull,
      );

      await _enterText(
        tester,
        _field(english.profileAreaLabel),
        'Dhanmondi, Dhaka',
      );

      expect(
        tester
            .widget<Switch>(find.byKey(ProfilePrivacyCard.publishAreaSwitchKey))
            .onChanged,
        isNotNull,
      );
    });

    testWidgets('discovery consent is always tappable — it does not need an area', (
      WidgetTester tester,
    ) async {
      // The two switches are independent. Availability of a phone number in the
      // directory is not conditioned on the donor having typed an area.
      await _pumpEditor(tester, initial: partialProfile);
      expect(
        tester
            .widget<Switch>(
              find.byKey(ProfilePrivacyCard.discoverableSwitchKey),
            )
            .onChanged,
        isNotNull,
      );
    });

    testWidgets('carries the published area into the saved profile', (
      WidgetTester tester,
    ) async {
      final FakeProfileRepository repo = await _pumpEditor(
        tester,
        initial: filledProfile,
      );

      await _tapVisible(
        tester,
        find.byKey(ProfilePrivacyCard.publishAreaSwitchKey),
      );
      await _tapVisible(tester, _save);

      expect(repo.lastSaved?.publishAreaInSearch, isFalse);
      // The value itself is kept: it is the publication that stops.
      expect(repo.lastSaved?.area, filledProfile.area);
    });

    testWidgets('saves the discovery consent the donor chose', (
      WidgetTester tester,
    ) async {
      // Stage 9.5. `filledProfile` has no `allowDonorDiscovery` — off by
      // default. Tapping the switch must produce a saved profile with the flag
      // on; the profile screen and the repository write path do the rest.
      final FakeProfileRepository repo = await _pumpEditor(
        tester,
        initial: filledProfile,
      );

      await _tapVisible(
        tester,
        find.byKey(ProfilePrivacyCard.discoverableSwitchKey),
      );
      await _tapVisible(tester, _save);

      expect(repo.lastSaved?.allowDonorDiscovery, isTrue);
      // The other flags are not disturbed.
      expect(repo.lastSaved?.publishAreaInSearch, isTrue);
      expect(repo.lastSaved?.isAvailable, isTrue);
    });

    testWidgets('withdrawing consent survives a save round trip', (
      WidgetTester tester,
    ) async {
      // A donor who has opted in and then opts out must not stay in the
      // directory: the write path deletes the public projection. Here we only
      // assert that the form actually carries the switch's `false` through to
      // the repository — the delete is covered in profile_documents_test.
      final FakeProfileRepository repo = await _pumpEditor(
        tester,
        initial: filledProfile.copyWith(allowDonorDiscovery: true),
      );

      await _tapVisible(
        tester,
        find.byKey(ProfilePrivacyCard.discoverableSwitchKey),
      );
      await _tapVisible(tester, _save);

      expect(repo.lastSaved?.allowDonorDiscovery, isFalse);
    });
  });

  group('ProfileEditScreen in Bengali', () {
    testWidgets('renders its labels and rules in Bangla', (
      WidgetTester tester,
    ) async {
      await _pumpEditor(
        tester,
        initial: partialProfile,
        locale: const Locale('bn'),
      );

      expect(find.text(bangla.profileEditTitle), findsOneWidget);
      expect(
        find.text(bangla.bloodGroupLabel.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text(bangla.profileDobLabel.toUpperCase()), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _enterText(tester, _field(bangla.fullNameLabel), '');
      await _tapVisible(tester, _save);
      expect(find.text(bangla.errorNameRequired), findsOneWidget);
    });
  });
}
