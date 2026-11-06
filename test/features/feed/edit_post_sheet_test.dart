import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/media/photo.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/feed/application/compose_providers.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/post_image_storage.dart';
import 'package:sholovvo_app/features/feed/presentation/edit_post_sheet.dart';
import 'package:sholovvo_app/features/feed/presentation/widgets/compose_image_grid.dart';

import '../../support/fake_compose.dart';
import '../../support/fake_photo_services.dart';
import '../../support/test_app.dart';

const Size _phone = Size(430, 932);

/// A shaped post: the two image lists parallel, the way this app publishes.
Post _postWithImages() {
  final StoredPostImage image = storedImage(0);
  final DateTime stamp = DateTime.utc(2026, 10, 20, 9);
  return Post(
    id: 'post-1',
    authorUid: 'uid-verified',
    authorName: 'Ayesha Rahman',
    text: 'Donated at Dhaka Medical today.',
    imageUrls: <String>[image.url],
    imagePaths: <String>[image.path],
    createdAt: stamp,
    updatedAt: stamp,
  );
}

/// A legacy post: text only, no image lists at all — the shape that used to
/// fail on save because the edited document never gained the keys the rules ask.
Post _legacyPost() {
  final DateTime stamp = DateTime.utc(2026, 10, 20, 9);
  return Post(
    id: 'post-legacy',
    authorUid: 'uid-verified',
    authorName: 'Ayesha Rahman',
    text: 'Old post with no image lists.',
    createdAt: stamp,
    updatedAt: stamp,
  );
}

final class _Edit {
  _Edit(this.service, this.storage, this.picker);

  final FakePostEditService service;
  final FakePostImageStorage storage;
  final FakePhotoPicker picker;
}

/// Mounts the edit sheet over fakes for every seam it touches.
Future<_Edit> _pumpSheet(
  WidgetTester tester,
  Post post, {
  FakePostEditService? service,
  FakePostImageStorage? storage,
  FakePhotoPicker? picker,
}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final FakePostEditService editService = service ?? FakePostEditService();
  final FakePostImageStorage imageStorage = storage ?? FakePostImageStorage();
  final FakePhotoPicker photoPicker =
      picker ?? FakePhotoPicker(candidate: PhotoCandidate(bytes: jpegBytes()));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authUidProvider.overrideWithValue('uid-verified'),
        postEditServiceProvider.overrideWithValue(editService),
        postImageStorageProvider.overrideWithValue(imageStorage),
        postPhotoPickerProvider.overrideWithValue(photoPicker),
      ],
      child: testApp(home: _SheetHost(post: post)),
    ),
  );
  await _settle(tester);
  return _Edit(editService, imageStorage, photoPicker);
}

/// The `home` route beneath [testApp]'s `Navigator`. It opens the edit sheet on
/// the frame after it mounts, from a context that is genuinely under the
/// `MaterialApp` — a `showModalBottomSheet` needs that `Navigator` to host the
/// sheet's `Overlay`, so the host must sit inside the app, not above it.
class _SheetHost extends StatefulWidget {
  const _SheetHost({required this.post});

  final Post post;

  @override
  State<_SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<_SheetHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        EditPostSheet.show(context, post: widget.post);
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: SizedBox.shrink());
}

