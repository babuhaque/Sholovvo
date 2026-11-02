import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/design/widgets/error_banner.dart';
import 'package:sholovvo_app/features/profile/application/profile_photo_providers.dart';
import 'package:sholovvo_app/features/profile/application/profile_providers.dart';
import 'package:sholovvo_app/features/profile/domain/profile_photo.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';
import 'package:sholovvo_app/features/profile/presentation/profile_screen.dart';
import 'package:sholovvo_app/features/profile/presentation/widgets/profile_identity_card.dart';
import 'package:sholovvo_app/features/profile/presentation/widgets/profile_photo_sheet.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_photo_services.dart';
import '../../support/fake_profile_repository.dart';
import '../../support/test_app.dart';

/// Tall enough that the donor card, its photo button and the sheet are all on
/// screen without scrolling.
const Size _tallPhone = Size(430, 2400);

/// The three seams the photo flow touches, kept together so a test can assert on
/// what reached each of them.
final class _Harness {
  _Harness(this.repository, this.storage, this.picker);

  final FakeProfileRepository repository;
  final FakePhotoStorage storage;
  final FakePhotoPicker picker;
}

/// Mounts the profile screen with the photo pipeline stubbed end to end.
///
/// No Supabase project, no platform channel, no network: the picker hands over
/// prepared bytes and the storage fake answers from memory.
Future<_Harness> _pumpProfile(
  WidgetTester tester, {
  UserProfile? profile = filledProfile,
  bool isConfigured = true,
  PhotoCandidate? candidate,
  Failure? pickerFailure,
  Failure? uploadFailure,
  ThemeMode themeMode = ThemeMode.light,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = _tallPhone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final FakeProfileRepository repository = FakeProfileRepository(
    profile: profile,
  );
  addTearDown(repository.dispose);
  final FakePhotoStorage storage = FakePhotoStorage()
    ..isConfigured = isConfigured
    ..uploadFailure = uploadFailure;
  final FakePhotoPicker picker = FakePhotoPicker(candidate: candidate)
    ..failure = pickerFailure;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repository),
        profilePhotoStorageProvider.overrideWithValue(storage),
        photoPickerProvider.overrideWithValue(picker),
      ],
      child: testApp(
        home: ProfileScreen(user: verifiedUser),
        themeMode: themeMode,
        locale: locale,
      ),
    ),
  );
  // `pumpAndSettle` would never return: the soft glow animates forever.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return _Harness(repository, storage, picker);
}

/// Taps a control that may start below the fold, the way a donor would reach it.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

/// Pumps past a sheet dismissal and the async work it starts.
///
/// Fixed durations rather than `pumpAndSettle`, for the reason [_pumpProfile]
/// gives. Four frames: the route's own pop animation, then the frame in which
/// the screen receives the sheet's answer, then the frame that paints the
/// spinner, then the one that shows the confirmation.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// The donor's photo button on the identity card.
Finder _photoButton(String label) =>
    find.widgetWithText(TextButton, label);

/// A finder scoped to the open photo sheet.
///
/// Scoped because the sheet title is also the completion card's name for the
/// photo field ("Profile photo"), so an unscoped `find.text` would see the chip
/// behind the sheet as well.
Finder _inSheet(Finder finder) => find.descendant(
  of: find.byType(ProfilePhotoSheet),
  matching: finder,
);

/// The avatar's image, when a photo is being shown.
Finder get _avatarImage => find.descendant(
  of: find.byType(ProfileIdentityCard),
  matching: find.byType(Image),
);

/// A profile that already points at [url].
UserProfile _profileWithPhoto(String url) => filledProfile.withPhoto(url);

