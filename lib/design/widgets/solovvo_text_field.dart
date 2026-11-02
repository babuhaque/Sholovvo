import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';

/// The app's text input.
///
/// A field, not a bare `TextField`: it owns the uppercase label, the leading
/// icon, the password visibility toggle and the inline error row, so every form
/// in the app (registration has nine fields) stays consistent and accessible.
class SolovvoTextField extends StatefulWidget {
  const SolovvoTextField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.showObscureToggle = false,
    this.showPasswordLabel = 'Show password',
    this.hidePasswordLabel = 'Hide password',
    this.errorText,
    this.helperText,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.maxLines = 1,
    this.autofillHints,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;

  /// Whether the value is masked by default.
  final bool obscureText;

  /// Render a visibility toggle in the suffix slot.
  final bool showObscureToggle;

  /// Tooltips for that toggle. English defaults keep the widget usable on its
  /// own; the forms pass the localised strings.
  final String showPasswordLabel;
  final String hidePasswordLabel;

  final String? errorText;
  final String? helperText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final int maxLines;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;

  @override
  State<SolovvoTextField> createState() => _SolovvoTextFieldState();
}

class _SolovvoTextFieldState extends State<SolovvoTextField> {
  late bool _obscured = widget.obscureText;

  @override
  void didUpdateWidget(SolovvoTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) {
      _obscured = widget.obscureText;
    }
  }

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
    borderRadius: AppRadius.mdRadius,
    borderSide: BorderSide(color: color, width: width),
  );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SolovvoPalette palette = context.palette;
    final bool hasError = widget.errorText != null;
    final Color restingBorder = hasError
        ? palette.danger
        : palette.outlineStrong;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.label != null) ...<Widget>[
          Text(
            widget.label!.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              color: hasError ? palette.danger : palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          autofillHints: widget.autofillHints,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          cursorColor: palette.brandInk,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
            color: widget.enabled ? palette.textPrimary : palette.textSecondary,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: theme.textTheme.bodyMedium,
            filled: true,
            fillColor: widget.enabled ? palette.surface : palette.surfaceMuted,
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon, size: 20, color: palette.textSecondary),
            prefixIconConstraints: const BoxConstraints(minWidth: 46),
            suffixIcon: widget.showObscureToggle
                ? IconButton(
                    onPressed: () => setState(() => _obscured = !_obscured),
                    tooltip: _obscured
                        ? widget.showPasswordLabel
                        : widget.hidePasswordLabel,
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: palette.textSecondary,
                    ),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            border: _border(restingBorder, 1.2),
            enabledBorder: _border(restingBorder, 1.2),
            focusedBorder: _border(
              hasError ? palette.danger : palette.brandInk,
              1.6,
            ),
            disabledBorder: _border(palette.outline, 1.2),
            errorBorder: _border(palette.danger, 1.2),
            focusedErrorBorder: _border(palette.danger, 1.6),
          ),
        ),
        if (hasError) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.error_outline, size: 14, color: palette.danger),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.errorText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.danger,
                  ),
                ),
              ),
            ],
          ),
        ] else if (widget.helperText != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(widget.helperText!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}
