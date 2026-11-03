import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/media/photo.dart';
import 'package:sholovvo_app/core/media/photo_picker.dart';
import 'package:sholovvo_app/design/widgets/error_banner.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/design/widgets/solovvo_text_field.dart';
import 'package:sholovvo_app/features/feed/application/compose_providers.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/post_draft.dart';
import 'package:sholovvo_app/features/feed/presentation/compose_post_screen.dart';
import 'package:sholovvo_app/features/feed/presentation/widgets/compose_image_grid.dart';

import '../../support/fake_compose.dart';
import '../../support/fake_feed.dart';
import '../../support/fake_photo_services.dart';
import '../../support/test_app.dart';

const Size _phone = Size(430, 932);

/// The author every publish in this file is attributed to.
const PostAuthor _author = PostAuthor(name: 'Ayesha Rahman');

/// The screen is pushed, never mounted as `home:`.
///
/// Two things a test can only reach from underneath the composer: the back
/// button, which a first route does not draw, and the guard that decides whether
/// leaving is allowed at all — a question that only exists when there is
/// somewhere to leave to.
const Key _hostKey = Key('under-the-composer');

Finder get _field => find.byType(TextField);
Finder get _publishButton => find.byType(SolovvoButton);
Finder get _addTile => find.byIcon(Icons.add_a_photo_outlined);

/// The app bar's back control.
///
/// Found by position rather than by its tooltip, because that tooltip is a
/// Material localisation string and so changes with the language: the guard has
/// to be tested in both, and it has to be the same control in both.
Finder get _backButton => find.descendant(
  of: find.byType(AppBar),
  matching: find.byType(IconButton),
);

/// The compose screen over fakes, holding the seams a test needs to keep open.
final class _Compose {
  _Compose({
    required this.repository,
    required this.storage,
    required this.picker,
  });

  final FakePostRepository repository;
  final FakePostImageStorage storage;
  final FakePhotoPicker picker;

  /// Types the way a donor does: through the field, not through the controller.
  ///
  /// The form keeps the text in two places on purpose — the caret belongs to the
  /// field's own controller, the draft to ComposeState — so a test that wrote to
  /// the notifier directly would not catch the two drifting apart.
  Future<void> type(WidgetTester tester, String value) async {
    await tester.enterText(_field, value);
    await tester.pump();
  }

  /// Opens the source sheet and takes the gallery row.
  ///
  /// The rows are found by icon rather than by label so the same helper works in
  /// Bangla, where every one of those words is different.
  Future<void> pickFromGallery(WidgetTester tester) async {
    await tester.tap(_addTile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byIcon(Icons.photo_library_outlined));
    await tester.pump();
    // The sheet pops itself when a row is chosen, and a zero-duration pump
    // freezes its exit halfway: a test that then counted the words on screen
    // would be counting a sheet the donor has already put away.
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// A draft with one photo already stored in it.
  Future<void> addOnePhoto(WidgetTester tester) async {
    await type(tester, 'Donated at Dhaka Medical today.');
    await pickFromGallery(tester);
    await _settle(tester);
  }
}

/// A few frames, enough for a resolved write or upload to reach the tree.
///
/// `pumpAndSettle` is unusable in this file rather than merely unwise: several
/// tests assert while the indeterminate upload spinner is turning, and that
/// animation never settles.
Future<void> _settle(WidgetTester tester, [int frames = 4]) async {
  for (int index = 0; index < frames; index++) {
    await tester.pump();
  }
}

/// Mounts the composer over fakes, in the language and on the window asked for.
Future<_Compose> _pumpCompose(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
  Size size = _phone,
  bool configured = true,
  PostAuthor author = _author,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final FakePostRepository repository = FakePostRepository();
  final FakePostImageStorage storage = FakePostImageStorage(
    isConfigured: configured,
  );
  final FakePhotoPicker picker = FakePhotoPicker(
    candidate: PhotoCandidate(bytes: jpegBytes()),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        postRepositoryProvider.overrideWithValue(repository),
        postImageStorageProvider.overrideWithValue(storage),
        postPhotoPickerProvider.overrideWithValue(picker),
        // A publish hands the new post to the feed and takes the author's name
        // from the profile stream. Both are seeded through their own seam here,
        // so no widget test needs a Firestore and the name in the written
        // document is the name this file chose.
        feedRepositoryProvider.overrideWithValue(FakeFeedRepository()),
        composeAuthorProvider.overrideWithValue(author),
      ],
      child: testApp(
        home: const _ComposeHost(),
        themeMode: themeMode,
        locale: locale,
      ),
    ),
  );

  // The host pushes the composer in a post-frame callback, so these pumps are
  // what open the route and let its 420ms transition finish.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();

  return _Compose(repository: repository, storage: storage, picker: picker);
}

