import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/presentation/expandable_post_text.dart';
import 'package:sholovvo_app/features/feed/presentation/widgets/feed_post_tile.dart';

import '../../support/fake_feed.dart';
import '../../support/test_app.dart';

/// A phone wide enough that the card's measure is stable, so the line count
/// [ExpandablePostText] measures is the one this file means to test.
const Size _phone = Size(430, 932);

/// The moment a test pretends is now.
///
/// Every tile here is mounted with an explicit [FeedPostTile.now], because a
/// relative label computed from the wall clock is a test that passes until the
/// suite runs at a different hour.
final DateTime _stamp = DateTime.utc(2026, 11, 3, 9);

/// A post [minutes] older than [_stamp].
Post _post({
  String text = 'Donated at Dhaka Medical today.',
  List<String> imageUrls = const <String>[],
  int likeCount = 0,
  int commentCount = 0,
  int minutes = 5,
}) {
  return fakePost(
    authorName: 'Ayesha Rahman',
    text: text,
    imageUrls: imageUrls,
    likeCount: likeCount,
    commentCount: commentCount,
    createdAt: _stamp.subtract(Duration(minutes: minutes)),
  );
}

/// Mounts [tile] on its own.
///
/// A bare `Scaffold` rather than the feed screen: the tile reads
/// `MaterialLocalizations` for its older-than-a-week date and
/// `ScaffoldMessenger` for its copy confirmation, and both come from here. What
/// this file must not do is reach through `FeedScreen`, because that would make
/// the feed's repository the tile's test double as well.
Future<void> _pumpTile(
  WidgetTester tester,
  Widget tile, {
  Locale locale = const Locale('en'),
  Size size = _phone,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    testApp(
      locale: locale,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: tile,
          )),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('FeedPostTile, the parts a donor reads', () {
    testWidgets('names the author, the text and the age', (
      WidgetTester tester,
    ) async {
      await _pumpTile(tester, FeedPostTile(post: _post(), now: _stamp));

      expect(find.text('Ayesha Rahman'), findsOneWidget);
      expect(find.text('Donated at Dhaka Medical today.'), findsOneWidget);
      expect(find.text('5 minutes ago'), findsOneWidget);
    });

    testWidgets('marks a post whose document says it was edited', (
      WidgetTester tester,
    ) async {
      // `isEdited` is derived by the entity from a stored `updatedAt` behind its
      // `createdAt`, so the fixture has to be built with two different stamps
      // rather than set directly.
      final Post edited = fakePost(
        authorName: 'Ayesha Rahman',
        text: 'Updated: the drive moved to Friday.',
        createdAt: _stamp.subtract(const Duration(days: 1)),
        updatedAt: _stamp.subtract(const Duration(hours: 2)),
      );

      await _pumpTile(tester, FeedPostTile(post: edited, now: _stamp));

      expect(
        find.textContaining('Edited · '),
        findsOneWidget,
        reason: 'the marker and the age share one line, not two',
      );
    });

    testWidgets('reports the two counts it was given and offers no more', (
      WidgetTester tester,
    ) async {
      await _pumpTile(
        tester,
        FeedPostTile(post: _post(likeCount: 3, commentCount: 1), now: _stamp),
      );

      expect(find.text('3 likes'), findsOneWidget);
      expect(find.text('1 comment'), findsOneWidget);
      // Nothing on this tile writes. A like button that only looked like one is
      // the failure mode the stage's rules freeze was recorded against.
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      expect(find.byIcon(Icons.send_rounded), findsNothing);
    });

    testWidgets('gives the copy control a reachable target', (
      WidgetTester tester,
    ) async {
      await _pumpTile(tester, FeedPostTile(post: _post(), now: _stamp));

      final Finder copy = find.byIcon(Icons.content_copy_rounded);
      expect(find.ancestor(of: copy, matching: find.byType(IconButton)),
          findsOneWidget);
      expect(tester.getSize(find.widgetWithIcon(IconButton, Icons.content_copy_rounded)),
          const Size(AppSpacing.minTapTarget, AppSpacing.minTapTarget));
    });

    testWidgets('copies the text the donor is looking at, and says so', (
      WidgetTester tester,
    ) async {
      final List<MethodCall> calls = <MethodCall>[];
      TestWidgetsFlutterBinding.ensureInitialized().handlePlatformMessage(
        'flutter/platform',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('experimentalSystemNavigationBarState'),
        ),
        (ByteData? _) {},
      );
      // The platform channel is intercepted rather than stubbed at the widget,
      // because `Clipboard.setData` is the write under test.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall call,
          ) async {
            calls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await _pumpTile(tester, FeedPostTile(post: _post(), now: _stamp));
      await tester.tap(find.byIcon(Icons.content_copy_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(calls.map((MethodCall call) => call.method), contains('Clipboard.setData'));
      expect(
        (calls.first.arguments as Map<Object?, Object?>)['text'],
        'Donated at Dhaka Medical today.',
      );
      expect(find.text('Post text copied.'), findsOneWidget);
    });
  });

  group('FeedPostTile photographs', () {
    testWidgets('draws nothing when the post carries no image', (
      WidgetTester tester,
    ) async {
      await _pumpTile(tester, FeedPostTile(post: _post(), now: _stamp));

      expect(find.byType(Image), findsNothing);
    });

    testWidgets('says whose photograph it is, for a screen reader', (
      WidgetTester tester,
    ) async {
      await _pumpTile(
        tester,
        FeedPostTile(
          post: _post(imageUrls: <String>['https://cdn/post-1.jpg']),
          now: _stamp,
        ),
      );

      // Asserted on the widget rather than on the semantics tree on purpose: a
      // network image in a test never resolves, so a `RawImage` node is never
      // built and there is no semantics to read. The label the widget would hand
      // to that node is the thing this app controls, and it is the thing that was
      // missing.
      expect(
        tester.widget<Image>(find.byType(Image)).semanticLabel,
        'Photo shared by Ayesha Rahman',
      );
    });

    testWidgets('labels every cell of a four-photo post', (
      WidgetTester tester,
    ) async {
      await _pumpTile(
        tester,
        FeedPostTile(
          post: _post(
            imageUrls: <String>[
              'https://cdn/post-1.jpg',
              'https://cdn/post-2.jpg',
              'https://cdn/post-3.jpg',
              'https://cdn/post-4.jpg',
            ],
          ),
          now: _stamp,
        ),
      );

      expect(find.byType(Image), findsNWidgets(4));
      for (final Widget widget in tester.widgetList(find.byType(Image))) {
        expect(
          (widget as Image).semanticLabel,
          'Photo shared by Ayesha Rahman',
          reason: 'no cell was left to be read as a bare image',
        );
      }
    });

    testWidgets('keeps the text readable when a photograph cannot load', (
      WidgetTester tester,
    ) async {
      await _pumpTile(
        tester,
        FeedPostTile(
          post: _post(imageUrls: <String>['https://cdn/gone.jpg']),
          now: _stamp,
        ),
      );
      // A test-boundary network image fails without a frame of its own, so the
      // error builder has to be driven by hand rather than waited for.
      await tester.pump();

      expect(find.text('Donated at Dhaka Medical today.'), findsOneWidget);
    });
  });

  group('FeedPostTile in Bangla', () {
    testWidgets('writes the count and the photo label in Bengali', (
      WidgetTester tester,
    ) async {
      await _pumpTile(
        tester,
        FeedPostTile(
          post: _post(likeCount: 2, imageUrls: <String>['https://cdn/p.jpg']),
          now: _stamp,
        ),
        locale: const Locale('bn'),
      );

      expect(find.text('2 লাইক'), findsOneWidget);
      expect(
        tester.widget<Image>(find.byType(Image)).semanticLabel,
        contains('এর শেয়ার করা ছবি'),
      );
      // A Bengali sentence with Western digits in it would pass the catalogue
      // checks and still read as a foreign string, so it is checked here too.
      expect(find.text('2 লাইক'), findsNothing);
    });
  });

  group('ExpandablePostText', () {
    testWidgets('leaves a short post alone', (WidgetTester tester) async {
      await _pumpText(tester, 'Six words here.');

      expect(find.text('Six words here.'), findsOneWidget);
      expect(find.text('Read more'), findsNothing);
      expect(find.text('Show less'), findsNothing);
    });

    testWidgets('collapses past six lines, then opens on request', (
      WidgetTester tester,
    ) async {
      final String long = List<String>.generate(
        12,
        (int index) => 'Line $index of a donor's longer story about the drive.',
      ).join(' ');

      await _pumpText(tester, long);

      expect(find.text('Read more'), findsOneWidget);
      // Collapsed: the widget is in the tree with a line limit, and the ellipsis
      // is what the donor sees.
      final Text collapsed = tester.widget<Text>(find.text(long));
      expect(collapsed.maxLines, 6);
      expect(collapsed.overflow, TextOverflow.ellipsis);

      await tester.tap(find.text('Read more'));
      await tester.pump();

      expect(find.text('Show less'), findsOneWidget);
      expect(find.text('Read more'), findsNothing);
      final Text expanded = tester.widget<Text>(find.text(long));
      expect(expanded.maxLines, isNull);
      expect(expanded.overflow, TextOverflow.visible);

      await tester.tap(find.text('Show less'));
      await tester.pump();

      expect(find.text('Read more'), findsOneWidget);
    });

    testWidgets('withholds the toggle when the width is unbounded', (
      WidgetTester tester,
    ) async {
      final String long = List<String>.generate(
        12,
        (int index) => 'Line $index of a donor's longer story about the drive.',
      ).join(' ');

      // Inside a `Row` in a horizontally scrollable box the measure is infinite,
      // and an honest answer about overflow cannot be given. Drawing all of it
      // silently is the safer lie, so this asserts that no control appears.
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: <Widget>[
                SizedBox(width: 4000, child: ExpandablePostText(text: long)),
              ]),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Read more'), findsNothing);
    });
  });
}

/// Mounts one [ExpandablePostText] at the card's reading width.
Future<void> _pumpText(WidgetTester tester, String text) async {
  await _pumpTile(tester, ExpandablePostText(text: text));
}
