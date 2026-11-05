import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/initials_avatar.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/presentation/expandable_post_text.dart';
import 'package:sholovvo_app/features/feed/presentation/feed_messages.dart';
import 'package:sholovvo_app/features/feed/presentation/image_viewer_screen.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// One post, drawn the way the feed draws it.
///
/// **Reads, likes, comments, and reports.** The like button and the comment
/// button perform writes via [onLikeToggle] and [onCommentTap]; the report flag
/// calls [onReportTap] which the parent wires to open the [ReportSheet].
/// The icon reflects [isLiked] from the caller's session-local set.
///
/// The two counts are the cached integers the post document carries, adjusted
/// optimistically by the controller. The subcollections behind them are not
/// read here.
///
/// The one other actions are **copy**, **share**, and **save**: copy puts the
/// text on the clipboard; share opens the system share sheet with the author's
/// name and the post text (no URL, because a post has no public address yet);
/// save bookmarks the post locally for later reading.
class FeedPostTile extends StatefulWidget {
  const FeedPostTile({
    super.key,
    required this.post,
    this.now,
    this.isLiked = false,
    this.onLikeToggle,
    this.onCommentTap,
    this.onReportTap,
    this.onEditTap,
    this.isSaved = false,
    this.onSaveToggle,
  });

  final Post post;

  /// The moment the relative timestamp is measured against. Left null by the
  /// screen, which reads the clock at build time; supplied by tests so a label
  /// like "3 hours ago" does not depend on when the suite ran.
  final DateTime? now;

  /// Whether the current user has liked this post (from the session-local set).
  final bool isLiked;

  /// Called when the user taps the like button. Null makes the button inert
  /// (useful in a preview or a context where likes are not available).
  final VoidCallback? onLikeToggle;

  /// Called when the user taps the comment count. Opens the comment thread.
  final VoidCallback? onCommentTap;

  /// Called when the user taps the report flag. Opens the report sheet.
  final VoidCallback? onReportTap;

  /// Called when the author taps the edit pencil. Null hides the icon.
  final VoidCallback? onEditTap;

  /// Whether the user has bookmarked this post locally.
  final bool isSaved;

  /// Called when the user taps the bookmark icon.
  final VoidCallback? onSaveToggle;

  @override
  State<FeedPostTile> createState() => _FeedPostTileState();
}

class _FeedPostTileState extends State<FeedPostTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartController;
  late final Animation<double> _heartScale;
  late final Animation<double> _heartOpacity;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _heartScale = Tween<double>(begin: 0.3, end: 1.2).animate(
      CurvedAnimation(
        parent: _heartController,
        curve: const Interval(0, 0.4, curve: Curves.easeOutBack),
      ),
    );
    _heartOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _heartController,
        curve: const Interval(0.4, 1, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    // Only add a like; never remove one on double-tap.
    if (!widget.isLiked && widget.onLikeToggle != null) {
      widget.onLikeToggle!();
    }
    _heartController.forward(from: 0);
  }

  Post get post => widget.post;
  DateTime? get now => widget.now;
  bool get isLiked => widget.isLiked;
  VoidCallback? get onLikeToggle => widget.onLikeToggle;
  VoidCallback? get onCommentTap => widget.onCommentTap;
  VoidCallback? get onReportTap => widget.onReportTap;
  VoidCallback? get onEditTap => widget.onEditTap;
  bool get isSaved => widget.isSaved;
  VoidCallback? get onSaveToggle => widget.onSaveToggle;

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

  void _share(BuildContext context) {
    // Share the post text through the system share sheet. There is no public
    // URL yet (no deep-link routing), so the payload is just the text itself
    // preceded by the author's name for attribution.
    final String content = '${post.authorName}\n\n${post.text}';
    SharePlus.instance.share(ShareParams(text: content));
  }

  Widget _buildContent(
    BuildContext context,
    TextTheme text,
    SolovvoPalette palette,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExpandablePostText(
          text: post.text,
          style: text.bodyMedium?.copyWith(color: palette.textPrimary),
        ),
        if (post.hasImages) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          GestureDetector(
            onDoubleTap: onLikeToggle != null ? _onDoubleTap : null,
            child: _PostImages(
              urls: post.imageUrls,
              authorName: post.authorName,
            ),
          ),
        ],
      ],
    );
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

    return Stack(
      children: <Widget>[
        SolovvoCard(
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
                    IconButton(
                      onPressed: onSaveToggle,
                      tooltip: l10n.feedSave,
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      color: isSaved
                          ? Theme.of(context).colorScheme.primary
                          : palette.textSecondary,
                      icon: Icon(
                        isSaved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                _buildContent(context, text, palette),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            children: <Widget>[
              Flexible(
                child: GestureDetector(
                  onTap: onLikeToggle,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 18,
                          color: isLiked
                              ? palette.danger
                              : palette.textSecondary,
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
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: GestureDetector(
                  onTap: onCommentTap,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
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
                      ],
                    ),
                  ),
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
              IconButton(
                onPressed: () => _share(context),
                tooltip: l10n.feedShare,
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                color: palette.textSecondary,
                icon: const Icon(Icons.share_outlined),
              ),
              if (onEditTap != null)
                IconButton(
                  onPressed: onEditTap,
                  tooltip: l10n.feedEditAction,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  color: palette.textSecondary,
                  icon: const Icon(Icons.edit_outlined),
                ),
              IconButton(
                onPressed: onReportTap,
                tooltip: l10n.reportTooltip,
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                color: palette.textSecondary,
                icon: const Icon(Icons.flag_outlined),
              ),
            ],
          ),
        ],
      ),
    ),
        // Heart animation overlay (visible only during double-tap).
        AnimatedBuilder(
          animation: _heartController,
          builder: (BuildContext context, Widget? child) {
            if (_heartController.isDismissed) {
              return const SizedBox.shrink();
            }
            return Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Opacity(
                    opacity: _heartOpacity.value,
                    child: Transform.scale(
                      scale: _heartScale.value,
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 80,
                        color: Colors.white,
                        shadows: <Shadow>[
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 12,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
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
            child: _PostImage(
              url: urls[0],
              semanticLabel: label,
              allUrls: urls,
              index: 0,
            ),
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
                    Expanded(
                      child: _cell(urls, index, cell, label),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    // An odd count leaves the last cell empty rather than letting
                    // one picture stretch to the full width of the card.
                    if (index + 1 < urls.length)
                      Expanded(
                        child: _cell(urls, index + 1, cell, label),
                      )
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

  Widget _cell(
    List<String> allUrls,
    int index,
    double height,
    String semanticLabel,
  ) {
    return SizedBox(
      height: height,
      child: _PostImage(
        url: allUrls[index],
        semanticLabel: semanticLabel,
        allUrls: allUrls,
        index: index,
      ),
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
  const _PostImage({
    required this.url,
    required this.semanticLabel,
    this.allUrls,
    this.index = 0,
  });

  final String url;

  /// All images in the post, enabling swipe navigation in the viewer.
  final List<String>? allUrls;

  /// This image's position within [allUrls].
  final int index;

  /// What a screen reader says instead of the picture. Supplied rather than read
  /// from [url], because a storage path is an identifier a donor never chose to
  /// hear read aloud.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        ImageViewerScreen.route(
          allUrls ?? <String>[url],
          initialIndex: index,
          semanticLabel: semanticLabel,
        ),
      ),
      child: ClipRRect(
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
      ),
    );
  }
}
