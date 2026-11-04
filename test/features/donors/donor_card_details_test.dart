import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/design/widgets/blood_group_badge.dart';
import 'package:sholovvo_app/features/donors/domain/entities/donor.dart';
import 'package:sholovvo_app/features/donors/presentation/donor_details_screen.dart';
import 'package:sholovvo_app/features/donors/presentation/widgets/donor_card.dart';

import '../../support/fake_donors.dart';
import '../../support/test_app.dart';

Future<void> _pump(WidgetTester tester, Widget page, {Locale locale = const Locale('en')}) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(home: page, locale: locale));
  await tester.pump();
}

void main() {
  group('DonorCard', () {
    testWidgets('shows the public name, group, availability and area', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        DonorCard(
          donor: fakeDonor(
            displayName: 'Ayesha Rahman',
            bloodGroup: 'O+',
            isAvailable: true,
            area: 'Mirpur, Dhaka',
          ),
        ),
      );

      expect(find.text('Ayesha Rahman'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Mirpur, Dhaka'), findsOneWidget);
      expect(find.byType(BloodGroupBadge), findsOneWidget);
    });

    testWidgets('falls back to a neutral label when the name is empty', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        DonorCard(donor: fakeDonor(displayName: '', bloodGroup: null)),
      );

      expect(find.text('Donor'), findsOneWidget);
      // No group set: the row says so rather than showing a blank or a false badge.
      expect(find.text('Blood group not set'), findsOneWidget);
      expect(find.byType(BloodGroupBadge), findsNothing);
    });

    testWidgets('renders no phone number, because the model has none', (
      WidgetTester tester,
    ) async {
      // A directory that could show a phone is a directory that one day will; the
      // read model carries no phone field, so nothing on this card can print one.
      await _pump(tester, DonorCard(donor: fakeDonor()));

      expect(find.textContaining('+880'), findsNothing);
    });

    testWidgets('shows "not available" for an unavailable donor', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        DonorCard(donor: fakeDonor(isAvailable: false)),
      );

      expect(find.text('Not available'), findsOneWidget);
    });
  });

  group('DonorDetailsScreen', () {
    testWidgets('draws the profile from the card data and the two notes', (
      WidgetTester tester,
    ) async {
      final Donor donor = fakeDonor(
        displayName: 'Nadia Islam',
        bloodGroup: 'AB-',
        isAvailable: true,
        area: 'Uttara, Dhaka',
      );

      await _pump(tester, DonorDetailsScreen(donor: donor));

      expect(find.text('Donor profile'), findsOneWidget);
      expect(find.text('Nadia Islam'), findsOneWidget);
      expect(find.text('Availability'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Uttara, Dhaka'), findsOneWidget);
      expect(find.textContaining('contact details are not shown'), findsOneWidget);
      expect(find.textContaining('chose to appear in search'), findsOneWidget);
    });

    testWidgets('omits the area row when the donor published none', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        DonorDetailsScreen(donor: fakeDonor(area: null)),
      );

      expect(find.text('Area'), findsNothing);
    });
  });
}