void main() {
  group('ComposePostScreen, an empty form', () {
    testWidgets('draws the field, the four slots and the publish', (
      WidgetTester tester,
    ) async {
      await _pumpCompose(tester);

      expect(find.byType(ComposePostScreen), findsOneWidget);
      expect(find.text('New post'), findsOneWidget);
      expect(_field, findsOneWidget);
      expect(find.text('YOUR UPDATE'), findsOneWidget);
      expect(
        find.text('Share news, a request, or a story from a blood drive.'),
        findsOneWidget,
      );
      expect(find.text(english.feedComposeLimit(PostValidator.maxTextLength)),
          findsOneWidget);
      expect(find.text('PHOTOS'), findsOneWidget);
      expect(find.byType(ComposeImageGrid), findsOneWidget);
      expect(find.text('Publish'), findsOneWidget);
    });

    testWidgets('shows no wait, no error, and nothing to publish', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(ErrorBanner), findsNothing);
      // An empty box is not an error yet: the inert publish already says so, and
      // a message under it would shout at a donor who has not started writing.
      expect(find.text('Write something before publishing'), findsNothing);
      expect(tester.widget<SolovvoButton>(_publishButton).onPressed, isNull);

      // warnIfMissed: an inert button is exactly what is being asserted, so the
      // tap is expected to land on nothing.
      await tester.tap(_publishButton, warnIfMissed: false);
      await _settle(tester);
      expect(fakes.repository.calls, 0);
    });

    testWidgets('keeps exactly one add tile and pads the rest of the grid', (
      WidgetTester tester,
    ) async {
      await _pumpCompose(tester);

      // Four cells always: the grid is the statement of the capacity.
      expect(_addTile, findsOneWidget);
      expect(find.text('Add photo'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });

  group('the text field', () {
    testWidgets('typing wakes the publish button', (WidgetTester tester) async {
      final _Compose fakes = await _pumpCompose(tester);

      await fakes.type(tester, 'Looking for O- for my sister.');

      expect(tester.widget<SolovvoButton>(_publishButton).onPressed, isNotNull);

      await tester.tap(_publishButton);
      await _settle(tester);
      expect(fakes.repository.calls, 1);
      expect(fakes.repository.lastDraft?.text, 'Looking for O- for my sister.');
      expect(fakes.repository.lastDraft?.author.name, 'Ayesha Rahman');
    });

    testWidgets('the limit is a message, not a wall', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);
      // Both sentences are read from the generated catalogue rather than typed
      // here, because their count goes through `NumberFormat.decimalPattern`:
      // English renders it "2,000", Bangla renders Bengali digits. A literal in
      // this file would be a second source of truth, and the wrong one.
      final String tooLong = english.errorPostTextTooLong(
        PostValidator.maxTextLength,
      );
      final String limit = english.feedComposeLimit(PostValidator.maxTextLength);

      // No `maxLength` on the field: a donor pasting a long story is allowed to
      // finish the sentence and read what to cut, rather than finding the caret
      // refuses to move. The rule bites at the publish button instead.
      await fakes.type(tester, 'a' * (PostValidator.maxTextLength + 1));

      expect(find.text(tooLong), findsOneWidget);
      expect(tester.widget<SolovvoButton>(_publishButton).onPressed, isNull);

      await tester.tap(_publishButton, warnIfMissed: false);
      await _settle(tester);
      expect(fakes.repository.calls, 0);

      await fakes.type(tester, 'a' * PostValidator.maxTextLength);
      expect(find.text(tooLong), findsNothing);
      expect(find.text(limit), findsOneWidget);
      expect(tester.widget<SolovvoButton>(_publishButton).onPressed, isNotNull);
    });

    testWidgets('an over-limit draft cannot be published', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);

      await fakes.type(tester, 'a' * (PostValidator.maxTextLength + 50));
      await tester.tap(_publishButton, warnIfMissed: false);
      await _settle(tester);

      expect(fakes.repository.calls, 0);
    });

    testWidgets('spaces are not a post', (WidgetTester tester) async {
      final _Compose fakes = await _pumpCompose(tester);

      await fakes.type(tester, '    ');

      expect(tester.widget<SolovvoButton>(_publishButton).onPressed, isNull);
      expect(find.text('Write something before publishing'), findsNothing);

      await tester.tap(_publishButton, warnIfMissed: false);
      await _settle(tester);
      expect(fakes.repository.calls, 0);
    });

    testWidgets('trims what it writes, without touching what was typed', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);
      // A refused publish keeps the screen open, so one run can read both halves
      // of the contract: what went into the document, and what stayed in the box.
      fakes.repository.failure = const NetworkFailure(debugMessage: 'offline');
      await fakes.type(tester, '   Donated today.   ');

      await tester.tap(_publishButton);
      await _settle(tester);

      expect(fakes.repository.lastDraft?.text, 'Donated today.');
      // The donor's own spacing stays in the box: trimming is the document's
      // business, not something the form silently rewrites under the caret.
      expect(tester.widget<TextField>(_field).controller!.text,
          '   Donated today.   ');
    });
  });

  group('photographs', () {
    testWidgets('the add tile asks where the photo comes from', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);

      await tester.tap(_addTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Add photo'), findsNWidgets(2));
      expect(find.text('Choose from gallery'), findsOneWidget);
      expect(find.text('Take a photo'), findsOneWidget);
      expect(fakes.picker.calls, 0, reason: 'asking is not picking');
      expect(fakes.storage.uploadCalls, 0);
    });

    testWidgets('the camera row asks the camera', (WidgetTester tester) async {
      final _Compose fakes = await _pumpCompose(tester);

      await tester.tap(_addTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byIcon(Icons.photo_camera_outlined));
      await _settle(tester);

      expect(fakes.picker.calls, 1);
      expect(fakes.picker.lastSource, PhotoSource.camera);
      expect(fakes.storage.uploadCalls, 1);
    });

    testWidgets('a picked photo uploads and fills the next slot', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);

      await fakes.pickFromGallery(tester);
      await _settle(tester);

      expect(fakes.picker.lastSource, PhotoSource.gallery);
      expect(fakes.storage.uploadCalls, 1);
      expect(find.byType(Image), findsOneWidget);
      expect(_addTile, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the add tile turns into a spinner while the object is up', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);
      fakes.storage.gate = Completer<void>();

      await fakes.pickFromGallery(tester);
      // Not one pump after an un-awaited call: the pick has to resolve, and the
      // fake says when the upload itself has begun.
      await fakes.storage.uploadStarted.future;
      await tester.pump();

      expect(find.text(english.feedComposeUploading), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_addTile, findsNothing);
      expect(find.byType(Image), findsNothing);

      fakes.storage.gate!.complete();
      await _settle(tester);

      expect(find.text(english.feedComposeUploading), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('publish waits for the photo still going up', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);
      await fakes.type(tester, 'Donated at Dhaka Medical today.');
      fakes.storage.gate = Completer<void>();

      await fakes.pickFromGallery(tester);
      await fakes.storage.uploadStarted.future;
      await tester.pump();

      // Publishing now would write a document missing the fourth photo, so the
      // button is inert for the whole of the upload even though the text alone
      // would have been a valid post.
      expect(tester.widget<SolovvoButton>(_publishButton).onPressed, isNull);
      await tester.tap(_publishButton, warnIfMissed: false);
      expect(fakes.repository.calls, 0);

      fakes.storage.gate!.complete();
      await _settle(tester);
      expect(tester.widget<SolovvoButton>(_publishButton).onPressed, isNotNull);
    });

    testWidgets('a failed upload says so and leaves the form usable', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);
      fakes.storage.uploadFailure = const NetworkFailure(
        debugMessage: 'offline',
      );

      await fakes.type(tester, 'Donated at Dhaka Medical today.');
      await fakes.pickFromGallery(tester);
      await _settle(tester);

      expect(find.byType(ErrorBanner), findsOneWidget);
      expect(
        find.text('No connection. Check your network and try again.'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
      // A photo that failed is not a photo: nothing was appended, and the slot
      // is free again rather than permanently disabled.
      expect(_addTile, findsOneWidget);
      expect(tester.widget<SolovvoButton>(_publishButton).onPressed, isNotNull);

      fakes.storage.uploadFailure = null;
      await fakes.pickFromGallery(tester);
      await _settle(tester);

      expect(find.byType(ErrorBanner), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      expect(fakes.storage.uploadCalls, 2);
    });

    testWidgets('a picker that fails says what went wrong', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);
      fakes.picker.failure = const PermissionFailure(
        debugMessage: 'denied',
      );

      await fakes.pickFromGallery(tester);
      await _settle(tester);

      expect(find.byType(ErrorBanner), findsOneWidget);
      expect(find.text('You do not have permission to do that.'), findsOneWidget);
      expect(fakes.storage.uploadCalls, 0);
      expect(_addTile, findsOneWidget);
    });

    testWidgets('a cancelled pick is silence', (WidgetTester tester) async {
      final _Compose fakes = await _pumpCompose(tester);
      fakes.picker.candidate = null;

      await fakes.pickFromGallery(tester);
      await _settle(tester);

      expect(find.byType(ErrorBanner), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(fakes.storage.uploadCalls, 0);
      expect(_addTile, findsOneWidget);
    });

    testWidgets('four photos fill the grid and the add tile goes', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);

      for (int index = 0; index < PostValidator.maxImages; index++) {
        await fakes.pickFromGallery(tester);
        await _settle(tester);
      }

      expect(fakes.storage.uploadCalls, PostValidator.maxImages);
      expect(find.byType(Image), findsNWidgets(PostValidator.maxImages));
      expect(_addTile, findsNothing);
      expect(find.text('Add photo'), findsNothing);
      // Four is the limit, not one past it: the draft is still publishable.
      await fakes.type(tester, 'Donated at Dhaka Medical today.');
      expect(tester.widget<SolovvoButton>(_publishButton).onPressed, isNotNull);

      await tester.tap(_publishButton);
      await _settle(tester);
      expect(fakes.repository.lastDraft?.imageUrls, hasLength(4));
    });

    testWidgets('removing a photo empties the slot and deletes the object', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);

      await fakes.pickFromGallery(tester);
      await _settle(tester);
      await fakes.pickFromGallery(tester);
      await _settle(tester);
      expect(find.byType(Image), findsNWidgets(2));

      await tester.tap(find.byTooltip('Remove photo').first);
      await _settle(tester);

      expect(fakes.storage.removedPaths, <String>[storedImage(0).path]);
      expect(find.byType(Image), findsOneWidget);
      // Positional, not a hole: what is left is the photo that came second.
      final Image remaining = tester.widget<Image>(find.byType(Image).first);
      expect(remaining.image, NetworkImage(storedImage(1).url));
      expect(_addTile, findsOneWidget);
    });

    testWidgets('a photo whose object has gone still holds its slot', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);
      fakes.storage.removeFailure = const NetworkFailure(
        debugMessage: 'offline',
      );

      await fakes.addOnePhoto(tester);
      await tester.tap(find.byTooltip('Remove photo'));
      await _settle(tester);

      // The donor asked for it to go and it did go. A banner about a delete that
      // failed would be a sentence about a file that is no longer on screen, so
      // the failure is logged and the form stays clean.
      expect(find.byType(Image), findsNothing);
      expect(find.byType(ErrorBanner), findsNothing);
    });
  });

  group('publishing', () {
    testWidgets('turns the button, confirms, and leaves', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);
      await fakes.type(tester, 'Donated at Dhaka Medical today.');
      fakes.repository.gate = Completer<void>();

      await tester.tap(_publishButton);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Every control is inert while the write is on its way: the field cannot be
      // edited, and the add tile cannot start an upload that no document would
      // ever name.
      expect(
        tester.widget<SolovvoTextField>(find.byType(SolovvoTextField)).enabled,
        isFalse,
      );
      expect(
        tester.widget<InkWell>(
          find.descendant(
            of: find.byType(ComposeImageGrid),
            matching: find.byType(InkWell),
          ),
        ).onTap,
        isNull,
      );

      fakes.repository.gate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byType(ComposePostScreen), findsNothing);
      expect(find.text('Your post is live.'), findsOneWidget);
      expect(find.byKey(_hostKey), findsOneWidget);
    });

    testWidgets('a failed publish keeps the words', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);
      await fakes.type(tester, 'Donated at Dhaka Medical today.');
      fakes.repository.failure = const NetworkFailure(debugMessage: 'offline');

      await tester.tap(_publishButton);
      await _settle(tester);

      expect(find.byType(ErrorBanner), findsOneWidget);
      expect(
        find.text('No connection. Check your network and try again.'),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(_field).controller!.text,
          'Donated at Dhaka Medical today.');
      expect(find.byType(ComposePostScreen), findsOneWidget);
      expect(tester.widget<SolovvoButton>(_publishButton).onPressed, isNotNull);

      fakes.repository.failure = null;
      await tester.tap(_publishButton);
      await _settle(tester);

      expect(fakes.repository.calls, 2);
      // Time, not just frames: the pop that follows a good publish is a route
      // transition, and a zero-duration pump leaves it stalled at the first step
      // with the composer still on screen.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ComposePostScreen), findsNothing);
      expect(find.text(english.feedComposePublished), findsOneWidget);
    });

    testWidgets('a second tap cannot write a second post', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);
      await fakes.type(tester, 'Donated at Dhaka Medical today.');
      fakes.repository.gate = Completer<void>();

      await tester.tap(_publishButton);
      await tester.pump();
      // Second tap silenced: a tap that lands on nothing is the point, and the
      // warning for it is noise.
      await tester.tap(_publishButton, warnIfMissed: false);
      await tester.pump();

      fakes.repository.gate!.complete();
      await _settle(tester);
      expect(fakes.repository.calls, 1);
    });

    testWidgets('a photo in the draft travels with it', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);
      await fakes.addOnePhoto(tester);

      await tester.tap(_publishButton);
      await _settle(tester);

      final PostDraft? draft = fakes.repository.lastDraft;
      expect(draft?.text, 'Donated at Dhaka Medical today.');
      expect(draft?.imageUrls, <String>[storedImage(0).url]);
      expect(draft?.imagePaths, <String>[storedImage(0).path]);
      expect(draft?.issue, isNull);
    });
  });

  group('leaving', () {
    testWidgets('an untouched form closes without asking', (
      WidgetTester tester,
    ) async {
      await _pumpCompose(tester);

      await tester.tap(_backButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ComposePostScreen), findsNothing);
      expect(find.text('Discard this post?'), findsNothing);
    });

    testWidgets('a draft asks before it is thrown away', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);
      await fakes.type(tester, 'Donated at Dhaka Medical today.');

      await tester.tap(_backButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Discard this post?'), findsOneWidget);
      expect(find.text('Your text and photos will be deleted.'), findsOneWidget);
      expect(find.byType(ComposePostScreen), findsOneWidget);
      expect(fakes.repository.calls, 0);
    });

    testWidgets('keep editing keeps the draft', (WidgetTester tester) async {
      final _Compose fakes = await _pumpCompose(tester);
      await fakes.addOnePhoto(tester);

      await tester.tap(_backButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Keep editing'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ComposePostScreen), findsOneWidget);
      expect(find.text('Discard this post?'), findsNothing);
      expect(tester.widget<TextField>(_field).controller!.text,
          'Donated at Dhaka Medical today.');
      expect(find.byType(Image), findsOneWidget);
      expect(fakes.storage.removedPaths, isEmpty);
    });

    testWidgets('discarding deletes the photo and closes', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);
      await fakes.addOnePhoto(tester);

      await tester.tap(_backButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Discard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // An abandoned draft has no document to own its objects, so leaving this
      // way is what keeps the bucket from filling with unsent photographs.
      expect(fakes.storage.removedPaths, <String>[storedImage(0).path]);
      expect(find.byType(ComposePostScreen), findsNothing);
      expect(find.text('Discard this post?'), findsNothing);
    });

    testWidgets('a discard during an upload keeps the form open', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);
      await fakes.type(tester, 'Donated at Dhaka Medical today.');
      fakes.storage.gate = Completer<void>();
      await fakes.pickFromGallery(tester);
      // Held open on purpose: this test is about the one moment the old guard
      // missed, and it can only be observed from inside an upload that has
      // started and has not finished.
      await fakes.storage.uploadStarted.future;
      await _settle(tester);

      await tester.tap(_backButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Discard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Not closed, and not silently closed-and-leaked: the draft survives, the
      // photo is still going up, and the grid says so in the donor's own words.
      expect(find.byType(ComposePostScreen), findsOneWidget);
      expect(find.text('Discard this post?'), findsNothing);
      expect(find.text('Uploading your photo…'), findsOneWidget);
      expect(fakes.storage.removedPaths, isEmpty);

      fakes.storage.gate!.complete();
      await _settle(tester);

      // Confirming again now abandons it properly, with the photo named and
      // deleted rather than dropped on the floor.
      await tester.tap(_backButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Discard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byType(ComposePostScreen), findsNothing);
      expect(fakes.storage.removedPaths, <String>[storedImage(0).path]);
    });

    testWidgets('a photo-only draft is worth confirming too', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);
      await fakes.pickFromGallery(tester);
      await _settle(tester);

      await tester.tap(_backButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Discard this post?'), findsOneWidget);
    });

    testWidgets('the system back button closes an untouched form', (
      WidgetTester tester,
    ) async {
      await _pumpCompose(tester);

      // The platform pop, not the visible arrow: on Android this is the gesture
      // that leaves an app, and it has to reach the same guard.
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ComposePostScreen), findsNothing);
      expect(find.text('Discard this post?'), findsNothing);
    });

    testWidgets('the system back button is guarded the same way as the arrow', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);
      await fakes.type(tester, 'Donated at Dhaka Medical today.');

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Discard this post?'), findsOneWidget);
      expect(find.byType(ComposePostScreen), findsOneWidget);
      expect(fakes.repository.calls, 0);
    });
  });

  group('a build with no photo bucket', () {
    testWidgets('says so, and still publishes the text', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester, configured: false);

      expect(find.byType(ComposeImageGrid), findsNothing);
      expect(
        find.text('Photo upload is not set up in this build yet.'),
        findsOneWidget,
      );
      // Not a dead end: the text half of the form is a whole post.
      await fakes.type(tester, 'Donated at Dhaka Medical today.');
      await tester.tap(_publishButton);
      await _settle(tester);

      expect(fakes.repository.calls, 1);
      expect(fakes.repository.lastDraft?.imageUrls, isEmpty);
      expect(fakes.picker.calls, 0);
      expect(fakes.storage.uploadCalls, 0);
    });

    testWidgets('a publish rejected by the rules says which rule', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);
      await fakes.type(tester, 'Donated at Dhaka Medical today.');
      fakes.repository.failure = const ValidationFailure(
        messageKey: 'textTooLong',
        debugMessage: 'too long',
      );

      await tester.tap(_publishButton);
      await _settle(tester);

      expect(find.byType(ErrorBanner), findsOneWidget);
      expect(
        find.text(english.errorPostTextTooLong(PostValidator.maxTextLength)),
        findsOneWidget,
      );
    });
  });

  group('both languages, and the narrowest phone', () {
    testWidgets('speaks Bangla end to end', (WidgetTester tester) async {
      final _Compose fakes = await _pumpCompose(tester, locale: const Locale('bn'));

      expect(find.text(bangla.feedComposeTitle), findsOneWidget);
      expect(
        find.text(bangla.feedComposeTextLabel.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text(bangla.feedComposeLimit(PostValidator.maxTextLength)),
          findsOneWidget);
      expect(find.text(bangla.feedComposePublish), findsOneWidget);

      await fakes.type(tester, 'রক্ত দান করেছি।');
      fakes.storage.gate = Completer<void>();
      await tester.tap(_addTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byIcon(Icons.photo_library_outlined));
      await fakes.storage.uploadStarted.future;
      await tester.pump();

      expect(find.text(bangla.feedComposeUploading), findsOneWidget);
      fakes.storage.gate!.complete();
      await _settle(tester);

      await tester.tap(_publishButton);
      await _settle(tester);
      expect(find.text(bangla.feedComposePublished), findsOneWidget);
    });

    testWidgets('answers a failure and a discard prompt in Bangla', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(
        tester,
        locale: const Locale('bn'),
        configured: false,
      );

      // The honest "no photo bucket in this build" note, in Bangla, in place of
      // the grid the English tests saw.
      expect(find.text(bangla.feedComposePhotosNotConfigured), findsOneWidget);
      expect(find.byType(ComposeImageGrid), findsNothing);

      await fakes.type(tester, 'রক্ত দান করেছি।');
      fakes.repository.failure = const NetworkFailure(
        debugMessage: 'offline',
      );
      await tester.tap(_publishButton);
      await _settle(tester);

      expect(find.text(bangla.failureNetwork), findsOneWidget);
      expect(find.text(bangla.feedComposeDiscardTitle), findsNothing);

      await tester.tap(_backButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(bangla.feedComposeDiscardTitle), findsOneWidget);
      expect(find.text(bangla.feedComposeDiscardBody), findsOneWidget);
      expect(find.text(bangla.feedComposeKeepEditing), findsOneWidget);
      expect(find.text(bangla.feedComposeDiscardConfirm), findsOneWidget);
    });

    testWidgets('fits the narrowest phone, in Bangla, in the dark', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(
        tester,
        locale: const Locale('bn'),
        themeMode: ThemeMode.dark,
        size: const Size(320, 640),
      );

      await fakes.type(tester, 'রক্ত দান করেছি।');
      await fakes.pickFromGallery(tester);
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsOneWidget);
      await tester.ensureVisible(_publishButton);
      expect(find.text(bangla.feedComposePublish), findsOneWidget);
    });

    testWidgets('keeps its measure on a tablet', (WidgetTester tester) async {
      await _pumpCompose(tester, size: const Size(1200, 1400));

      final double width = tester.getSize(find.byType(ComposeImageGrid)).width;
      // The same 560 the feed and the profile editor use, so a long post does not
      // draw a line a reader has to follow across a desktop window.
      expect(width, closeTo(ComposePostScreen.maxContentWidth, 1));
    });
  });

  group('what a screen reader hears', () {
    testWidgets('names the publish, the slots and the upload', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);
      fakes.storage.gate = Completer<void>();
      await fakes.type(tester, 'Donated at Dhaka Medical today.');

      expect(find.bySemanticsLabel(english.feedComposePublish), findsOneWidget);
      expect(find.bySemanticsLabel(english.feedComposeAddPhoto), findsOneWidget);
      // The limit is a line of its own in the tree, so a reader hears what is
      // allowed before typing rather than finding out from a disabled button.
      expect(
        find.bySemanticsLabel(english.feedComposeLimit(PostValidator.maxTextLength)),
        findsOneWidget,
      );

      await fakes.pickFromGallery(tester);
      await fakes.storage.uploadStarted.future;
      await tester.pump();
      expect(
        find.bySemanticsLabel(english.feedComposeUploading),
        findsOneWidget,
      );
      fakes.storage.gate!.complete();
      await _settle(tester);

      // Where the name of the remove control actually sits. A Material
      // `IconButton(tooltip:)` puts its description in the node's tooltip and not
      // in its label, so `find.bySemanticsLabel` is the wrong probe: asserting a
      // label here would be a claim about this app that the framework does not
      // make. The role and the action are the parts worth pinning — a reader gets
      // a button it can press, and the name it is pressing it for.
      final SemanticsData remove = tester
          .getSemantics(find.byTooltip(english.feedComposeRemovePhoto).first)
          .getSemanticsData();
      expect(remove.tooltip, english.feedComposeRemovePhoto);
      expect(
        remove,
        isSemantics(isButton: true, isEnabled: true, hasTapAction: true),
      );
    });

    testWidgets('calls the publish a button, and stops calling it one while '
        'the draft is empty', (WidgetTester tester) async {
      final _Compose fakes = await _pumpCompose(tester);

      // The label, the role and the enabled state are what a screen reader says,
      // so all three have to be right in both states of the same button.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Publish')),
        isSemantics(label: 'Publish', isButton: true, isEnabled: false),
      );

      await fakes.type(tester, 'Donated at Dhaka Medical today.');
      expect(
        tester.getSemantics(find.bySemanticsLabel('Publish')),
        isSemantics(
          label: 'Publish',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      fakes.repository.failure = const NetworkFailure(debugMessage: 'offline');
      await tester.tap(_publishButton);
      await _settle(tester);

      // A failed write is announced rather than flashed and forgotten: the banner
      // is a live region, so a reader hears the reason without scrolling for it.
      expect(
        find.bySemanticsLabel('No connection. Check your network and try again.'),
        findsOneWidget,
      );
    });

    testWidgets('a reader can press the publish, not only hear it', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester);
      await fakes.type(tester, 'Donated at Dhaka Medical today.');

      // The activation a screen-reader user actually performs: a tap action on the
      // node the label names, with no finger and no screen coordinate involved.
      // A button that announces itself and cannot be pressed is not a button, and
      // a donor using TalkBack would be left with a post they cannot send.
      tester.semantics.tap(find.semantics.byLabel(english.feedComposePublish));
      await _settle(tester);

      expect(fakes.repository.calls, 1);
      expect(
        fakes.repository.lastDraft?.text,
        'Donated at Dhaka Medical today.',
      );
      expect(find.byType(ErrorBanner), findsNothing);
    });

    testWidgets('gives every control a real target on a small phone', (
      WidgetTester tester,
    ) async {
      final _Compose fakes = await _pumpCompose(tester, size: const Size(320, 640));
      await fakes.addOnePhoto(tester);

      // The remove disc is deliberately 44 rather than the 48 the design token
      // asks for: it sits on top of a photograph inside a 132 dp cell, and a 48
      // circle would cover a third of the thing the donor is looking at. It is
      // pinned here so the deviation stays a decision rather than an accident.
      final Size remove = tester.getSize(find.byTooltip('Remove photo'));
      expect(remove.width, greaterThanOrEqualTo(44));
      expect(remove.height, greaterThanOrEqualTo(44));

      final Size cell = tester.getSize(
        find
            .ancestor(
              of: _addTile,
              matching: find.byType(AspectRatio),
            )
            .first,
      );
      expect(cell.shortestSide, greaterThanOrEqualTo(48));
    });
  });
}

/// The route the composer is pushed from.
///
/// The composer is never the bottom of the stack in the app: the feed pushes it.
/// Mounted as `home:` a test would see an app bar with no back arrow, a pop that
/// leaves the whole app, and none of the guard's real behaviour, so every test
/// here runs against this one-frame host instead.
class _ComposeHost extends StatefulWidget {
  const _ComposeHost();

  @override
  State<_ComposeHost> createState() => _ComposeHostState();
}

class _ComposeHostState extends State<_ComposeHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration stamp) {
      if (mounted) {
        Navigator.of(context).push(ComposePostScreen.route());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: const SizedBox.expand(key: _hostKey));
  }
}
