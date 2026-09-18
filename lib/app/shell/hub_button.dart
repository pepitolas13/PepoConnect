import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../shared/motion/pressable.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/fluent_tooltip.dart';

/// Monitor glyph with a chevron at the top of the rail. Opens the hub menu.
class HubButton extends StatelessWidget {
  const HubButton({
    super.key,
    required this.onPressed,
    required this.tooltip,
    this.connected = false,
  });

  final VoidCallback onPressed;
  final String tooltip;

  /// Small green dot when at least one device is connected.
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    return FluentTooltip(
      message: tooltip,
      child: Pressable(
        onTap: onPressed,
        semanticLabel: tooltip,
        builder: (context, states, _) => SizedBox(
          width: 48,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FluentIcons.desktop_20_regular, size: 20, color: colors.textPrimary),
                  const SizedBox(width: 2),
                  Icon(FluentIcons.chevron_down_12_regular, size: 12, color: colors.textSecondary),
                ],
              ),
              if (connected)
                Positioned(
                  right: 11,
                  top: 9,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: colors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.bgBase, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
