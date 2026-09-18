import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../shared/i18n/l10n.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/fluent_button.dart';
import '../../shared/widgets/pepo_badge.dart';

/// Frame of the right-hand activity panel: title with unread count,
/// "Clear all" and a close button. The list itself is [child].
class ActivityPanelFrame extends StatelessWidget {
  const ActivityPanelFrame({
    super.key,
    required this.child,
    this.unread = 0,
    this.onClearAll,
    this.onClose,
    this.width = Sizes.activityPanelWidth,
  });

  final Widget child;
  final int unread;
  final VoidCallback? onClearAll;
  final VoidCallback? onClose;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final t = context.t;
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: colors.divider)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.s, 0),
                child: Row(
                  children: [
                    Text(t.activityTitle, style: text.bodyStrong),
                    const SizedBox(width: Space.s),
                    PepoBadge(count: unread),
                    const Spacer(),
                    if (onClearAll != null)
                      FluentButton.subtle(
                        label: t.clearAll,
                        size: FluentButtonSize.small,
                        onPressed: onClearAll,
                      ),
                    if (onClose != null)
                      FluentIconButton(
                        icon: FluentIcons.dismiss_16_regular,
                        tooltip: t.activityPanelHide,
                        onPressed: onClose,
                      ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: colors.divider),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
