import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/data/models/post_document.dart';
import 'package:sholovvo_app/features/feed/data/post_writer.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/post_draft.dart';
import 'package:sholovvo_app/features/feed/domain/post_repository.dart';

/// Turns a [PostDraft] into one `posts` document.
///
/// Three decisions live here, and nowhere else:
///
/// * **The author's uid comes from the session.** Not from the draft, not from
///   the profile: `firestore.rules` compares `authorUid` against
///   `request.auth.uid`, so the only value that can be written successfully is
///   the one the token already proves. It is read off [PostWriter] rather than
///   off a `FirebaseAuth` handed to this class, so this file holds no Firebase
///   type and the write path is testable without an app.
/// * **An unpublishable draft never reaches the network.** The same
///   [PostValidator] rules the mapper applies on read are applied before the
///   write, so a post that no reader would accept costs no quota. The rules
///   stage will enforce the same limits server-side; this is the client half.
/// * **The document is stamped by the server, the returned entity by the
///   client.** See [PostDocument.toCreateMap] and [PostRepository.publish].
class FirestorePostRepository implements PostRepository {
  FirestorePostRepository(this._writer, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final PostWriter _writer;
  final DateTime Function() _clock;

  @override
  Future<Result<Post>> publish(PostDraft draft) async {
    // Checked before anything else so a signed-out attempt is reported as an
    // auth problem rather than as the `permission-denied` the rules would send.
    final String? uid = _writer.authorUid;
    if (uid == null || uid.isEmpty) {
      return const FailureResult<Post>(
        AuthFailure(debugMessage: 'A post needs a signed-in author'),
      );
    }

    final PostIssue? issue = draft.issue;
    if (issue != null) {
      return FailureResult<Post>(
        ValidationFailure(
          messageKey: issue.name,
          debugMessage: 'Post draft rejected: ${issue.name}',
        ),
      );
    }

    final DateTime now = _clock().toUtc();
    final Post post = Post(
      id: _writer.newPostId(),
      authorUid: uid,
      authorName: draft.author.name,
      authorPhotoUrl: draft.author.photoUrl,
      text: draft.text,
      imageUrls: draft.imageUrls,
      imagePaths: draft.imagePaths,
      createdAt: now,
      updatedAt: now,
    );

    final Result<void> written = await _writer.createPost(
      post.id,
      PostDocument.toCreateMap(post),
    );
    final Failure? failure = written.failureOrNull;
    if (failure != null) {
      // The entity is dropped, not returned with a failure attached: a post that
      // is not in the database must not be shown in a feed as if it were.
      return FailureResult<Post>(failure);
    }

    return Success<Post>(post);
  }
}