void main() {
  group('the photo control on the donor card', () {
    testWidgets('offers to add a photo when the donor has none', (
      WidgetTester tester,
    ) async {
      await _pumpProfile(tester);

      expect(find.byType(ProfileIdentityCard), findsOneWidget);
      expect(_photoButton(english.profilePhotoAdd), findsOneWidget);
      expect(find.text(english.profilePhotoChange), findsNothing);
      // No image until there is a URL to load.
      expect(_avatarImage, findsNothing);
    });

    testWidgets('offers to change it once there is one, and shows the image', (
      WidgetTester tester,
    ) async {
      const String url =
          'https://demo.supabase.co/storage/v1/object/public/avatars/'
          'uid-verified/avatar-1.jpg';
      await _pumpProfile(tester, profile: _profileWithPhoto(url));

      expect(_photoButton(english.profilePhotoChange), findsOneWidget);
      expect(find.text(english.profilePhotoAdd), findsNothing);

      final Image image = tester.widget<Image>(_avatarImage);
      expect((image.image as NetworkImage).url, url);
    });
  });

  group('the photo sheet', () {
    testWidgets('offers the two safe sources and no removal without a photo', (
      WidgetTester tester,
    ) async {
      await _pumpProfile(tester);

      await _tapVisible(tester, _photoButton(english.profilePhotoAdd));
      await _settle(tester);

      expect(_inSheet(find.text(english.profilePhotoSheetTitle)), findsOneWidget);
      expect(_inSheet(find.text(english.profilePhotoFromGallery)), findsOneWidget);
      expect(_inSheet(find.text(english.profilePhotoFromCamera)), findsOneWidget);
      expect(_inSheet(find.text(english.profilePhotoRemove)), findsNothing);
    });

    testWidgets('offers removal once a photo exists', (WidgetTester tester) async {
      await _pumpProfile(
        tester,
        profile: _profileWithPhoto(FakePhotoStorage.defaultUploadUrl),
      );

      await _tapVisible(tester, _photoButton(english.profilePhotoChange));
      await _settle(tester);

      expect(_inSheet(find.text(english.profilePhotoRemove)), findsOneWidget);
    });

    testWidgets('says the upload is not set up instead of offering choices '
        'that could only fail', (WidgetTester tester) async {
      final _Harness harness = await _pumpProfile(tester, isConfigured: false);

      await _tapVisible(tester, _photoButton(english.profilePhotoAdd));
      await _settle(tester);

      expect(_inSheet(find.text(english.profilePhotoNotConfigured)), findsOneWidget);
      expect(_inSheet(find.text(english.profilePhotoFromGallery)), findsNothing);
      expect(_inSheet(find.text(english.profilePhotoFromCamera)), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, english.close));
      await _settle(tester);

      expect(harness.picker.calls, 0);
      expect(harness.repository.photoUrlCalls, 0);
    });
  });

  group('uploading a photo', () {
    testWidgets('a gallery pick uploads it and publishes the returned URL', (
      WidgetTester tester,
    ) async {
      final _Harness harness = await _pumpProfile(
        tester,
        candidate: PhotoCandidate(bytes: jpegBytes(), fileName: 'me.jpg'),
      );

      await _tapVisible(tester, _photoButton(english.profilePhotoAdd));
      await _settle(tester);
      await tester.tap(find.text(english.profilePhotoFromGallery));
      await _settle(tester);

      expect(harness.picker.lastSource?.name, 'gallery');
      expect(harness.storage.uploadCalls, 1);
      expect(harness.repository.lastPhotoUrl, harness.storage.uploadUrl);
      expect(harness.repository.profile?.photoUrl, harness.storage.uploadUrl);
      expect(find.text(english.profilePhotoUpdated), findsOneWidget);
      expect(find.byType(ErrorBanner), findsNothing);
      // The card now reads "Change photo", because the profile it renders has
      // the new URL.
      expect(_photoButton(english.profilePhotoChange), findsOneWidget);
    });

    testWidgets('the camera is a separate source, not a second gallery', (
      WidgetTester tester,
    ) async {
      final _Harness harness = await _pumpProfile(
        tester,
        candidate: PhotoCandidate(bytes: pngBytes()),
      );

      await _tapVisible(tester, _photoButton(english.profilePhotoAdd));
      await _settle(tester);
      await tester.tap(find.text(english.profilePhotoFromCamera));
      await _settle(tester);

      expect(harness.picker.lastSource?.name, 'camera');
      expect(harness.storage.lastUpload?.format, PhotoFormat.png);
    });

    testWidgets('closing the picker changes nothing and confirms nothing', (
      WidgetTester tester,
    ) async {
      final _Harness harness = await _pumpProfile(tester);

      await _tapVisible(tester, _photoButton(english.profilePhotoAdd));
      await _settle(tester);
      await tester.tap(find.text(english.profilePhotoFromGallery));
      await _settle(tester);

      expect(harness.picker.calls, 1);
      expect(harness.storage.uploadCalls, 0);
      expect(harness.repository.photoUrlCalls, 0);
      expect(find.text(english.profilePhotoUpdated), findsNothing);
      expect(find.byType(ErrorBanner), findsNothing);
    });

    testWidgets('a file that is not an image is explained, not uploaded', (
      WidgetTester tester,
    ) async {
      final _Harness harness = await _pumpProfile(
        tester,
        candidate: PhotoCandidate(bytes: textBytes(), fileName: 'me.jpg'),
      );

      await _tapVisible(tester, _photoButton(english.profilePhotoAdd));
      await _settle(tester);
      await tester.tap(find.text(english.profilePhotoFromGallery));
      await _settle(tester);

      expect(find.byType(ErrorBanner), findsOneWidget);
      expect(find.text(english.errorPhotoUnsupported), findsOneWidget);
      expect(harness.storage.uploadCalls, 0);
      expect(harness.repository.photoUrlCalls, 0);
    });

    testWidgets('a denied library permission is explained too', (
      WidgetTester tester,
    ) async {
      await _pumpProfile(
        tester,
        pickerFailure: ValidationFailure(
          messageKey: PhotoIssue.accessDenied.name,
          debugMessage: 'denied',
        ),
      );

      await _tapVisible(tester, _photoButton(english.profilePhotoAdd));
      await _settle(tester);
      await tester.tap(find.text(english.profilePhotoFromGallery));
      await _settle(tester);

      expect(find.text(english.errorPhotoAccessDenied), findsOneWidget);
    });

    testWidgets('a failed upload is reported and the old photo keeps showing', (
      WidgetTester tester,
    ) async {
      const String previous =
          'https://demo.supabase.co/storage/v1/object/public/avatars/'
          'uid-verified/avatar-old.jpg';
      final _Harness harness = await _pumpProfile(
        tester,
        profile: _profileWithPhoto(previous),
        candidate: PhotoCandidate(bytes: jpegBytes()),
        uploadFailure: const NetworkFailure(debugMessage: 'offline'),
      );

      await _tapVisible(tester, _photoButton(english.profilePhotoChange));
      await _settle(tester);
      await tester.tap(find.text(english.profilePhotoFromGallery));
      await _settle(tester);

      expect(find.byType(ErrorBanner), findsOneWidget);
      expect(find.text(english.failureNetwork), findsOneWidget);
      expect(harness.repository.photoUrlCalls, 0);
      expect(harness.repository.profile?.photoUrl, previous);
      final Image image = tester.widget<Image>(_avatarImage);
      expect((image.image as NetworkImage).url, previous);
    });

    testWidgets('the avatar shows a spinner over the photo while uploading', (
      WidgetTester tester,
    ) async {
      const String previous =
          'https://demo.supabase.co/storage/v1/object/public/avatars/'
          'uid-verified/avatar-old.jpg';
      final _Harness harness = await _pumpProfile(
        tester,
        profile: _profileWithPhoto(previous),
        candidate: PhotoCandidate(bytes: jpegBytes()),
      );
      harness.storage.gate = Completer<void>();

      await _tapVisible(tester, _photoButton(english.profilePhotoChange));
      await _settle(tester);
      await tester.tap(find.text(english.profilePhotoFromGallery));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.descendant(
          of: find.byType(ProfileIdentityCard),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      // The old photo is still there: blanking it would look like it had
      // already been replaced.
      expect(_avatarImage, findsOneWidget);
      // And the button cannot start a second operation from this state.
      expect(
        tester
            .widget<TextButton>(_photoButton(english.profilePhotoChange))
            .onPressed,
        isNull,
      );

      harness.storage.gate!.complete();
      await _settle(tester);

      expect(
        find.descendant(
          of: find.byType(ProfileIdentityCard),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      expect(find.text(english.profilePhotoUpdated), findsOneWidget);
    });
  });

  group('removing a photo', () {
    testWidgets('asks first, then clears the field and deletes the object', (
      WidgetTester tester,
    ) async {
      const String url =
          'https://demo.supabase.co/storage/v1/object/public/avatars/'
          'uid-verified/avatar-1.jpg';
      final _Harness harness = await _pumpProfile(
        tester,
        profile: _profileWithPhoto(url),
      );

      await _tapVisible(tester, _photoButton(english.profilePhotoChange));
      await _settle(tester);
      await tester.tap(find.text(english.profilePhotoRemove));
      await _settle(tester);

      expect(find.text(english.profilePhotoRemoveConfirmTitle), findsOneWidget);
      expect(find.text(english.profilePhotoRemoveConfirmBody), findsOneWidget);
      expect(harness.repository.photoUrlCalls, 0, reason: 'nothing yet');

      await tester.tap(
        find.widgetWithText(TextButton, english.profilePhotoRemove),
      );
      await _settle(tester);

      expect(harness.repository.lastPhotoUrl, isNull);
      expect(harness.repository.profile?.photoUrl, isNull);
      // The profile no longer points at the object, so it goes too.
      expect(harness.storage.removedUrls, <String>[url]);
      expect(find.text(english.profilePhotoRemoved), findsOneWidget);
      expect(_photoButton(english.profilePhotoAdd), findsOneWidget);
    });

    testWidgets('cancelling the confirmation leaves the photo untouched', (
      WidgetTester tester,
    ) async {
      const String url =
          'https://demo.supabase.co/storage/v1/object/public/avatars/'
          'uid-verified/avatar-1.jpg';
      final _Harness harness = await _pumpProfile(
        tester,
        profile: _profileWithPhoto(url),
      );

      await _tapVisible(tester, _photoButton(english.profilePhotoChange));
      await _settle(tester);
      await tester.tap(find.text(english.profilePhotoRemove));
      await _settle(tester);
      await tester.tap(find.widgetWithText(TextButton, english.actionCancel));
      await _settle(tester);

      expect(harness.repository.photoUrlCalls, 0);
      expect(harness.storage.removedUrls, isEmpty);
      expect(harness.repository.profile?.photoUrl, url);
      expect(_photoButton(english.profilePhotoChange), findsOneWidget);
    });
  });

  group('the photo flow in Bangla', () {
    testWidgets('labels the control and the sheet in Bangla', (
      WidgetTester tester,
    ) async {
      await _pumpProfile(tester, locale: const Locale('bn'));

      expect(_photoButton(bangla.profilePhotoAdd), findsOneWidget);

      await _tapVisible(tester, _photoButton(bangla.profilePhotoAdd));
      await _settle(tester);

      expect(_inSheet(find.text(bangla.profilePhotoSheetTitle)), findsOneWidget);
      expect(_inSheet(find.text(bangla.profilePhotoFromGallery)), findsOneWidget);
      expect(_inSheet(find.text(bangla.profilePhotoFromCamera)), findsOneWidget);
      expect(find.text(english.profilePhotoFromGallery), findsNothing);
    });

    testWidgets('explains the unconfigured state in Bangla', (
      WidgetTester tester,
    ) async {
      await _pumpProfile(
        tester,
        locale: const Locale('bn'),
        isConfigured: false,
      );

      await _tapVisible(tester, _photoButton(bangla.profilePhotoAdd));
      await _settle(tester);

      expect(_inSheet(find.text(bangla.profilePhotoNotConfigured)), findsOneWidget);
    });
  });

  group('the photo flow in the dark theme', () {
    testWidgets('opens the sheet from the dark palette without a failure', (
      WidgetTester tester,
    ) async {
      await _pumpProfile(tester, themeMode: ThemeMode.dark);

      await _tapVisible(tester, _photoButton(english.profilePhotoAdd));
      await _settle(tester);

      expect(_inSheet(find.text(english.profilePhotoFromGallery)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
