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
/// **Tappable only when the caller says so.** [onTap] is optional and defaults
/// to null, and [SolovvoCard] renders no `InkWell` when it is null. Stage 9.1
/// pinned that behaviour in a widget test to keep the row honest while there was
/// nowhere to go; Stage 10's per-request destination ([RequestDetailScreen],
/// built as the read-half of that destination) is now the somewhere, so callers
/// that want to open it pass the callback. The dashboard preview and the
/// requests screen pass the same callback, so a tap reads identically from both
/// places. A caller that genuinely has no destination can still leave [onTap]
/// null and the row stays inert.
///
/// **What it does not show.** No patient name, no phone number and no street
/// address. As of Stage 9.5 (M3-C1) those fields live in
/// `blood_requests/{id}/private/contact`, gated by the rules so this read model
/// never carries them and the row cannot render them — see [BloodRequest]. The
/// row names the hospital (and only the hospital) and the date. No distance: the
/// app does not know where the donor is.
class RequestTile extends StatelessWidget {
  const RequestTile({super.key, required this.request, this.onTap});

  final BloodRequest request;

  /// Where a tap goes. See the class docblock: null means "this row is inert",
  /// and callers that mean to open [RequestDetailScreen] pass a callback that
  /// pushes it.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;

    return SolovvoCard(
      onTap: onTap,
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
