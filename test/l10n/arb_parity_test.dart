import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// The ARB files as written, before `gen_l10n` touches them.
///
/// These tests read the catalogues instead of the generated class because
/// `gen_l10n` happily generates a class from a Bengali file that is missing
/// half its keys — it writes a warning file and carries on. A gap would then
/// only show up as an English sentence on a Bengali screen.
Map<String, Object?> _load(String locale) => jsonDecode(
  File('lib/l10n/app_$locale.arb').readAsStringSync(),
) as Map<String, Object?>;

/// The translated messages only: `@@locale` and the `@key` descriptions are
/// metadata, not copy.
Map<String, String> _messages(Map<String, Object?> arb) {
  return <String, String>{
    for (final MapEntry<String, Object?> entry in arb.entries)
      if (!entry.key.startsWith('@')) entry.key: entry.value! as String,
  };
}

/// `{name}`-style placeholders, which must survive translation or the sentence
/// silently loses the address or the seconds count it is about.
Set<String> _placeholders(String message) {
  return RegExp(r'\{(\w+)\}').allMatches(message).map((Match m) => m[1]!).toSet();
}

/// Keys whose Bengali value is intentionally identical to the English one.
///
/// An email address is an address in every language, and "English" is the
/// endonym a Bengali speaker looks for in a language list.
const Set<String> _intentionallyUntranslated = <String>{
  'emailHint',
  'languageEnglish',
};

/// The Bengali block of Unicode. A translated sentence has to contain at least
/// one Bengali letter; a string that contains none was left in English.
final RegExp _bengaliScript = RegExp(r'[\u0980-\u09FF]');

/// Rewrites Bengali numerals (`০`–`৯`, a contiguous block at U+09E6) as ASCII,
/// so two catalogues can be compared on the number they state rather than on
/// the glyphs that state it.
String _asAsciiDigits(String message) {
  return String.fromCharCodes(
    message.runes.map(
      (int rune) =>
          rune >= 0x09E6 && rune <= 0x09EF ? 0x30 + (rune - 0x09E6) : rune,
    ),
  );
}

void main() {
  final Map<String, String> en = _messages(_load('en'));
  final Map<String, String> bn = _messages(_load('bn'));

  group('ARB catalogues', () {
    test('declare the locales the app is built for', () {
      expect(_load('en')['@@locale'], 'en');
      expect(_load('bn')['@@locale'], 'bn');
      expect(
        AppLocalizations.supportedLocales.map((Locale l) => l.languageCode),
        containsAll(<String>['en', 'bn']),
      );
    });

    test('define exactly the same messages', () {
      final Set<String> missing = en.keys.toSet().difference(bn.keys.toSet());
      final Set<String> extra = bn.keys.toSet().difference(en.keys.toSet());

      expect(missing, isEmpty, reason: 'added to English but not Bengali');
      expect(extra, isEmpty, reason: 'in Bengali but no longer used');
    });

    test('keep every placeholder the English sentence had', () {
      for (final String key in en.keys) {
        expect(
          _placeholders(bn[key]!),
          _placeholders(en[key]!),
          reason: '$key lost or invented a placeholder',
        );
      }
    });

    test('are actually translated, not copied', () {
      final List<String> untranslated = <String>[];

      for (final String key in en.keys) {
        if (_intentionallyUntranslated.contains(key)) {
          continue;
        }
        if (!_bengaliScript.hasMatch(bn[key]!)) {
          untranslated.add(key);
        }
      }

      expect(
        untranslated,
        isEmpty,
        reason: 'these Bengali messages contain no Bengali text',
      );
    });

    test('state the same numbers in both languages', () {
      // "At least 8 characters" and "অন্তত ৮ অক্ষর" agree, but only after the
      // Bengali numerals are read as numbers. A sentence that says eight in one
      // language and six in the other is a bug no placeholder check can see.
      final RegExp digits = RegExp(r'\d+');
      Iterable<String> numbers(String message) =>
          digits.allMatches(_asAsciiDigits(message)).map((RegExpMatch m) => m[0]!);

      for (final String key in en.keys) {
        expect(
          numbers(bn[key]!),
          numbers(en[key]!),
          reason: '$key disagrees about a number',
        );
      }
    });

    test('writes its numbers in Bengali numerals', () {
      // A Bengali catalogue that says "8" instead of "৮" reads as a foreign
      // string even though every letter around it is correct.
      final RegExp asciiDigit = RegExp(r'[0-9]');
      for (final String key in en.keys) {
        expect(
          asciiDigit.hasMatch(bn[key]!),
          isFalse,
          reason: '$key uses Western digits in a Bengali sentence',
        );
      }
    });

    test('report no untranslated messages from the generator', () {
      // Written by `flutter gen-l10n` on every build; `{}` means nothing is
      // missing. The key-set check above catches the addition, this catches a
      // generator run that was never refreshed.
      final File report = File('lib/l10n/untranslated.json');
      expect(report.existsSync(), isTrue);
      expect(jsonDecode(report.readAsStringSync()), isEmpty);
    });

    test('generate a typed accessor for every key', () {
      // Spot-checks the class the app actually calls: a key present in the ARB
      // but absent from the generated API would fail here rather than at
      // compile time somewhere unrelated.
      final AppLocalizations english = lookupAppLocalizations(const Locale('en'));
      final AppLocalizations bengali = lookupAppLocalizations(const Locale('bn'));

      expect(english.welcomeHeadline, en['welcomeHeadline']);
      expect(bengali.welcomeHeadline, bn['welcomeHeadline']);
      expect(english.errorPasswordTooShort(8), contains('8'));
      expect(bengali.errorPasswordTooShort(8), contains('8'));
      expect(english.resendIn(30), contains('30'));
    });
  });
}
