import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/data/post_edit_service.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// A bottom sheet for editing the text of an existing post.
///
/// Author-only: shows a pre-filled text field with the current post text and
/// a Save button. On success pops with `true` so the caller can refresh the
/// feed; on failure shows an inline error and stays open.
class EditPostSheet extends ConsumerStatefulWidget {
  const EditPostSheet({super.key, required this.post});

  final Post post;

  /// Shows the edit sheet. Returns a non-null value if the post was saved or deleted.
  static Future<Object?> show(BuildContext context, {required Post post}) {
    return showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext ctx) => EditPostSheet(post: post),
    );
  }

  @override
  ConsumerState<EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends ConsumerState<EditPostSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.post.text);
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);

    final PostEditService service = ref.read(postEditServiceProvider);
    final Result<void> result = await service.editText(
      postId: widget.post.id,
      uid: uid,
      newText: _controller.text,
    );

    if (!mounted) return;

    switch (result) {
      case Success<void>():
        Navigator.of(context).pop(true);
      case FailureResult<void>():
        setState(() {
          _isSaving = false;
          _errorMessage = context.l10n.feedEditError;
        });
    }
  }

  Future<void> _delete() async {
    final AppLocalizations l10n = context.l10n;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l10n.feedDeleteConfirmTitle),
        content: Text(l10n.feedDeleteConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.feedDeleteConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);

    final PostEditService service = ref.read(postEditServiceProvider);
    final Result<void> result = await service.deletePost(
      postId: widget.post.id,
      uid: uid,
    );

    if (!mounted) return;

    switch (result) {
      case Success<void>():
        Navigator.of(context).pop('deleted');
      case FailureResult<void>():
        setState(() {
          _isSaving = false;
          _errorMessage = l10n.feedDeleteError;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.gutter,
        right: AppSpacing.gutter,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.feedEditTitle,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            maxLines: 6,
            minLines: 3,
            maxLength: PostValidator.maxTextLength,
            decoration: InputDecoration(
              hintText: l10n.feedEditHint,
              border: const OutlineInputBorder(),
            ),
          ),
          if (_errorMessage != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          SolovvoButton(
            label: _isSaving ? l10n.feedEditSaving : l10n.feedEditSave,
            isLoading: _isSaving,
            onPressed: _isSaving ? null : _save,
            expand: true,
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: _isSaving ? null : _delete,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: Text(l10n.feedDeleteAction),
            ),
          ),
        ],
      ),
    );
  }
}