/// A few frames — the bottom sheet's entrance and any resolved write.
///
/// `pumpAndSettle` is avoided because the upload spinner in the grid never
/// settles while an upload gate is held open.
Future<void> _settle(WidgetTester tester, [int frames = 6]) async {
  for (int index = 0; index < frames; index++) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Finder get _saveButton => find.widgetWithText(SolovvoButton, 'Save changes');
Finder get _addTile => find.byIcon(Icons.add_a_photo_outlined);
Finder get _removePhoto => find.byTooltip('Remove photo');

void main() {
  group('EditPostSheet photographs', () {
    testWidgets('shows the post\'s current photo and an add tile', (
      WidgetTester tester,
    ) async {
      await _pumpSheet(tester, _postWithImages());

      expect(find.byType(ComposeImageGrid), findsOneWidget);
      expect(find.text('Photos'), findsOneWidget);
      expect(_removePhoto, findsOneWidget);
      expect(_addTile, findsOneWidget);
    });

    testWidgets('a legacy text-only post still opens and offers to add', (
      WidgetTester tester,
    ) async {
      await _pumpSheet(tester, _legacyPost());

      // The whole point of the fix: a post that carries no image lists is not
      // refused. The sheet opens on the text and offers an empty grid.
      expect(find.byType(ComposeImageGrid), findsOneWidget);
      expect(_addTile, findsOneWidget);
      expect(_removePhoto, findsNothing);
    });

    testWidgets('adding a photo uploads it into the grid', (
      WidgetTester tester,
    ) async {
      final _Edit fakes = await _pumpSheet(tester, _legacyPost());

      await tester.tap(_addTile);
      await _settle(tester);
      await tester.tap(find.byIcon(Icons.photo_library_outlined));
      await _settle(tester);

      expect(fakes.picker.calls, 1);
      expect(fakes.storage.uploadCalls, 1);
      expect(_removePhoto, findsOneWidget);
    });

    testWidgets('removing a photo drops it and deletes the object', (
      WidgetTester tester,
    ) async {
      final _Edit fakes = await _pumpSheet(tester, _postWithImages());

      await tester.tap(_removePhoto);
      await _settle(tester);

      expect(fakes.storage.removedPaths, <String>[storedImage(0).path]);
      expect(_removePhoto, findsNothing);
    });
  });

  group('EditPostSheet save', () {
    testWidgets('submits the new text with parallel image lists', (
      WidgetTester tester,
    ) async {
      final _Edit fakes = await _pumpSheet(tester, _postWithImages());

      await tester.enterText(find.byType(TextField), 'Edited story of the drive.');
      await tester.tap(_saveButton);
      await _settle(tester);

      expect(fakes.service.editCalls, 1);
      expect(fakes.service.lastEditedText, 'Edited story of the drive.');
      expect(fakes.service.lastImageUrls, <String>[storedImage(0).url]);
      expect(fakes.service.lastImagePaths, <String>[storedImage(0).path]);
    });

    testWidgets('a legacy post save sends empty lists, fixing the old failure', (
      WidgetTester tester,
    ) async {
      final _Edit fakes = await _pumpSheet(tester, _legacyPost());

      await tester.enterText(find.byType(TextField), 'Now it saves.');
      await tester.tap(_saveButton);
      await _settle(tester);

      // The normalisation: a text-only edit on a legacy post now writes the two
      // (empty) lists, so the stored document satisfies the rules and the save
      // lands instead of reporting "could not save your changes".
      expect(fakes.service.editCalls, 1);
      expect(fakes.service.lastImageUrls, isEmpty);
      expect(fakes.service.lastImagePaths, isEmpty);
    });

    testWidgets('a network failure is shown, not swallowed', (
      WidgetTester tester,
    ) async {
      final _Edit fakes = await _pumpSheet(
        tester,
        _legacyPost(),
        service: FakePostEditService()
          ..editFailure = const NetworkFailure(debugMessage: 'offline'),
      );

      await tester.enterText(find.byType(TextField), 'Retype me.');
      await tester.tap(_saveButton);
      await _settle(tester);

      expect(
        find.text('No connection. Check your network and try again.'),
        findsOneWidget,
      );
      expect(fakes.service.editCalls, 1);
    });
  });

  group('EditPostSheet delete', () {
    testWidgets('deleting the post also removes its stored photos', (
      WidgetTester tester,
    ) async {
      final _Edit fakes = await _pumpSheet(tester, _postWithImages());

      final Finder deleteButton = find.widgetWithText(TextButton, 'Delete post');
      await tester.ensureVisible(deleteButton);
      await tester.tap(deleteButton);
      await _settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await _settle(tester);

      // The regression this pins: the Firestore delete leaves the bucket alone,
      // so the sheet must remove the post's own photos or they orphan there.
      expect(fakes.service.deleteCalls, 1);
      expect(fakes.storage.removedPaths, <String>[storedImage(0).path]);
    });

    testWidgets('a failed delete leaves the photos untouched', (
      WidgetTester tester,
    ) async {
      final _Edit fakes = await _pumpSheet(
        tester,
        _postWithImages(),
        service: FakePostEditService()
          ..deleteFailure = const NetworkFailure(debugMessage: 'offline'),
      );

      final Finder deleteButton = find.widgetWithText(TextButton, 'Delete post');
      await tester.ensureVisible(deleteButton);
      await tester.tap(deleteButton);
      await _settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await _settle(tester);

      // The document is still there, so its photos must stay: cleanup runs only
      // after a successful delete, never on a failure.
      expect(fakes.service.deleteCalls, 1);
      expect(fakes.storage.removedPaths, isEmpty);
      expect(find.text('Could not delete the post.'), findsOneWidget);
    });
  });
}
