import 'package:flutter/foundation.dart';

/// What a report is about.
///
/// Two values, because two things can be reported. A report about a *person*
/// rather than about something they wrote is a different product decision (and a
/// different rules question), so it is not an enum member waiting to be noticed.
///
/// [wireName] is what the document stores. It is spelled out rather than taken
/// from `name` so renaming a Dart constant can never silently change the format
/// every existing report is written in — the same reason `ProfileDocuments`
/// writes `gender.name` explicitly instead of trusting an index.
enum ReportTarget {
  post('post'),
  comment('comment');

  const ReportTarget(this.wireName);

  final String wireName;

  /// The target a stored value names, or `null` when this build does not know
  /// it. Unknown is not guessed at: a report filed against a kind of thing this
  /// version cannot see is still a report, and filing it under the wrong target
  /// would hide it from whoever reads the queue.
  static ReportTarget? fromWire(String? value) {
    for (final ReportTarget target in values) {
      if (target.wireName == value) {
        return target;
      }
    }
    return null;
  }
}

/// Why something is being reported.
///
/// Deliberately short. A long list is harder to choose from on a phone, and every
/// value here has to mean something to whoever reads the queue — an option
/// nobody picks is a label that only exists to make the menu look thorough.
/// `misinformation` is first-class rather than folded into `other` because a
/// false claim about a blood drive or a donor's eligibility is the failure mode
/// that actually hurts somebody in this app.
enum ReportReason {
  spam('spam'),
  harassment('harassment'),
  hateSpeech('hate_speech'),
  misinformation('misinformation'),
  other('other');

  const ReportReason(this.wireName);

  final String wireName;

  /// The reason a stored value names, or `null` when this build does not know
  /// it. A reason invented by a newer client must not be read as `other`: the
  /// queue would then lose the distinction the reporter took trouble to make.
  static ReportReason? fromWire(String? value) {
    for (final ReportReason reason in values) {
      if (reason.wireName == value) {
        return reason;
      }
    }
    return null;
  }
}

/// What is wrong with a report's data.
enum ReportIssue {
  /// No reporter. An anonymous report cannot be rate-limited or followed up.
  reporterMissing,

  /// No target id: nothing to act on.
  targetMissing,

  /// No author uid for the reported content, so the queue cannot group a
  /// pattern of reports against one account.
  targetAuthorMissing,

  /// Longer than [ReportValidator.maxNoteLength].
  noteTooLong,

  /// A field is present but not the type the document shape promises.
  fieldMalformed,
}

/// The rules a report has to satisfy.
abstract final class ReportValidator {
  /// Three hundred characters. A note is a sentence of context, not a second
  /// copy of the post.
  static const int maxNoteLength = 300;

  static ReportIssue? validate({
    required String reporterUid,
    required String targetId,
    required String targetAuthorUid,
    String? note,
  }) {
    if (reporterUid.trim().isEmpty) {
      return ReportIssue.reporterMissing;
    }
    if (targetId.trim().isEmpty) {
      return ReportIssue.targetMissing;
    }
    if (targetAuthorUid.trim().isEmpty) {
      return ReportIssue.targetAuthorMissing;
    }
    if ((note ?? '').trim().length > maxNoteLength) {
      return ReportIssue.noteTooLong;
    }
    return null;
  }
}

/// One report against one post or comment.
///
/// **A report is a signal, not an enforcement.** Filing one changes nothing
/// about the content: it writes a row that a person can read later. Nothing in
/// this app hides a post automatically, because the Spark plan has no server to
/// make that decision and a client that hides content at another donor's request
/// is a client that can be argued into censorship.
///
/// **Write-only for the client.** The rules (Stage 8.7) will let a signed-in
/// account create its own report and read none of them; reading the queue is an
/// admin surface, and there is no admin surface yet.
///
/// [targetAuthorUid] is duplicated from the reported document on purpose: the
/// queue has to work after the post is deleted, and reading the target to find
/// out who wrote it is a read the plan charges for on every row.
@immutable
final class Report {
  const Report({
    required this.id,
    required this.reporterUid,
    required this.target,
    required this.targetId,
    required this.targetAuthorUid,
    required this.reason,
    required this.createdAt,
    this.note,
  });

  /// The `reports` document id.
  final String id;

  final String reporterUid;

  final ReportTarget target;

  /// The id of the reported post or comment — never the path, so a report
  /// survives the parent being deleted.
  final String targetId;

  final String targetAuthorUid;

  final ReportReason reason;

  /// What the reporter added in their own words, if anything.
  final String? note;

  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is Report &&
      other.id == id &&
      other.reporterUid == reporterUid &&
      other.target == target &&
      other.targetId == targetId &&
      other.targetAuthorUid == targetAuthorUid &&
      other.reason == reason &&
      other.note == note &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    reporterUid,
    target,
    targetId,
    targetAuthorUid,
    reason,
    note,
    createdAt,
  );

  @override
  String toString() =>
      'Report($id, ${target.wireName}: $targetId, ${reason.wireName})';
}
