import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/features/feed/presentation/feed_messages.dart';

import '../../support/test_app.dart';

/// A fixed "now", so the boundaries below are asserted rather than observed.
final DateTime _now = DateTime.utc(2026, 11, 3, 12);

String _age(Duration ago) {
  return feedRelativeTime(
    english,
    _now.subtract(ago),
    olderDate: '27 Oct',
    now: _now,
  );
}

void main() {
  group('feedRelativeTime', () {
    test('says "just now" for the first minute', () {
      expect(_age(const Duration(seconds: 0)), 'Just now');
      expect(_age(const Duration(seconds: 59)), 'Just now');
    });

    test('counts minutes up to the hour', () {
      expect(_age(const Duration(seconds: 60)), '1 minute ago');
      expect(_age(const Duration(minutes: 59)), '59 minutes ago');
    });

    test('counts hours up to the day', () {
      expect(_age(const Duration(minutes: 60)), '1 hour ago');
      expect(_age(const Duration(hours: 23)), '23 hours ago');
    });

    test('counts days up to a week', () {
      expect(_age(const Duration(hours: 24)), '1 day ago');
      expect(_age(const Duration(days: 6)), '6 days ago');
    });

    test('switches to a calendar date after a week', () {
      // `feedCalendarAfterDays` is the published boundary; the test reads it
      // rather than repeating the number.
      expect(
        _age(Duration(days: feedCalendarAfterDays - 1)),
        isNot('On 27 Oct'),
      );
      expect(_age(Duration(days: feedCalendarAfterDays)), 'On 27 Oct');
      expect(_age(const Duration(days: 400)), 'On 27 Oct');
    });

    test('reads a future timestamp as "just now"', () {
      // A device clock that disagrees with the server. "In 4 minutes" would be
      // arithmetic the reader has to reconcile with a post that is visibly
      // already there.
      expect(
        feedRelativeTime(
          english,
          _now.add(const Duration(minutes: 4)),
          olderDate: '27 Oct',
          now: _now,
        ),
        'Just now',
      );
    });

    test('speaks Bangla when the app is in Bangla', () {
      expect(
        feedRelativeTime(
          bangla,
          _now.subtract(const Duration(minutes: 30)),
          olderDate: '২৭ অক্টো',
          now: _now,
        ),
        '৩০ মিনিট আগে',
      );
      expect(
        feedRelativeTime(
          bangla,
          _now.subtract(const Duration(days: 40)),
          olderDate: '২৭ সেপ্ট',
          now: _now,
        ),
        '২৭ সেপ্ট তারিখে',
      );
    });
  });

  group('feedFailureMessage', () {
    test('names every failure the repository can return', () {
      // The switch in the implementation is exhaustive; this list is what keeps
      // the words distinct. A shared sentence would pass a hand-written switch
      // that mapped two branches to the same catalogue key.
      final Map<Failure, String> messages = <Failure, String>{
        const AuthFailure(): english.failureUnknownAuth,
        const NetworkFailure(): english.failureNetwork,
        const RateLimitedFailure(): english.failureRateLimited,
        const PermissionFailure(): english.failurePermission,
        const NotFoundFailure(): english.failureNotFound,
        const ConflictFailure(): english.failureConflict,
        const ValidationFailure(messageKey: 'feedCursorInvalid'):
            english.failureValidation,
        const ConfigurationFailure(setting: 'supabase'):
            english.failureUnexpected,
        const UnexpectedFailure(): english.failureUnexpected,
      };

      for (final MapEntry<Failure, String> entry in messages.entries) {
        expect(
          feedFailureMessage(english, entry.key),
          entry.value,
          reason: 'wrong sentence for ${entry.key.runtimeType}',
        );
      }
    });

    test('a refused read tells the donor it was refused', () {
      // The one failure a signed-in donor can actually provoke: the rules said
      // no. Reporting it as "no connection" would send them to fix the wrong
      // thing.
      expect(
        feedFailureMessage(english, const PermissionFailure()),
        'You do not have permission to do that.',
      );
    });

    test('speaks Bangla when the app is in Bangla', () {
      expect(
        feedFailureMessage(bangla, const NetworkFailure()),
        bangla.failureNetwork,
      );
      expect(bangla.failureNetwork, isNot(english.failureNetwork));
    });
  });
}
