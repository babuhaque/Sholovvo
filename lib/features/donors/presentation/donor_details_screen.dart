import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/motion/fade_slide_route.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/blood_group_badge.dart';
import 'package:sholovvo_app/design/widgets/initials_avatar.dart';
import 'package:sholovvo_app/design/widgets/soft_glow_background.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/features/donors/domain/entities/donor.dart';
import 'package:sholovvo_app/features/donors/presentation/donor_search_messages.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// A single donor's public profile.
///
/// **It draws the card's data, and nothing more.** No second read, no lookup of a
/// private document: everything here is the same [Donor] the results list already
/// holds, because that object is all the privacy model permits a searcher to see. The
/// screen therefore cannot reach a phone number or a street address even by
/// construction — those fields are not on [Donor], and there is no code path here that
/// goes looking for them.
///
/// **It says what it is missing.** The contact note is the honest answer to the
/// question a profile page provokes — "how do I reach them?" Reaching a donor is Stage
/// 10's, and until it exists a page that looked like it should have a phone number but
/// did not would read as broken rather than as deliberate. The consent note, likewise,
/// tells the reader why this person is here at all: they published their profile.
class DonorDetailsScreen extends StatelessWidget {
  const DonorDetailsScreen({super.key, required this.donor});

  final Donor donor;

  static Route<void> route(Donor donor) {
    return FadeSlidePageRoute<void>(page: DonorDetailsScreen(donor: donor));
  }

  static const double narrowMaxWidth = 560;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final String name = donor.displayName;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.donorDetailsTitle)),
      body: SoftGlowBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double side = constraints.maxWidth >= narrowMaxWidth
                  ? (constraints.maxWidth - narrowMaxWidth) / 2
                  : AppSpacing.gutter;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  side,
                  AppSpacing.md,
                  side,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: InitialsAvatar(
                        name: name,
                        photoUrl: donor.hasPhoto ? donor.photoUrl : null,
                        size: 96,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: Text(
                        name.isEmpty ? l10n.donorUnnamed : name,
                        style: text.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SolovvoCard(
                      child: Column(
                        children: <Widget>[
                          _DetailRow(
                            label: l10n.bloodGroupLabel,
                            trailing: donor.hasBloodGroup
                                ? BloodGroupBadge(
                                    bloodGroup: donor.bloodGroup!,
                                    variant: BloodGroupBadgeVariant.square,
                                  )
                                : null,
                            value: donor.hasBloodGroup
                                ? null
                                : donorGroupLabel(l10n, donor.bloodGroup),
                          ),
                          _DetailRow(
                            label: l10n.donorAvailabilityHeading,
                            value: donorAvailabilityLabel(l10n, donor.isAvailable),
                          ),
                          if (donor.hasArea)
                            _DetailRow(label: l10n.donorAreaFieldLabel, value: donor.area!),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.donorContactNote,
                      style: text.labelMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.donorConsentNote,
                      style: text.labelSmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One labelled line in the profile card, its value on the far side.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, this.value, this.trailing});

  final String label;
  final String? value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: text.bodyMedium),
          if (trailing != null)
            trailing!
          else
            Flexible(
              child: Text(
                value ?? '',
                style: text.titleSmall,
                textAlign: TextAlign.end,
              ),
            ),
        ],
      ),
    );
  }
}
