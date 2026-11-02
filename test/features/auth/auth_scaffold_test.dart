import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/brand/app_brand.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/auth/presentation/widgets/auth_scaffold.dart';

import '../../support/auth_harness.dart';
import '../../support/test_app.dart';

/// A frame with enough body to overflow a short window.
Widget _frame() {
  return testApp(
    home: AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to reach your donor profile and the requests near you.',
      footer: const Text('New to Solovvo?'),
      children: <Widget>[
        for (final String label in <String>['Email', 'Password'])
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SolovvoTextFieldProxy(label: label),
          ),
        const SolovvoButton(label: 'Sign in', onPressed: null),
      ],
    ),
  );
}

/// A plain box standing in for a text field, so the frame test does not depend
/// on the field's internals.
class SolovvoTextFieldProxy extends StatelessWidget {
  const SolovvoTextFieldProxy({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Align(alignment: Alignment.centerLeft, child: Text(label)),
    );
  }
}

void main() {
  group('AuthScaffold', () {
    testWidgets('never pushes the title above the top of a short window', (
      WidgetTester tester,
    ) async {
      // A laptop browser window, or a phone with the keyboard open. The frame
      // used to centre its body here, which lifted the wordmark and the heading
      // out of the scrollable range.
      usePhoneSurface(tester, size: const Size(400, 420));

      await tester.pumpWidget(_frame());
      await tester.pump();

      final Rect title = tester.getRect(find.text('Welcome back'));
      expect(title.top, greaterThanOrEqualTo(0));
      expect(title.bottom, lessThanOrEqualTo(420));
      expect(find.text(AppBrand.name), findsOneWidget);
      expect(
        tester.getRect(find.text(AppBrand.name)).top,
        greaterThanOrEqualTo(0),
      );
    });

    testWidgets('centres the body when it fits, and scrolls when it does not', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester, size: const Size(400, 1000));
      await tester.pumpWidget(_frame());
      await tester.pump();
      final double tallTop = tester.getRect(find.text('Welcome back')).top;

      usePhoneSurface(tester, size: const Size(400, 500));
      await tester.pumpWidget(_frame());
      await tester.pump();
      final double shortTop = tester.getRect(find.text('Welcome back')).top;

      expect(
        tallTop,
        greaterThan(shortTop),
        reason: 'a roomier window should keep the body vertically centred',
      );
      // Only the overflowing case needs to scroll.
      expect(
        find.byType(Scrollable),
        findsWidgets,
        reason: 'the body must stay reachable by scrolling',
      );
    });
  });
}
