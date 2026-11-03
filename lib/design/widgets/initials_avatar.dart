import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';

/// How an identity mark is drawn.
///
/// Two approved appearances rather than one: [brand] is the app's identity disc
/// (header, profile card), [muted] is the quieter one a content card uses so a
/// row of faces does not compete with the cards behind them.
enum InitialsAvatarVariant {
  /// Brand tint, bold initials. The mark this app uses for a person.
  brand,

  /// Muted fill with an outline, theme-sized initials. For content cards.
  muted,
}

/// A circular identity mark: the photo when there is one, initials otherwise.
///
/// The fallback for a nameless profile is a person icon rather than a letter.
/// An invented "A" would read as a name the donor chose, and this app spends
/// real effort elsewhere not claiming things it does not know.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 48,
    this.variant = InitialsAvatarVariant.brand,
  });

  final String name;

  /// Only rendered when it is a non-empty URL, which since Stage 6 means a photo
  /// the donor uploaded and whose URL the profile write accepted.
  final String? photoUrl;

  final double size;

  final InitialsAvatarVariant variant;

  /// First character of the first and last word, or nothing at all.
  ///
  /// Runes rather than code units so a Bengali or emoji first character is not
  /// sliced in half, and at most two letters so a long name stays legible at
  /// 40 dp. Used by both variants: two ways of deriving initials from one name
  /// is how "Ayesha Rahman" ends up as "AR" in one place and "Ay" in another.
  String get _initials {
    final List<String> words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return '';
    }
    final String first = String.fromCharCode(words.first.runes.first);
    if (words.length == 1) {
      return first.toUpperCase();
    }
    final String last = String.fromCharCode(words.last.runes.first);
    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;
    final TextTheme text = Theme.of(context).textTheme;
    final String? photo = photoUrl?.trim();
    final String initials = _initials;

    final Widget fallback = switch (variant) {
      InitialsAvatarVariant.brand => DecoratedBox(
        decoration: BoxDecoration(
          color: palette.brandTint,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: initials.isEmpty
              ? Icon(
                  Icons.person_outline_rounded,
                  size: size * 0.5,
                  color: palette.onBrandTint,
                )
              : Text(
                  initials,
                  style: text.titleMedium?.copyWith(
                    fontSize: size * 0.36,
                    fontWeight: FontWeight.w700,
                    color: palette.onBrandTint,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
      // Deliberately theme-sized text rather than a fraction of [size]: this
      // variant sits inside a card whose type scale is already the approved one,
      // and a 40 dp disc with 12.5 px initials is the size that was reviewed.
      InitialsAvatarVariant.muted => DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surfaceMuted,
          shape: BoxShape.circle,
          border: Border.all(color: palette.outline),
        ),
        child: Center(
          child: initials.isEmpty
              ? Icon(
                  Icons.person_outline_rounded,
                  size: size * 0.5,
                  color: palette.textPrimary,
                )
              : Text(
                  initials,
                  style: text.labelMedium?.copyWith(
                    color: palette.textPrimary,
                    letterSpacing: 0,
                  ),
                ),
        ),
      ),
    };

    return SizedBox(
      width: size,
      height: size,
      child: photo == null || photo.isEmpty
          ? fallback
          : ClipOval(
              child: Image.network(
                photo,
                width: size,
                height: size,
                fit: BoxFit.cover,
                // A stale or unreachable URL must not leave a broken box where
                // the donor's identity goes.
                errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stack,
                ) => fallback,
              ),
            ),
    );
  }
}
