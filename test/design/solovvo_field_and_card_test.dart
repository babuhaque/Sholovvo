import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/design/app_theme.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/design/widgets/solovvo_text_field.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
  );
}

void main() {
  group('SolovvoTextField', () {
    testWidgets('renders the uppercased label and accepts text', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          SolovvoTextField(
            controller: controller,
            label: 'Email',
            hintText: 'you@example.com',
            prefixIcon: Icons.mail_outline,
          ),
        ),
      );

      expect(find.text('EMAIL'), findsOneWidget);
      expect(find.byIcon(Icons.mail_outline), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'donor@solovvo.app');
      await tester.pump();

      expect(controller.text, 'donor@solovvo.app');
    });

    testWidgets('toggles password visibility', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const SolovvoTextField(
            label: 'Password',
            obscureText: true,
            showObscureToggle: true,
          ),
        ),
      );

      TextField field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isFalse);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('shows an inline error instead of the helper text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SolovvoTextField(
            label: 'Phone',
            helperText: 'Include the country code',
            errorText: 'Enter a valid phone number',
          ),
        ),
      );

      expect(find.text('Enter a valid phone number'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Include the country code'), findsNothing);
    });

    testWidgets('shows helper text when there is no error', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SolovvoTextField(
            label: 'Phone',
            helperText: 'Include the country code',
          ),
        ),
      );

      expect(find.text('Include the country code'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });
  });

  group('SolovvoCard', () {
    testWidgets('renders its child and fires onTap', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _host(
          SolovvoCard(
            onTap: () => taps++,
            child: const Text('Campaign'),
          ),
        ),
      );

      expect(find.text('Campaign'), findsOneWidget);

      await tester.tap(find.text('Campaign'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('is inert without onTap', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(const SolovvoCard(child: Text('Static'))),
      );

      await tester.tap(find.text('Static'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
