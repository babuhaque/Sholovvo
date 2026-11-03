import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/media/photo_picker.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/post_image_storage.dart';
import 'package:sholovvo_app/features/feed/presentation/compose_post_screen.dart';
import 'package:sholovvo_app/features/feed/presentation/widgets/compose_image_grid.dart';

import '../../support/fake_compose.dart';
import '../../support/test_app.dart';

const Size _phone = Size(430, 932);

Finder get _addTile => find.byIcon(Icons.add_a_photo_outlined);
Finder get _spinner => find.byType(CircularProgressIndicator);
Finder get _cells => find.byType(AspectRatio);

/// What the grid was asked to do, in the order it was asked.
///
/// The grid is a pure widget: it owns no state and touches no service. Every one
/// of these tests can therefore be answered by what it drew and what it reported,
/// which is what makes them fast and what makes them meaningful — a callback the
/// screen never receives is a photo the donor will never see.
final class _Actions {
  final List<PhotoSource> added = <PhotoSource>[];
  final List<StoredPostImage> removed = <StoredPostImage>[];

  void onAdd(PhotoSource source) => added.add(source);
  void onRemove(StoredPostImage image) => removed.add(image);
}

/// Mounts the grid at the measure the compose screen gives it.
///
/// Deliberately inside the same padding, `ConstrainedBox` and scrolling column as
/// the screen, so a layout verdict here is a verdict about the grid as shipped and
/// not about a grid floating in a vacuum.
Future<_Actions> _pumpGrid(
  WidgetTester tester, {
  List<StoredPostImage> images = const <StoredPostImage>[],
  bool isUploading = false,
  bool enabled = true,
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
  Size size = _phone,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final _Actions actions = _Actions();
  await tester.pumpWidget(
    testApp(
      locale: locale,
      themeMode: themeMode,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: ComposePostScreen.maxContentWidth,
              ),
              child: ComposeImageGrid(
                images: images,
                isUploading: isUploading,
                enabled: enabled,
                onAdd: actions.onAdd,
                onRemove: actions.onRemove,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return actions;
}

/// [PostValidator.maxImages] stored photos, each with its own URL.
List<StoredPostImage> _images(int count) {
  return <StoredPostImage>[
    for (int index = 0; index < count; index++) storedImage(index),
  ];
}

/// Opens the source sheet, lets it arrive, and taps one of its two rows.
Future<void> _choose(WidgetTester tester, {PhotoSource source = PhotoSource.gallery}) async {
  await tester.tap(_addTile);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(
    find.byIcon(
      source == PhotoSource.gallery
          ? Icons.photo_library_outlined
          : Icons.photo_camera_outlined,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('the grid always holds four cells', () {
    for (int count = 0; count <= PostValidator.maxImages; count++) {
      testWidgets('with $count photo(s) attached', (
        WidgetTester tester,
      ) async {
        await _pumpGrid(tester, images: _images(count));

        // The grid is the statement of the capacity: a donor sees what is filled,
        // the one way to add, and how many are left, without a caption.
        expect(_cells, findsNWidgets(PostValidator.maxImages));
        expect(find.byType(Image), findsNWidgets(count));
        expect(
          _addTile,
          count < PostValidator.maxImages ? findsOneWidget : findsNothing,
        );
        expect(find.text('Add photo'), findsNWidgets(count < 4 ? 1 : 0));
      });
    }

    testWidgets('fills the first row before the second', (
      WidgetTester tester,
    ) async {
      await _pumpGrid(tester, images: _images(2));

      final Iterable<Rect> photos = find.byType(Image).evaluate().map(
        (Element element) => tester.getRect(find.byWidget(element.widget)),
      );
      final List<Rect> cells = <Rect>[
        for (int index = 0; index < 4; index++)
          tester.getRect(_cells.at(index)),
      ];

      // Positional, not a hole: photo one is in cell one and photo two in cell
      // two, so removing the first shifts the second left rather than leaving a
      // gap a donor reads as a lost picture.
      expect(photos.elementAt(0).topLeft.dx, closeTo(cells[0].topLeft.dx, 0.5));
      expect(photos.elementAt(0).topLeft.dy, closeTo(cells[0].topLeft.dy, 0.5));
      expect(photos.elementAt(1).topLeft.dx, closeTo(cells[1].topLeft.dx, 0.5));
      expect(photos.elementAt(1).topLeft.dy, closeTo(cells[1].topLeft.dy, 0.5));
      expect(cells[0].top, lessThan(cells[2].top), reason: 'two rows of two');
    });

    testWidgets('every cell is square', (WidgetTester tester) async {
      await _pumpGrid(tester, images: _images(1));

      for (int index = 0; index < PostValidator.maxImages; index++) {
        final Size cell = tester.getSize(_cells.at(index));
        expect(cell.width, closeTo(cell.height, 0.5));
      }
    });
  });

  group('adding a photo', () {
    testWidgets('opens a sheet rather than two side-by-side buttons', (
      WidgetTester tester,
    ) async {
      final _Actions actions = await _pumpGrid(tester);

      await tester.tap(_addTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Choose from gallery'), findsOneWidget);
      expect(find.text('Take a photo'), findsOneWidget);
      // Two labels that fit inside a 152 dp cell in neither language: Bangla is
      // the longer of the two, and a truncated "গ্যালারি…" is indistinguishable
      // from the other half of the pair.
      expect(actions.added, isEmpty);
    });

    testWidgets('reports the gallery choice once, and only then', (
      WidgetTester tester,
    ) async {
      final _Actions actions = await _pumpGrid(tester);

      await tester.tap(_addTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(actions.added, isEmpty, reason: 'opening the sheet is not choosing');

      await tester.tap(find.byIcon(Icons.photo_library_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(actions.added, <PhotoSource>[PhotoSource.gallery]);
      expect(find.text('Choose from gallery'), findsNothing);
    });

    testWidgets('reports the camera choice', (WidgetTester tester) async {
      final _Actions actions = await _pumpGrid(tester);

      await _choose(tester, source: PhotoSource.camera);

      expect(actions.added, <PhotoSource>[PhotoSource.camera]);
    });

    testWidgets('a sheet closed without a choice adds nothing', (
      WidgetTester tester,
    ) async {
      final _Actions actions = await _pumpGrid(tester);

      await tester.tap(_addTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // The scrim, above the sheet on a phone-sized window.
      await tester.tapAt(const Offset(215, 40));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(actions.added, isEmpty);
      expect(_addTile, findsOneWidget);
    });

    testWidgets('offers no way in once the four slots are full', (
      WidgetTester tester,
    ) async {
      final _Actions actions = await _pumpGrid(tester, images: _images(4));

      // The limit is drawn, not explained: with four photos there is no tile to
      // tap, so a fifth photo cannot be asked for in the first place.
      expect(_addTile, findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsNWidgets(4));
      expect(actions.added, isEmpty);
    });
  });

  group('removing a photo', () {
    testWidgets('names the photo it was given, not the first one', (
      WidgetTester tester,
    ) async {
      final List<StoredPostImage> images = _images(3);
      final _Actions actions = await _pumpGrid(tester, images: images);

      await tester.tap(find.byTooltip('Remove photo').last);

      expect(actions.removed, <StoredPostImage>[images[2]]);
    });

    testWidgets('gives every photo its own control', (
      WidgetTester tester,
    ) async {
      await _pumpGrid(tester, images: _images(3));

      expect(find.byTooltip('Remove photo'), findsNWidgets(3));
    });

    testWidgets('the control survives a picture that has gone', (
      WidgetTester tester,
    ) async {
      // The test renderer answers every network image with 400, which is exactly
      // the case here: the object is in the draft whether or not it can be drawn,
      // and a donor who cannot see it must still be able to take it out.
      await _pumpGrid(tester, images: _images(2));
      await tester.pump();

      expect(find.byTooltip('Remove photo'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  group('the uploading state', () {
    testWidgets('turns the add tile into a spinner in place', (
      WidgetTester tester,
    ) async {
      await _pumpGrid(tester, isUploading: true);

      expect(_spinner, findsOneWidget);
      expect(find.text(english.feedComposeUploading), findsOneWidget);
      expect(_addTile, findsNothing);
      expect(_cells, findsNWidgets(PostValidator.maxImages));
    });

    testWidgets('cannot be tapped into a second upload', (
      WidgetTester tester,
    ) async {
      final _Actions actions = await _pumpGrid(tester, isUploading: true);

      expect(
        tester.widget<InkWell>(find.byType(InkWell)).onTap,
        isNull,
        reason: 'a second pick would queue behind one the donor cannot see',
      );
      expect(actions.added, isEmpty);
    });

    testWidgets('leaves the photos already stored where they are', (
      WidgetTester tester,
    ) async {
      await _pumpGrid(tester, images: _images(2), isUploading: true);

      expect(find.byType(Image), findsNWidgets(2));
      expect(_spinner, findsOneWidget);
      // Still four cells: the third is busy, the fourth waits.
      expect(_cells, findsNWidgets(PostValidator.maxImages));
    });

    testWidgets('shows no spinner when nothing is in flight', (
      WidgetTester tester,
    ) async {
      await _pumpGrid(tester, images: _images(1));

      expect(_spinner, findsNothing);
      expect(find.text(english.feedComposeUploading), findsNothing);
    });
  });

  group('a grid frozen by a publish', () {
    testWidgets('opens nothing and removes nothing', (
      WidgetTester tester,
    ) async {
      final _Actions actions = await _pumpGrid(
        tester,
        images: _images(2),
        enabled: false,
      );

      expect(
        tester.widget<InkWell>(
          find.ancestor(of: _addTile, matching: find.byType(InkWell)),
        ).onTap,
        isNull,
      );
      // The removal controls are the grid's only icon buttons, so reading them
      // from their own type is both the whole set and no guesswork: `find.byTooltip`
      // answers with the tooltip widget rather than the button behind the words.
      final Iterable<IconButton> controls = find
          .byType(IconButton)
          .evaluate()
          .map((Element element) => element.widget as IconButton);
      expect(controls, hasLength(2));
      for (final IconButton control in controls) {
        expect(control.onPressed, isNull);
      }
      expect(actions.added, isEmpty);
      expect(actions.removed, isEmpty);
    });

    testWidgets('still shows the photos it holds', (WidgetTester tester) async {
      await _pumpGrid(tester, images: _images(3), enabled: false);

      expect(find.byType(Image), findsNWidgets(3));
      expect(_cells, findsNWidgets(PostValidator.maxImages));
    });
  });

  group('both languages, every width', () {
    testWidgets('says the same three things in Bangla', (
      WidgetTester tester,
    ) async {
      await _pumpGrid(tester, locale: const Locale('bn'), images: _images(1));

      expect(find.text(bangla.feedComposeAddPhoto), findsOneWidget);
      expect(find.byTooltip(bangla.feedComposeRemovePhoto), findsOneWidget);

      await tester.tap(_addTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(bangla.feedComposeFromGallery), findsOneWidget);
      expect(find.text(bangla.feedComposeFromCamera), findsOneWidget);
    });

    testWidgets('says it is busy in Bangla', (WidgetTester tester) async {
      await _pumpGrid(tester, locale: const Locale('bn'), isUploading: true);

      expect(find.text(bangla.feedComposeUploading), findsOneWidget);
      expect(find.text(english.feedComposeUploading), findsNothing);
    });

    for (final double width in <double>[320, 360, 430]) {
      for (final Locale locale in <Locale>[
        const Locale('en'),
        const Locale('bn'),
      ]) {
        testWidgets(
          'holds a full grid at ${width.toInt()} dp in ${locale.languageCode}, '
          'light and dark',
          (WidgetTester tester,
        ) async {
          for (final ThemeMode mode in <ThemeMode>[
            ThemeMode.light,
            ThemeMode.dark,
          ]) {
            await _pumpGrid(
              tester,
              images: _images(PostValidator.maxImages),
              locale: locale,
              themeMode: mode,
              size: Size(width, 640),
            );

            // A RenderFlex overflow is thrown, so this is a real layout verdict
            // rather than a look: four cells, two rows, nothing spilling.
            expect(tester.takeException(), isNull);
            expect(_cells, findsNWidgets(PostValidator.maxImages));
            // The removal controls are counted by icon: their tooltip is a
            // localised string, and this test runs in both languages.
            expect(find.byIcon(Icons.close_rounded), findsNWidgets(4));
          }

          await _pumpGrid(
            tester,
            isUploading: true,
            locale: locale,
            size: Size(width, 640),
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        },
        );
      }
    }

    testWidgets('keeps the add tile inside its cell at the narrowest width', (
      WidgetTester tester,
    ) async {
      await _pumpGrid(tester, size: const Size(320, 640), locale: const Locale('bn'));

      final Size cell = tester.getSize(_cells.first);
      final Size label = tester.getSize(find.text(bangla.feedComposeAddPhoto));
      // The label truncates with an ellipsis rather than pushing the row wide:
      // what matters is that it stays inside the cell it was measured for.
      expect(label.width, lessThanOrEqualTo(cell.width));
      expect(cell.shortestSide, greaterThanOrEqualTo(AppSpacing.minTapTarget));
    });
  });

  group('what a screen reader hears', () {
    testWidgets('names the add tile, and says so when it is busy', (
      WidgetTester tester,
    ) async {
      await _pumpGrid(tester, images: _images(2));
      expect(
        find.bySemanticsLabel(english.feedComposeAddPhoto),
        findsOneWidget,
      );

      await _pumpGrid(tester, isUploading: true);
      expect(
        find.bySemanticsLabel(english.feedComposeUploading),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(english.feedComposeAddPhoto),
        findsNothing,
      );
    });

    testWidgets('names every removal and gives each one a press', (
      WidgetTester tester,
    ) async {
      await _pumpGrid(tester, images: _images(2));

      // Two half-truths worth separating. The word a reader hears arrives on the
      // node's tooltip, not its label, because that is where a Material
      // `IconButton(tooltip:)` puts it — so `find.bySemanticsLabel` finds nothing
      // here and that gap is the framework's, not this grid's. What this file
      // owns is that every photo gets its own control, that the control is named,
      // and that it can actually be activated.
      final List<SemanticsData> controls = <SemanticsData>[
        for (final Element element in find.byTooltip(
              english.feedComposeRemovePhoto,
            ).evaluate())
          tester
              .getSemantics(find.byWidget(element.widget))
              .getSemanticsData(),
      ];
      expect(controls, hasLength(2));
      for (final SemanticsData control in controls) {
        expect(control.tooltip, english.feedComposeRemovePhoto);
        expect(
          control,
          isSemantics(isButton: true, isEnabled: true, hasTapAction: true),
        );
      }
    });

    testWidgets('says the one thing a full grid has to say', (
      WidgetTester tester,
    ) async {
      await _pumpGrid(tester, images: _images(1));

      // One add tile: the empty squares are decoration, and a donor listening to
      // the grid should hear one invitation rather than four, three of them about
      // nothing at all.
      expect(
        find.bySemanticsLabel(english.feedComposeAddPhoto),
        findsOneWidget,
      );
    });
  });
}
