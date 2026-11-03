import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/post_draft.dart';

/// The feed's write side.
///
/// Kept apart from `FeedRepository` on purpose: the feed screen reads pages, the
/// compose screen publishes one post, and neither has any use for the other's
/// method. One method here, because this stage ships exactly one write — no
/// edit, no delete, no like and no comment, each of which needs a rules decision
/// of its own before it can be declared.
abstract interface class PostRepository {
  /// Publishes [draft] as a new post, authored by the signed-in donor.
  ///
  /// The author's uid is deliberately not part of the draft: this takes it from
  /// the session, which is the value `firestore.rules` compares `authorUid`
  /// against. The draft's name and photo are the snapshot the document stores,
  /// not an identity claim.
  ///
  /// The returned [Post] carries the new document id and the client's clock. The
  /// document itself is stamped by the server, so a just-published post is
  /// placed from a local estimate until the next read agrees with the server.
  /// That is the one place this app shows a client timestamp, and it is accepted
  /// only because the alternative is telling a donor nothing after a write that
  /// succeeded.
  Future<Result<Post>> publish(PostDraft draft);
}
