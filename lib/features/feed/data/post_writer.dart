import 'package:sholovvo_app/core/result/result.dart';

/// The one document write the feed performs.
///
/// Split out of the repository for the same reason the read has a documents
/// seam: the part that decides *what* a post is can then be tested against a
/// fake, while the part that touches Firestore stays short enough to read in one
/// go. A write is also the half that costs money and cannot be undone, so it is
/// the half worth being able to observe in a test.
///
/// [newPostId] exists so the id is known **before** the write. That ordering is
/// what lets the repository build the complete post it returns — id included —
/// in one go, instead of writing a document and then rebuilding the entity
/// around the address it landed at.
abstract interface class PostWriter {
  /// The uid of the signed-in donor, or `null` when nobody is signed in.
  ///
  /// Read from the session by the implementation, because that is the value
  /// `firestore.rules` will compare `authorUid` against. It lives on this port
  /// rather than being passed into the repository so the repository holds no
  /// Firebase type at all — which is what makes the write testable without an
  /// app, exactly as the read side is.
  String? get authorUid;

  /// A fresh document id, allocated without writing anything.
  ///
  /// Firestore generates these client-side, so this costs no network round trip.
  String newPostId();

  /// Creates the document at [id] with [fields], replacing anything already
  /// there.
  ///
  /// [fields] is exactly what `PostDocument.toCreateMap` produced; this layer
  /// does not add, rename or default a field.
  Future<Result<void>> createPost(String id, Map<String, Object?> fields);
}
