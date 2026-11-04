import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/blood_group_badge.dart';
import 'package:sholovvo_app/design/widgets/initials_avatar.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/features/donors/domain/entities/donor.dart';
import 'package:sholovvo_app/features/donors/presentation/donor_details_screen.dart';
import 'package:sholovvo_app/features/donors/presentation/donor_search_messages.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// One discoverable donor in the results list.
///
/// **What it shows, and only this.** The published name, the blood group, the
/// availability, and the area *when the donor published one*. There is no phone
/// number on this card and there never will be from this data — [Donor] is built from
/// the public profile document, which the privacy model keeps free of contact
/// details. A directory that listed a phone next to every name would turn consented
/// donors into a callable list, which is exactly what Stage 9.4 forbids.
///
/// **It is a row that goes somewhere.** Unlike `RequestTile`, which deliberately has
/// no destination until Stage 10 gives a request one, a donor card opens the donor's
/// public profile. That is a real destination built from the same fields already on
/// the card, so the chevron is a promise the app can keep rather than one it cannot.
class DonorCard extends StatelessWidget {
  const DonorCard({super.key, required this.donor});

  final Donor donor;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final String name = donor.displayName;

    return SolovvoCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => Navigator.of(context).push(DonorDetailsScreen.route(donor)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InitialsAvatar(
            name: name,
            photoUrl: donor.hasPhoto ? donor.photoUrl : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name.isEmpty ? l10n.donorUnnamed : name,
                  style: text.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    if (donor.hasBloodGroup)
                      BloodGroupBadge(
                        bloodGroup: donor.bloodGroup!,
                        variant: BloodGroupBadgeVariant.square,
                      )
                    else
                      Text(donorGroupLabel(l10n, donor.bloodGroup),
                          style: text.bodySmall),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        donorAvailabilityLabel(l10n, donor.isAvailable),
                        style: text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (donor.hasArea) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    donor.area!,
                    style: text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
