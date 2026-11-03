import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/features/feed/domain/entities/report.dart';

Report _report({
  String reporterUid = 'uid-verified',
  String targetId = 'post-1',
  String targetAuthorUid = 'uid-author',
  String? note,
}) {
  return Report(
    id: 'report-1',
    reporterUid: reporterUid,
    target: ReportTarget.post,
    targetId: targetId,
    targetAuthorUid: targetAuthorUid,
    reason: ReportReason.spam,
    note: note,
    createdAt: DateTime.utc(2026, 10, 20, 11),
  );
}

void main() {
  group('ReportTarget', () {
    test('round-trips every stored value', () {
      for (final ReportTarget target in ReportTarget.values) {
        expect(ReportTarget.fromWire(target.wireName), target);
      }
    });

    test('stores a spelled-out name rather than the Dart constant', () {
      // Renaming `hateSpeech` must not silently change a format that existing
      // reports are already written in.
      expect(ReportTarget.post.wireName, 'post');
      expect(ReportTarget.comment.wireName, 'comment');
    });

    test('an unknown or absent value yields nothing rather than a guess', () {
      expect(ReportTarget.fromWire('story'), isNull);
      expect(ReportTarget.fromWire(''), isNull);
      expect(ReportTarget.fromWire(null), isNull);
      expect(ReportTarget.fromWire('Post'), isNull);
    });

    test('every wire name is unique', () {
      final Set<String> names = ReportTarget.values
          .map((ReportTarget value) => value.wireName)
          .toSet();

      expect(names.length, ReportTarget.values.length);
    });
  });

  group('ReportReason', () {
    test('round-trips every stored value', () {
      for (final ReportReason reason in ReportReason.values) {
        expect(ReportReason.fromWire(reason.wireName), reason);
      }
    });

    test('a camelCase constant is stored in snake case', () {
      expect(ReportReason.hateSpeech.wireName, 'hate_speech');
      expect(ReportReason.fromWire('hate_speech'), ReportReason.hateSpeech);
    });

    test('an unknown reason is not folded into "other"', () {
      // Folding it would lose the distinction the reporter took trouble to make.
      expect(ReportReason.fromWire('doxxing'), isNull);
      expect(ReportReason.fromWire(null), isNull);
    });

    test('the set is short enough to choose from on a phone', () {
      expect(ReportReason.values.length, 5);
      expect(ReportReason.values, contains(ReportReason.misinformation));
    });

    test('every wire name is unique', () {
      final Set<String> names = ReportReason.values
          .map((ReportReason value) => value.wireName)
          .toSet();

      expect(names.length, ReportReason.values.length);
    });
  });

  group('ReportValidator', () {
    test('a report with a reporter, a target and its author is valid', () {
      expect(
        ReportValidator.validate(
          reporterUid: 'uid-verified',
          targetId: 'post-1',
          targetAuthorUid: 'uid-author',
        ),
        isNull,
      );
    });

    test('an anonymous report is refused', () {
      expect(
        ReportValidator.validate(
          reporterUid: '  ',
          targetId: 'post-1',
          targetAuthorUid: 'uid-author',
        ),
        ReportIssue.reporterMissing,
      );
    });

    test('a report with nothing to act on is refused', () {
      expect(
        ReportValidator.validate(
          reporterUid: 'uid-verified',
          targetId: '',
          targetAuthorUid: 'uid-author',
        ),
        ReportIssue.targetMissing,
      );
      expect(
        ReportValidator.validate(
          reporterUid: 'uid-verified',
          targetId: 'post-1',
          targetAuthorUid: '',
        ),
        ReportIssue.targetAuthorMissing,
      );
    });

    test('a note may be absent, but not an essay', () {
      expect(
        ReportValidator.validate(
          reporterUid: 'uid-verified',
          targetId: 'post-1',
          targetAuthorUid: 'uid-author',
        ),
        isNull,
      );
      expect(ReportValidator.maxNoteLength, 300);
      expect(
        ReportValidator.validate(
          reporterUid: 'uid-verified',
          targetId: 'post-1',
          targetAuthorUid: 'uid-author',
          note: 'a' * ReportValidator.maxNoteLength,
        ),
        isNull,
      );
      expect(
        ReportValidator.validate(
          reporterUid: 'uid-verified',
          targetId: 'post-1',
          targetAuthorUid: 'uid-author',
          note: 'a' * (ReportValidator.maxNoteLength + 1),
        ),
        ReportIssue.noteTooLong,
      );
    });
  });

  group('Report', () {
    test('compares by value', () {
      expect(_report(), _report());
      expect(_report().hashCode, _report().hashCode);
      expect(_report(), isNot(_report(note: 'context')));
    });

    test('describes itself without quoting the note', () {
      final Report report = _report(
        note: 'A note that should stay out of logs',
      );

      expect(report.toString(), contains('post-1'));
      expect(report.toString(), isNot(contains('stay out of logs')));
    });
  });
}
