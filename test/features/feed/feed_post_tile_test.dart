import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/presentation/expandable_post_text.dart';
import 'package:sholovvo_app/features/feed/presentation/widgets/feed_post_tile.dart';

import '../../support/fake_feed.dart';
import '../../support/test_app.dart';

/// A phone, for the width the card is read at.
const Size _phone = Size(430, 932);

/// The measure the feed gives a tile on a phone, so the line count
/// [ExpandablePostText] measures is the one this file means to test.
const double _cardWidth = 380;

/// The moment a test pretends is now.
///
/// Every tile here is mounted with an explicit [FeedPostTile.now], because a
/// relative label computed from the wall clock is a test that passes until the
/// suite happens to run at a different hour.
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

/// The same post, with an edit recorded against it.
Post _editedPost() {
  final DateTime created = _stamp.subtract(const Duration(days: 1));
  return Post(
    id: 'post-1',
    authorUid: 'uid-verified',
    authorName: 'Ayesha Rahman',
    text: 'Updated: the drive moved to Friday.',
    imageUrls: const <String>[],
    createdAt: created,
    updatedAt: _stamp.subtract(const Duration(hours: 2)),
    editedAt: _stamp.subtract(const Duration(hours: 2)),
  );
}

/// Mounts [tile] on its own, at the feed's phone measure.
///
/// A bare `Scaffold` rather than `FeedScreen`, on purpose. The tile needs
/// `MaterialLocalizations` for its older-than-a-week date and `ScaffoldMessenger`
/// for its copy confirmation, and this supplies both. Reaching through the feed
/// screen instead would make that screen's repository this tile's test double too,
/// so a change to paging could fail a test about one card.
Future<void> _pumpTile(
  WidgetTester tester,
  Widget tile, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    testApp(
      locale: locale,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(
            child: SizedBox(width: _cardWidth, child: tile),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// One paragraph long enough to need collapsing at [_cardWidth].
final String _long = List<String>.generate(
  14,
  (int index) => 'Line $index of the story about the drive last Friday.',
).join(' ');

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

    testWidgets('marks a post that was edited, on the age line', (
      WidgetTester tester,
    ) async {
      await _pumpTile(tester, FeedPostTile(post: _editedPost(), now: _stamp));

      // One line, not two: the marker qualifies the age rather than replacing it,
      // so a donor who edits sees when the post went out and that it changed.
      expect(find.textContaining('Edited · '), findsOneWidget);
      expect(find.text('Edited'), findsNothing);
    });

    testWidgets('reports the two counts it was given, and offers no more', (
      WidgetTester tester,
    ) async {
      await _pumpTile(
        tester,
        FeedPostTile(post: _post(likeCount: 3, commentCount: 1), now: _stamp),
      );

      expect(find.text('3 likes'), findsOneWidget);
      expect(find.text('1 comment'), findsOneWidget);
      // Nothing on this tile writes. A like control that only looked like one is
      // the failure mode the stage's rules freeze exists to prevent, so its
      // absence is asserted rather than assumed from the design.
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('gives the copy control an accessible name', (
      WidgetTester tester,
    ) async {
      await _pumpTile(tester, FeedPostTile(post: _post(), now: _stamp));

      final IconButton button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.content_copy_rounded),
          matching: find.byType(IconButton),
        ),
      );
      // An icon-only control with no tooltip is read as nothing at all, and
      // "copy" is the one word that tells a listener what the button will do.
      expect(button.tooltip, 'Copy text');
    });

    testWidgets('copies the text the donor is looking at, and says so', (
      WidgetTester tester,
    ) async {
      final List<MethodCall> calls = <MethodCall>[];
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

      // Intercepted at the channel rather than stubbed at the widget, because
      // what the donor gets on the clipboard is the thing under test.
      expect(
        calls.map((MethodCall call) => call.method),
        contains('Clipboard.setData'),
      );
      expect(
        (calls
                .firstWhere(
                  (MethodCall call) => call.method == 'Clipboard.setData',
                )
                .arguments
            as Map<Object?, Object?>)['text'],
        'Donated at Dhaka Medical today.',
      );
      expect(find.text('Post text copied.'), findsOneWidget);
    });
  });

  group('FeedPostTile photographs', () {
    testWidgets('draws no image at all when the post carries none', (
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
          reason: 'no cell may be left to be read as a bare image',
        );
      }
    });

    testWidgets('keeps a post readable when its photo URL is dead', (
      WidgetTester tester,
    ) async {
      await _pumpTile(
        tester,
        FeedPostTile(
          post: _post(imageUrls: <String>['https://cdn/gone.jpg']),
          now: _stamp,
        ),
      );

      // The test binding answers a network image with a failure, which is the
      // case the error builder exists for: one deleted object must not take a
      // donor's sentence down with it.
      expect(find.text('Donated at Dhaka Medical today.'), findsOneWidget);
      expect(find.text('Ayesha Rahman'), findsOneWidget);
    });
  });

  group('FeedPostTile in Bangla', () {
    testWidgets('says the count and the photograph in Bengali', (
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

      // Matched on the word rather than the numeral: a plural count is formatted
      // through `decimalPattern` for the locale, so its digits are Bengali ones,
      // and pinning the glyph here would test intl's data rather than this app.
      expect(find.text('2 likes'), findsNothing);
      expect(find.textContaining('লাইক', findRichText: true), findsOneWidget);
      expect(
        tester.widget<Image>(find.byType(Image)).semanticLabel,
        contains('শেয়ার করা ছবি'),
      );
    });
  });

  group('ExpandablePostText', () {
    testWidgets('leaves a short post alone', (WidgetTester tester) async {
      await _pumpTile(
        tester,
        const ExpandablePostText(text: 'Six words here.'),
      );

      expect(find.text('Six words here.'), findsOneWidget);
      expect(find.text('Read more'), findsNothing);
      expect(find.text('Show less'), findsNothing);
    });

    testWidgets('collapses after six lines, then opens on request', (
      WidgetTester tester,
    ) async {
      await _pumpTile(tester, ExpandablePostText(text: _long));

      // Measured, not guessed: the toggle only exists because the laid-out text
      // really did exceed the limit at this width.
      expect(find.text('Read more'), findsOneWidget);
      final Text collapsed = tester.widget<Text>(find.text(_long));
      expect(collapsed.maxLines, 6);
      expect(collapsed.overflow, TextOverflow.ellipsis);

      await tester.tap(find.text('Read more'));
      await tester.pump();

      expect(find.text('Show less'), findsOneWidget);
      expect(find.text('Read more'), findsNothing);
      final Text expanded = tester.widget<Text>(find.text(_long));
      expect(expanded.maxLines, isNull);
      expect(expanded.overflow, TextOverflow.visible);

      await tester.tap(find.text('Show less'));
      await tester.pump();

      expect(find.text('Read more'), findsOneWidget);
      expect(tester.widget<Text>(find.text(_long)).maxLines, 6);
    });

    testWidgets('withholds the toggle when the width is unbounded', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // Inside a horizontal scroller the measure is infinite, and no honest
      // answer about overflow can be given. Drawing all of the text and saying
      // nothing is the safe half of that: a "Read more" that did not know it had
      // finished would be a control with no effect.
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ExpandablePostText(text: _long),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Read more'), findsNothing);
      expect(find.text(_long), findsOneWidget);
    });
  });

  group('FeedPostTile, like interaction', () {
    testWidgets('outlined heart when not liked', (WidgetTester tester) async {
      await _pumpTile(
        tester,
        FeedPostTile(post: _post(likeCount: 3), now: _stamp, isLiked: false),
      );
      expect(
        find.byIcon(Icons.favorite_border_rounded),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    });

    testWidgets('filled heart when liked', (WidgetTester tester) async {
      await _pumpTile(
        tester,
        FeedPostTile(post: _post(likeCount: 3), now: _stamp, isLiked: true),
      );
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    });

    testWidgets('tapping the like area calls onLikeToggle', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await _pumpTile(
        tester,
        FeedPostTile(
          post: _post(),
          now: _stamp,
          onLikeToggle: () => taps++,
        ),
      );
      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('no callback: tap is inert', (WidgetTester tester) async {
      await _pumpTile(
        tester,
        FeedPostTile(post: _post(), now: _stamp),
      );
      // Should not throw: onTap == null → GestureDetector is inert.
      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pump();
      // No crash, no assertion — just verifies the null path.
    });

    testWidgets('tapping comment area calls onCommentTap', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await _pumpTile(
        tester,
        FeedPostTile(
          post: _post(commentCount: 5),
          now: _stamp,
          onCommentTap: () => taps++,
        ),
      );
      await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('no comment callback: tap is inert', (
      WidgetTester tester,
    ) async {
      await _pumpTile(
        tester,
        FeedPostTile(post: _post(commentCount: 2), now: _stamp),
      );
      await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
      await tester.pump();
      // Verifies the null path does not crash.
    });
  });

  group('report', () {
    testWidgets('flag icon is visible', (WidgetTester tester) async {
      await _pumpTile(tester, FeedPostTile(post: _post(), now: _stamp));
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    });

    testWidgets('tapping flag invokes onReportTap', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await _pumpTile(
        tester,
        FeedPostTile(post: _post(), now: _stamp, onReportTap: () => taps++),
      );
      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('no report callback: tap is inert', (
      WidgetTester tester,
    ) async {
      await _pumpTile(tester, FeedPostTile(post: _post(), now: _stamp));
      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pump();
      // Null callback must not throw.
    });
  });

  group('share', () {
    testWidgets('share icon is visible', (WidgetTester tester) async {
      await _pumpTile(tester, FeedPostTile(post: _post(), now: _stamp));
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    });
  });

  group('bookmark', () {
    testWidgets('outline icon when not saved', (WidgetTester tester) async {
      await _pumpTile(tester, FeedPostTile(post: _post(), now: _stamp));
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_rounded), findsNothing);
    });

    testWidgets('filled icon when saved', (WidgetTester tester) async {
      await _pumpTile(
        tester,
        FeedPostTile(post: _post(), now: _stamp, isSaved: true),
      );
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
    });

    testWidgets('tap invokes onSaveToggle', (WidgetTester tester) async {
      int taps = 0;
      await _pumpTile(
        tester,
        FeedPostTile(
          post: _post(),
          now: _stamp,
          onSaveToggle: () => taps++,
        ),
      );
      await tester.tap(find.byIcon(Icons.bookmark_border_rounded));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('edit icon', () {
    testWidgets('hidden when onEditTap is null', (WidgetTester tester) async {
      await _pumpTile(tester, FeedPostTile(post: _post(), now: _stamp));
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets('visible when onEditTap is provided', (WidgetTester tester) async {
      await _pumpTile(
        tester,
        FeedPostTile(post: _post(), now: _stamp, onEditTap: () {}),
      );
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('tap invokes onEditTap', (WidgetTester tester) async {
      int taps = 0;
      await _pumpTile(
        tester,
        FeedPostTile(post: _post(), now: _stamp, onEditTap: () => taps++),
      );
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pump();
      expect(taps, 1);
    });
  });
}
