import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Hover tooltip with a 600 ms delay. Never shown on touch platforms.
class FluentTooltip extends StatelessWidget {
  const FluentTooltip({
    super.key,
    required this.message,
    required this.child,
    this.preferBelow = true,
    this.shortcut,
  });

  final String message;
  final Widget child;
  final bool preferBelow;

  /// Keyboard shortcut shown after the message, e.g. `Ctrl+1`.
  final String? shortcut;

  static bool get _touch =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    if (_touch || message.isEmpty) return child;
    final colors = context.pepo;
    final text = shortcut == null ? message : '$message  $shortcut';
    return Tooltip(
      message: text,
      preferBelow: preferBelow,
      waitDuration: const Duration(milliseconds: 600),
      showDuration: const Duration(seconds: 4),
      verticalOffset: 20,
      padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: 5),
      decoration: BoxDecoration(
        color: colors.flyoutSurface,
        borderRadius: Radii.controlRadius,
        border: Border.all(color: colors.cardStroke),
        boxShadow: PepoShadows.toast,
      ),
      textStyle: context.text.caption.copyWith(color: colors.textPrimary),
      child: child,
    );
  }
}
