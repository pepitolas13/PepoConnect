import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'fluent_button.dart';

/// Centered empty view: thin 48 px icon, one sentence, optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Smaller icon and spacing for side panels.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: compact ? 32 : Sizes.iconEmpty, color: colors.textTertiary),
              SizedBox(height: compact ? Space.s : Space.l),
              Text(
                title,
                style: (compact ? text.bodyStrong : text.bodyLarge).copyWith(
                  color: colors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: Space.xs),
                Text(
                  message!,
                  style: text.body.copyWith(color: colors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: Space.l),
                FluentButton(label: actionLabel!, onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
