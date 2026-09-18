import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'fluent_button.dart';

enum InfoBarSeverity { info, success, caution, critical }

/// Inline status strip: icon, bold title, message, optional action, close.
class InfoBar extends StatelessWidget {
  const InfoBar({
    super.key,
    required this.title,
    this.message,
    this.severity = InfoBarSeverity.info,
    this.action,
    this.onClose,
  });

  final String title;
  final String? message;
  final InfoBarSeverity severity;
  final Widget? action;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final (IconData icon, Color tint) = switch (severity) {
      InfoBarSeverity.info => (FluentIcons.info_20_filled, colors.accent),
      InfoBarSeverity.success => (FluentIcons.checkmark_circle_20_filled, colors.success),
      InfoBarSeverity.caution => (FluentIcons.warning_20_filled, colors.caution),
      InfoBarSeverity.critical => (FluentIcons.error_circle_20_filled, colors.critical),
    };
    final background = severity == InfoBarSeverity.info
        ? colors.controlFill
        : tint.withValues(alpha: 0.12);
    return Semantics(
      liveRegion: severity != InfoBarSeverity.info,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.s, Space.s),
        decoration: BoxDecoration(
          color: background,
          borderRadius: Radii.controlRadius,
          border: Border.all(color: colors.cardStroke),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 16, color: tint),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Wrap(
                  spacing: Space.s,
                  runSpacing: Space.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(title, style: text.bodyStrong),
                    if (message != null)
                      Text(message!, style: text.body.copyWith(color: colors.textSecondary)),
                    ?action,
                  ],
                ),
              ),
            ),
            if (onClose != null)
              FluentIconButton(
                icon: FluentIcons.dismiss_16_regular,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: onClose,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}
