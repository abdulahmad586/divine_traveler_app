import 'package:flutter/material.dart';
import 'package:tahfeex/shared/constants/constants.dart';

import '../resources/resources.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppDialogAction — describes a single button in an AppDialog.
// ─────────────────────────────────────────────────────────────────────────────

class AppDialogAction {
  final String label;
  final VoidCallback? onPressed;

  /// Renders as a filled primary button.
  final bool isPrimary;

  /// Renders label in red — for irreversible destructive operations.
  final bool isDestructive;

  const AppDialogAction({
    required this.label,
    this.onPressed,
    this.isPrimary = false,
    this.isDestructive = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// AppDialog — premium replacement for AlertDialog used throughout the app.
// ─────────────────────────────────────────────────────────────────────────────

class AppDialog extends StatelessWidget {
  /// Short, bold heading.
  final String title;

  /// Optional plain-text body. Use [content] for richer layouts.
  final String? body;

  /// Optional custom body widget (e.g. TextField). Takes precedence over [body].
  final Widget? content;

  final List<AppDialogAction> actions;

  const AppDialog({
    super.key,
    required this.title,
    this.body,
    this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),

            // Body
            if (content != null || body != null) ...[
              const SizedBox(height: 10),
              if (content != null)
                content!
              else
                Text(
                  body!,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],

            const SizedBox(height: 20),

            // Actions — right-aligned row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (int i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _ActionButton(action: actions[i]),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ActionButton — renders one dialog action in the appropriate style.
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final AppDialogAction action;
  const _ActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final label = Text(
      action.label,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );

    if (action.isPrimary) {
      return FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.buttonRadius)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: action.onPressed,
        child: label,
      );
    }

    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor:
            action.isDestructive ? Colors.red[400] : AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: action.onPressed,
      child: label,
    );
  }
}
