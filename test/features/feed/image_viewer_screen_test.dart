import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/presentation/image_viewer_screen.dart';

import '../../support/fake_photo_services.dart';
import '../../support/test_app.dart';

const Size _phone = Size(430, 932);

const String _urlA = 'https://cdn/post-1.jpg';
const String _urlB = 'https://cdn/post-2.jpg';

/// Mounts the viewer over a [FakeGallerySaver], pushing its route under a host.
///
/// The screen is a `ConsumerStatefulWidget` that reads [gallerySaverProvider],
/// so it is mounted inside a [ProviderScope] the way the composer tests mount
/// their screens — the seam is overridden rather than a real `gal`/`http` write
/// attempted against a platform the test binding cannot answer.
Future<FakeGallerySaver> _pumpViewer(
  WidgetTester tester, {
  required List<String> urls,
  int initialIndex = 0,
  FakeGallerySaver? saver,
}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final FakeGallerySaver gallery = saver ?? FakeGallerySaver();
  final _ViewerHost host = _ViewerHost(urls, initialIndex);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [gallerySaverProvider.overrideWithValue(gallery)],
      child: testApp(home: host),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return gallery;
}

/// A host that pushes the viewer route once, on the frame after it mounts.
class _ViewerHost extends StatefulWidget {
  const _ViewerHost(this.urls, this.initialIndex);

  final List<String> urls;
  final int initialIndex;

  @override
  State<_ViewerHost> createState() => _ViewerHostState();
}

class _ViewerHostState extends State<_ViewerHost> {
  bool _pushed = false;

  @override
  Widget build(BuildContext context) {
    if (!_pushed) {
      _pushed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).push(
          ImageViewerScreen.route(widget.urls, initialIndex: widget.initialIndex),
        );
      });
    }
    return const Scaffold(body: SizedBox.shrink());
  }
}

Finder get _downloadButton => find.byIcon(Icons.download_rounded);

void main() {
  group('ImageViewerScreen download to gallery', () {
    testWidgets('offers a download control', (WidgetTester tester) async {
      await _pumpViewer(tester, urls: <String>[_urlA]);

      expect(_downloadButton, findsOneWidget);
      expect(find.byTooltip('Download'), findsOneWidget);
    });

    testWidgets('saves the visible photo and confirms it', (
      WidgetTester tester,
    ) async {
      final FakeGallerySaver gallery = await _pumpViewer(
        tester,
        urls: <String>[_urlA],
      );

      await tester.tap(_downloadButton);
      await tester.pump();
      await tester.pump();

      expect(gallery.calls, 1);
      expect(gallery.lastUrl, _urlA);
      expect(find.text('Saved to your gallery.'), findsOneWidget);
    });

    testWidgets('reports a network failure honestly', (
      WidgetTester tester,
    ) async {
      final FakeGallerySaver gallery = FakeGallerySaver(
        failure: const NetworkFailure(debugMessage: 'offline'),
      );
      await _pumpViewer(tester, urls: <String>[_urlA], saver: gallery);

      await tester.tap(_downloadButton);
      await tester.pump();
      await tester.pump();

      expect(find.text('Could not download this photo.'), findsOneWidget);
      expect(find.text('Saved to your gallery.'), findsNothing);
    });

    testWidgets('names a denied permission as the reason', (
      WidgetTester tester,
    ) async {
      final FakeGallerySaver gallery = FakeGallerySaver(
        failure: const PermissionFailure(debugMessage: 'denied'),
      );
      await _pumpViewer(tester, urls: <String>[_urlA], saver: gallery);

      await tester.tap(_downloadButton);
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Solovvo needs permission to save to your gallery.'),
        findsOneWidget,
      );
    });

    testWidgets('saves the photo the donor is looking at, not the first', (
      WidgetTester tester,
    ) async {
      final FakeGallerySaver gallery = await _pumpViewer(
        tester,
        urls: <String>[_urlA, _urlB],
        initialIndex: 1,
      );

      await tester.tap(_downloadButton);
      await tester.pump();
      await tester.pump();

      // With two images the page indicator shows "2 / 2", and the download must
      // name the second url because that is the page under the viewer.
      expect(find.text('2 / 2'), findsOneWidget);
      expect(gallery.lastUrl, _urlB);
    });
  });
}
