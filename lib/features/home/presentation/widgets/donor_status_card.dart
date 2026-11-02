import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/features/home/domain/home_dashboard.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// Blood group, last donation and availability, in one card.
///
/// The three tiles say "Not set yet" rather than nothing at all: a donor who
/// has not filled in a profile yet needs to see that the app knows these values
/// exist, not an empty card that reads as a rendering bug. The `??` chain is the
/// whole point — no value is ever fabricated.
class DonorStatusCard extends StatelessWidget {
  const DonorStatusCard({super.key, required this.donor});

  /// `null` until the profile stage lands; the card then renders the same empty
  /// state it renders for a donor who has simply not filled it in.
  final DonorSnapshot? donor;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SolovvoPalette palette = context.palette;
    final TextTheme text = Theme.of(context).textTheme;

    final String bloodGroup = donor?.bloodGroup ?? l10n.notSetYet;
    final String lastDonation = _lastDonation(context, l10n);
    final String availability = switch (donor?.isAvailable) {
      null => l10n.notSetYet,
      true => l10n.availableNow,
      false => l10n.notAvailableNow,
    };
    final int? donations = donor?.donationCount;

    return SolovvoCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(l10n.donorStatusTitle, style: text.titleMedium),
              ),
              if (donations != null && donations > 0)
                Text(
                  l10n.homeDonationsCount(donations),
                  style: text.labelSmall?.copyWith(
                    color: palette.brandInk,
                    letterSpacing: 0.4,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // One table rather than three tiles in a row: a label may wrap to two
          // lines ("সর্বশেষ রক্তদান" does at 320 dp where "Last donation" does
          // not), and a row would leave the three values on three different
          // baselines. Two table rows keep them aligned in both languages.
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            columnWidths: const <int, TableColumnWidth>{
              0: FlexColumnWidth(),
              1: FlexColumnWidth(),
              2: FlexColumnWidth(),
            },
            children: <TableRow>[
              TableRow(
                children: <Widget>[
                  _Label(l10n.bloodGroupLabel),
                  _Label(l10n.lastDonationLabel),
                  _Label(l10n.availabilityLabel),
                ],
              ),
              TableRow(
                children: <Widget>[
                  _Value(
                    bloodGroup,
                    emphasised: donor?.bloodGroup != null,
                  ),
                  _Value(lastDonation),
                  _Value(
                    availability,
                    color: donor?.isAvailable == true
                        ? palette.success
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The recorded date, "no donations yet", or "not set yet" — in that order of
  /// preference, because a zero count is a real fact and a missing date is not.
  String _lastDonation(BuildContext context, AppLocalizations l10n) {
    final DateTime? at = donor?.lastDonationAt;
    if (at != null) {
      final DateTime local = at.toLocal();
      // Flutter's own delegate rather than `intl.DateFormat`, so no locale data
      // has to be initialised before the first frame.
      return MaterialLocalizations.of(context).formatShortMonthDay(local);
    }
    if (donor?.donationCount == 0) {
      return l10n.neverDonated;
    }
    return l10n.notSetYet;
  }
}

/// The name of a fact, above its value.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.text, {this.emphasised = false, this.color});

  final String text;

  /// Blood group is the one value that gets brand ink and a heavier weight: it
  /// is the value a matching donor is chosen by.
  final bool emphasised;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs, right: AppSpacing.xs),
      child: Text(
        this.text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: (emphasised ? text.headlineSmall : text.titleMedium)?.copyWith(
          color:
              color ?? (emphasised ? palette.brandInk : palette.textSecondary),
        ),
      ),
    );
  }
}
