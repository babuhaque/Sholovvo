import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';

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
  });

  final String name;

  /// Only rendered when it is a non-empty URL, which since Stage 6 means a photo
  /// the donor uploaded and whose URL the profile write accepted.
  final String? photoUrl;

  final double size;

  /// First character of the first and last word, or nothing at all.
  ///
  /// Runes rather than code units so a Bengali or emoji first character is not
  /// sliced in half, and at most two letters so a long name stays legible at
  /// 40 dp.
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
    final String? photo = photoUrl?.trim();

    final Widget fallback = DecoratedBox(
      decoration: BoxDecoration(
        color: palette.brandTint,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: _initials.isEmpty
            ? Icon(
                Icons.person_outline_rounded,
                size: size * 0.5,
                color: palette.onBrandTint,
              )
            : Text(
                _initials,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w700,
                  color: palette.onBrandTint,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );

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
                errorBuilder:
                    (BuildContext context, Object error, StackTrace? stack) =>
                        fallback,
              ),
            ),
    );
  }
}
