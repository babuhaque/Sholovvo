import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/features/feed/domain/entities/report.dart';

void main() {
  group('ReportTarget wire names', () {
    test('post → "post"', () {
      expect(ReportTarget.post.wireName, 'post');
    });

    test('comment → "comment"', () {
      expect(ReportTarget.comment.wireName, 'comment');
    });

    test('fromWire round-trips every value', () {
      for (final ReportTarget t in ReportTarget.values) {
        expect(ReportTarget.fromWire(t.wireName), t);
      }
    });

    test('fromWire returns null for unknown', () {
      expect(ReportTarget.fromWire('unknown'), isNull);
    });
  });

  group('ReportReason wire names', () {
    test('match the Firestore rules allow-list', () {
      // firestore.rules L593 checks:
      // reason in ['spam', 'harassment', 'hate_speech', 'misinformation', 'other']
      const Set<String> allowed = <String>{
        'spam',
        'harassment',
        'hate_speech',
        'misinformation',
        'other',
      };
      for (final ReportReason r in ReportReason.values) {
        expect(
          allowed,
          contains(r.wireName),
          reason: '${r.name}.wireName="${r.wireName}" not in rules',
        );
      }
    });

    test('fromWire round-trips every value', () {
      for (final ReportReason r in ReportReason.values) {
        expect(ReportReason.fromWire(r.wireName), r);
      }
    });

    test('fromWire returns null for unknown', () {
      expect(ReportReason.fromWire('future_reason'), isNull);
    });
  });

  group('ReportValidator', () {
    test('valid report returns null', () {
      expect(
        ReportValidator.validate(
          reporterUid: 'uid-1',
          targetId: 'post-abc',
          targetAuthorUid: 'uid-2',
        ),
        isNull,
      );
    });

    test('empty reporterUid → reporterMissing', () {
      expect(
        ReportValidator.validate(
          reporterUid: '  ',
          targetId: 'post-abc',
          targetAuthorUid: 'uid-2',
        ),
        ReportIssue.reporterMissing,
      );
    });

    test('empty targetId → targetMissing', () {
      expect(
        ReportValidator.validate(
          reporterUid: 'uid-1',
          targetId: '',
          targetAuthorUid: 'uid-2',
        ),
        ReportIssue.targetMissing,
      );
    });

    test('empty targetAuthorUid → targetAuthorMissing', () {
      expect(
        ReportValidator.validate(
          reporterUid: 'uid-1',
          targetId: 'post-abc',
          targetAuthorUid: '  ',
        ),
        ReportIssue.targetAuthorMissing,
      );
    });

    test('note exceeding maxNoteLength → noteTooLong', () {
      final String longNote = 'a' * (ReportValidator.maxNoteLength + 1);
      expect(
        ReportValidator.validate(
          reporterUid: 'uid-1',
          targetId: 'post-abc',
          targetAuthorUid: 'uid-2',
          note: longNote,
        ),
        ReportIssue.noteTooLong,
      );
    });

    test('note at exact limit is valid', () {
      final String maxNote = 'a' * ReportValidator.maxNoteLength;
      expect(
        ReportValidator.validate(
          reporterUid: 'uid-1',
          targetId: 'post-abc',
          targetAuthorUid: 'uid-2',
          note: maxNote,
        ),
        isNull,
      );
    });

    test('null note is valid', () {
      expect(
        ReportValidator.validate(
          reporterUid: 'uid-1',
          targetId: 'post-abc',
          targetAuthorUid: 'uid-2',
          note: null,
        ),
        isNull,
      );
    });
  });
}
