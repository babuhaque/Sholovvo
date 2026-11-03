import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/initials_avatar.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/presentation/expandable_post_text.dart';
import 'package:sholovvo_app/features/feed/presentation/feed_messages.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// One post, drawn the way the feed draws it.
///
/// **Everything here reads.** There is no like button, no comment field and no
/// overflow menu, because this stage has no write path and a control that does
/// nothing is worse than a number that only reports. The two counts are the
/// cached integers the post document carries; the subcollections behind them are
/// not read.
///
/// The one action that exists is **copy**, and it copies the text the donor is
/// looking at. Nothing is composed — no share URL, no link to a post that has no
/// public address yet.
class FeedPostTile extends StatelessWidget {
  const FeedPostTile({super.key, required this.post, this.now});

  final Post post;

  /// The moment the relative timestamp is measured against. Left null by the
  /// screen, which reads the clock at build time; supplied by tests so a label
  /// like "3 hours ago" does not depend on when the suite ran.
  final DateTime? now;

  Future<void> _copy(BuildContext context) async {
    // Read before the await: after it, this context may no longer be mounted.
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );

    await Clipboard.setData(ClipboardData(text: post.text));

    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.feedCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SolovvoPalette palette = context.palette;
    final TextTheme text = Theme.of(context).textTheme;

    final String postedAt = feedRelativeTime(
      l10n,
      post.createdAt,
      olderDate: MaterialLocalizations.of(context)
          .formatShortMonthDay(post.createdAt.toLocal()),
      now: now,
    );

    return SolovvoCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              InitialsAvatar(
                name: post.authorName,
                photoUrl: post.authorPhotoUrl,
                size: 40,
                variant: InitialsAvatarVariant.muted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      post.authorName,
                      style: text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      post.isEdited
                          ? '${l10n.feedEdited} · $postedAt'
                          : postedAt,
                      style: text.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ExpandablePostText(
            text: post.text,
            style: text.bodyMedium?.copyWith(color: palette.textPrimary),
          ),
          if (post.hasImages) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _PostImages(urls: post.imageUrls, authorName: post.authorName),
          ],
          const SizedBox(height: AppSpacing.xxs),
          Row(
            children: <Widget>[
              Icon(
                Icons.favorite_border_rounded,
                size: 18,
                color: palette.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Flexible(
                child: Text(
                  l10n.feedLikeCount(post.likeCount),
                  style: text.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 18,
                color: palette.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Flexible(
                child: Text(
                  l10n.feedCommentCount(post.commentCount),
                  style: text.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => unawaited(_copy(context)),
                tooltip: l10n.feedCopy,
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                color: palette.textSecondary,
                icon: const Icon(Icons.content_copy_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Up to four photographs, in the order the donor arranged them.
///
/// One image gets a wide crop because a lone square wastes half the card. Two or
/// more become a two-column grid of squares, which is the shape that keeps a
/// four-image post the same height as a two-image one and stops the timeline
/// from jumping as it loads.
///
/// **Height is capped.** A square is right for a 380 dp card and wrong for a
/// 900 dp one, where two cells would each be over 400 dp tall and one photograph
/// would take the whole screen. Past the cap the cells keep their width and crop
/// instead — a feed is text with pictures, not a gallery.
///
/// [authorName] exists only to be handed down as part of each picture's
/// semantics label. A photograph in a feed is the one element a screen reader
/// cannot read aloud from what is next to it, and the two sentences a listener
/// could need — who wrote this, and what is in the picture — are not both
/// answerable from the author line above.
class _PostImages extends StatelessWidget {
  const _PostImages({required this.urls, required this.authorName});

  /// The tallest a picture may draw, whatever the card's width.
  static const double maxHeight = 300;

  final List<String> urls;

  /// Whose post these pictures belong to. Used for the label, never drawn.
  final String authorName;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    // Built once for the whole group rather than per cell: every picture in a
    // post belongs to the same author, and the sentence is the same for all of
    // them.
    final String label = l10n.feedPostPhotoLabel(authorName);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;

        if (urls.length == 1) {
          return SizedBox(
            width: width,
            height: math.min(width * 10 / 16, maxHeight),
            child: _PostImage(url: urls[0], semanticLabel: label),
          );
        }

        // Two cells and the gap between them, or the cap, whichever is shorter.
        final double cell = math.min((width - AppSpacing.xs) / 2, maxHeight);

        return Column(
          children: <Widget>[
            for (int index = 0; index < urls.length; index += 2)
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : AppSpacing.xs),
                child: Row(
                  children: <Widget>[
                    Expanded(child: _cell(urls[index], cell, label)),
                    const SizedBox(width: AppSpacing.xs),
                    // An odd count leaves the last cell empty rather than letting
                    // one picture stretch to the full width of the card.
                    if (index + 1 < urls.length)
                      Expanded(child: _cell(urls[index + 1], cell, label))
                    else
                      const Spacer(),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _cell(String url, double height, String semanticLabel) {
    return SizedBox(
      height: height,
      child: _PostImage(url: url, semanticLabel: semanticLabel),
    );
  }
}

/// One photograph, with both of its failure paths drawn.
///
/// A post is a piece of writing with pictures attached, so an image that has
/// been deleted from the bucket, or that cannot load on a slow connection, must
/// not take the text down with it. [errorBuilder] paints a placeholder instead;
/// a post whose storage objects are gone is still a readable post.
class _PostImage extends StatelessWidget {
  const _PostImage({required this.url, required this.semanticLabel});

  final String url;

  /// What a screen reader says instead of the picture. Supplied rather than read
  /// from [url], because a storage path is an identifier a donor never chose to
  /// hear read aloud.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;

    return ClipRRect(
      borderRadius: AppRadius.mdRadius,
      child: ColoredBox(
        color: palette.surfaceMuted,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          semanticLabel: semanticLabel,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stackTrace) =>
                  Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 22,
                      color: palette.textSecondary,
                    ),
                  ),
          loadingBuilder:
              (BuildContext context, Widget child, ImageChunkEvent? progress) =>
                  progress == null
                  ? child
                  : const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
        ),
      ),
    );
  }
}
