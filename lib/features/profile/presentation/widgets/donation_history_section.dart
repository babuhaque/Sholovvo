import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/blood_group_badge.dart';
import 'package:sholovvo_app/design/widgets/empty_state_card.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/features/profile/domain/donation_record.dart';
import 'package:sholovvo_app/features/profile/presentation/profile_messages.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// The donor's own donation records, read-only.
///
/// Nothing on this card can be edited, because nothing here is typed in by the
/// user: `firestore.rules` only lets a donor create a `pending` record for a
/// request they answered, and only a recipient can confirm one. A hand-entered
/// "last donation" would therefore be fabricated history, so the card shows what
/// exists and says plainly when that is nothing.
///
/// Statistics appear only from confirmed records. A pending record is listed but
/// never counted: it has not happened yet as far as the data model is concerned.
class DonationHistorySection extends StatelessWidget {
  const DonationHistorySection({
    super.key,
    required this.history,
    required this.onRetry,
  });

  final AsyncValue<Result<DonationHistory>> history;

  /// Re-reads the collection. Bound to the failure card's "Try again" only.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    if (history.hasError && !history.hasValue) {
      return EmptyStateCard(
        icon: Icons.cloud_off_outlined,
        title: l10n.profileHistoryErrorTitle,
        body: l10n.failureUnexpected,
        action: TextButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
      );
    }

    final Result<DonationHistory>? result = history.value;
    if (result == null) {
      // Held back rather than shown empty: "no donations" and "not loaded" are
      // different claims about the donor's history.
      return const SolovvoCard(
        padding: EdgeInsets.all(AppSpacing.md),
        child: LinearProgressIndicator(minHeight: 3),
      );
    }

    return switch (result) {
      FailureResult<DonationHistory>(:final Failure failure) => EmptyStateCard(
        icon: Icons.cloud_off_outlined,
        title: l10n.profileHistoryErrorTitle,
        body: profileFailureMessage(l10n, failure),
        action: TextButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
      ),
      Success<DonationHistory>(:final DonationHistory value) =>
        value.records.isEmpty
            ? EmptyStateCard(
                icon: Icons.volunteer_activism_outlined,
                title: l10n.profileHistoryEmptyTitle,
                body: l10n.profileHistoryEmptyBody,
              )
            : _HistoryList(history: value),
    };
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.history});

  final DonationHistory history;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SolovvoPalette palette = context.palette;
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (history.confirmedCount > 0) ...<Widget>[
          SolovvoCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.volunteer_activism_rounded,
                  size: 20,
                  color: palette.brandInk,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.profileHistoryCount(history.confirmedCount),
                        style: text.titleMedium,
                      ),
                      if (history.lastConfirmedAt != null)
                        Text(
                          l10n.profileHistoryLast(
                            MaterialLocalizations.of(
                              context,
                            ).formatMediumDate(history.lastConfirmedAt!.toLocal()),
                          ),
                          style: text.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        for (final DonationRecord record in history.records)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: _DonationRow(record: record),
          ),
      ],
    );
  }
}

class _DonationRow extends StatelessWidget {
  const _DonationRow({required this.record});

  final DonationRecord record;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final DateTime date = record.effectiveDate?.toLocal() ?? DateTime(0);
    final String when = record.effectiveDate == null
        ? l10n.notSetYet
        : MaterialLocalizations.of(context).formatMediumDate(date);
    final String hospital = record.hospitalName.trim().isEmpty
        ? l10n.notSetYet
        : record.hospitalName.trim();

    return SolovvoCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (record.bloodGroup.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: BloodGroupBadge(bloodGroup: record.bloodGroup),
            ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  hospital,
                  style: text.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(when, style: text.bodySmall),
              ],
            ),
          ),
          _StatusChip(status: record.status),
        ],
      ),
    );
  }
}

/// Confirmed is a success colour, pending a warning one — the distinction is the
/// whole point of the two states.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final DonationStatus status;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SolovvoPalette palette = context.palette;
    final bool confirmed = status == DonationStatus.confirmed;
    final Color color = confirmed ? palette.success : palette.warning;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.pillRadius,
      ),
      child: Text(
        confirmed
            ? l10n.profileHistoryConfirmed
            : l10n.profileHistoryPending,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
