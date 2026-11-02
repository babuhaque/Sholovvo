import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/design/app_theme.dart';
import 'package:sholovvo_app/design/widgets/blood_drop_mark.dart';
import 'package:sholovvo_app/design/widgets/floating_blood_drops.dart';
import 'package:sholovvo_app/design/widgets/soft_glow_background.dart';

Widget _host(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('FloatingBloodDrops', () {
    testWidgets('paints a single canvas and keeps animating', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 390,
            height: 844,
            child: FloatingBloodDrops(),
          ),
        ),
      );

      expect(find.byType(FloatingBloodDrops), findsOneWidget);
      expect(tester.hasRunningAnimations, isTrue);

      // Advance several frames: the painter must not throw mid-animation.
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('is excluded from semantics and hit testing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Stack(
            children: <Widget>[
              const Positioned.fill(child: FloatingBloodDrops()),
              Center(
                child: GestureDetector(
                  onTap: () {},
                  child: const Text('underneath'),
                ),
              ),
            ],
          ),
        ),
      );

      final SemanticsHandle handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('underneath'), findsOneWidget);
      handle.dispose();

      // The decorative layer must not swallow the tap.
      await tester.tap(find.text('underneath'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('honours the reduce-motion setting', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 390,
            height: 844,
            child: FloatingBloodDrops(),
          ),
          disableAnimations: true,
        ),
      );

      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('BloodDropMark', () {
    testWidgets('renders at the requested size', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(const Center(child: BloodDropMark(size: 64))),
      );

      final Size size = tester.getSize(find.byType(BloodDropMark));
      expect(size.width, 64);
      expect(size.height, 64);
    });

    testWidgets('exposes a label only when one is given', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(_host(const Center(child: BloodDropMark())));
      expect(find.bySemanticsLabel('blood drop'), findsNothing);

      await tester.pumpWidget(
        _host(
          const Center(child: BloodDropMark(semanticLabel: 'blood drop')),
        ),
      );
      expect(find.bySemanticsLabel('blood drop'), findsOneWidget);

      handle.dispose();
    });
  });

  group('SoftGlowBackground', () {
    testWidgets('renders its child on the cream surface', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const SoftGlowBackground(child: Text('content'))),
      );

      expect(find.text('content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
