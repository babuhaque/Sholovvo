import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/data/comment_service.dart';
import 'package:sholovvo_app/features/feed/domain/entities/comment.dart';

/// The Firestore-backed comment service provider.
///
/// Same lazy-construction pattern as [feedRepositoryProvider] and
/// [postLikeServiceProvider]. A test overrides this and never touches a live
/// backend.
final Provider<CommentService> commentServiceProvider =
    Provider<CommentService>((Ref ref) {
  return FirestoreCommentService(FirebaseFirestore.instance);
});

/// Everything the comment sheet draws, in one immutable value.
@immutable
final class CommentState {
  const CommentState({
    this.postId,
    this.comments = const <Comment>[],
    this.isLoading = false,
    this.isSubmitting = false,
    this.failure,
    this.loaded = false,
  });

  /// The post whose thread is open. Set on first [CommentController.load] call.
  final String? postId;

  /// The thread, oldest first.
  final List<Comment> comments;

  /// A page load is in flight.
  final bool isLoading;

  /// A comment submission is in flight.
  final bool isSubmitting;

  /// Why the last operation failed, or `null`.
  final Failure? failure;

  /// Whether the first load has resolved.
  final bool loaded;

  bool get isEmpty => loaded && comments.isEmpty;

  CommentState copyWith({
    String? postId,
    List<Comment>? comments,
    bool? isLoading,
    bool? isSubmitting,
    Failure? failure,
    bool clearFailure = false,
    bool? loaded,
  }) {
    return CommentState(
      postId: postId ?? this.postId,
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : (failure ?? this.failure),
      loaded: loaded ?? this.loaded,
    );
  }
}

/// Manages one post's comment thread.
///
/// A single provider — the comment sheet is modal, so only one thread is
/// active at a time. The controller:
/// - Loads comments on [open], replacing the previous thread.
/// - Submits a new comment via [submitComment] (optimistic append + rollback).
/// - Notifies the [FeedController] to increment `commentCount` on success.
class CommentController extends Notifier<CommentState> {
  @override
  CommentState build() => const CommentState();

  /// Opens a thread for [postId]: clears the previous state, then loads.
  Future<void> open(String postId) async {
    state = CommentState(postId: postId, isLoading: true);
    final CommentService service = ref.read(commentServiceProvider);
    final Result<List<Comment>> result = await service.loadComments(postId);
    // Guard against a concurrent open() replacing the state while awaiting.
    if (state.postId != postId) {
      return;
    }
    switch (result) {
      case Success<List<Comment>>(:final value):
        state = state.copyWith(
          comments: value,
          isLoading: false,
          loaded: true,
        );
      case FailureResult<List<Comment>>(:final failure):
        state = state.copyWith(
          isLoading: false,
          loaded: true,
          failure: failure,
        );
    }
  }

  /// Retries loading the current thread.
  Future<void> retry() async {
    final String? id = state.postId;
    if (id != null) {
      await open(id);
    }
  }

  /// Submits a new comment. Returns `true` on success.
  Future<bool> submitComment({
    required String authorUid,
    required String authorName,
    String? authorPhotoUrl,
    required String text,
    String? parentId,
    String? replyToName,
  }) async {
    final String? postId = state.postId;
    if (postId == null) {
      return false;
    }
    state = state.copyWith(isSubmitting: true, clearFailure: true);
    final CommentService service = ref.read(commentServiceProvider);
    final Result<Comment> result = await service.addComment(
      postId: postId,
      authorUid: authorUid,
      authorName: authorName,
      authorPhotoUrl: authorPhotoUrl,
      text: text,
      parentId: parentId,
      replyToName: replyToName,
    );

    switch (result) {
      case Success<Comment>(:final value):
        // Guard: if the sheet switched to a different post while writing.
        if (state.postId != postId) {
          return true;
        }
        state = state.copyWith(
          comments: <Comment>[...state.comments, value],
          isSubmitting: false,
        );
        ref
            .read(feedControllerProvider.notifier)
            .incrementCommentCount(postId);
        return true;
      case FailureResult<Comment>(:final failure):
        state = state.copyWith(
          isSubmitting: false,
          failure: failure,
        );
        return false;
    }
  }

  /// Deletes a comment authored by the current user. Returns `true` on success.
  Future<bool> deleteComment(String commentId) async {
    final String? postId = state.postId;
    if (postId == null) {
      return false;
    }
    final CommentService service = ref.read(commentServiceProvider);
    final Result<void> result = await service.deleteComment(
      postId: postId,
      commentId: commentId,
    );

    switch (result) {
      case Success<void>():
        if (state.postId != postId) return true;
        state = state.copyWith(
          comments: state.comments
              .where((Comment c) => c.id != commentId)
              .toList(),
        );
        ref
            .read(feedControllerProvider.notifier)
            .decrementCommentCount(postId);
        return true;
      case FailureResult<void>():
        return false;
    }
  }
}

/// Single provider for the comment sheet.
final NotifierProvider<CommentController, CommentState>
    commentControllerProvider =
    NotifierProvider<CommentController, CommentState>(
  CommentController.new,
);
