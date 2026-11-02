import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/design/app_theme.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('SolovvoButton', () {
    testWidgets('renders its label and fires the callback', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _host(
          SolovvoButton(label: 'Get Started', onPressed: () => taps++),
        ),
      );

      expect(find.text('Get Started'), findsOneWidget);

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('is not tappable while loading', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        _host(
          SolovvoButton(
            label: 'Get Started',
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(SolovvoButton));
      await tester.pump();

      expect(taps, 0);
    });

    testWidgets('is not tappable when onPressed is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(const SolovvoButton(label: 'Disabled')));

      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.tap(find.byType(SolovvoButton));
      await tester.pump();

      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('renders a leading icon when supplied', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SolovvoButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    });

    testWidgets('all three variants render without exception', (
      WidgetTester tester,
    ) async {
      for (final SolovvoButtonVariant variant in SolovvoButtonVariant.values) {
        await tester.pumpWidget(
          _host(
            SolovvoButton(
              label: variant.name,
              variant: variant,
              onPressed: () {},
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text(variant.name), findsOneWidget);
      }
    });
  });
}
