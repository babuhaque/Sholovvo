import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/blood_group_badge.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';
import 'package:sholovvo_app/features/requests/presentation/requests_messages.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// One open request, as both the dashboard's nearby section and the requests
/// screen list it.
///
/// **One widget for both screens, on purpose.** The dashboard shows three of
/// these and the screen shows the window; a second row widget for the second
/// screen is where the two start to disagree about what a request carries — and a
/// donor who reads a short row at home and a long row on the list has no way to
/// tell which one is the truth. So the same widget renders the same entity, and
/// the only difference is how many are on screen.
///
/// **No tap, no chevron.** This row goes nowhere, and it does not look as though
/// it goes anywhere. A destination for one request — the hospital, the contact,
/// the way to say yes — is Stage 10's, and until it exists a chevron would be a
/// promise the app cannot keep. The dashboard's "See all" is the one control here,
/// because that one leads somewhere real.
///
/// **What it does not show.** No patient name, no phone number and no street
/// address. As of Stage 9.5 (M3-C1) those fields live in
/// `blood_requests/{id}/private/contact`, gated by the rules so this read model
/// never carries them and the row cannot render them — see [BloodRequest]. The
/// row names the hospital (and only the hospital) and the date. No distance: the
/// app does not know where the donor is.
class RequestTile extends StatelessWidget {
  const RequestTile({super.key, required this.request});

  final BloodRequest request;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;

    return SolovvoCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          BloodGroupBadge(
            bloodGroup: request.bloodGroup,
            variant: BloodGroupBadgeVariant.square,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  request.area,
                  style: text.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.homeUnitsNeeded(request.units)} · '
                  '${requestsNeededByLabel(context, request)}',
                  style: text.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
