import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// "100 %" plus a Fluent battery glyph with the right fill level. Shows the
/// charging bolt while plugged in and turns red under 15 %.
class BatteryIndicator extends StatelessWidget {
  const BatteryIndicator({
    super.key,
    required this.level,
    this.charging = false,
    this.showLabel = true,
    this.size = 20,
    this.color,
  });

  /// 0..100, or null when unknown (nothing is rendered).
  final int? level;
  final bool charging;
  final bool showLabel;
  final double size;
  final Color? color;

  static IconData iconFor(int level, bool charging) {
    if (charging) return FluentIcons.battery_charge_20_regular;
    final tenth = (level / 10).round().clamp(0, 10);
    return switch (tenth) {
      0 => FluentIcons.battery_0_20_regular,
      1 => FluentIcons.battery_1_20_regular,
      2 => FluentIcons.battery_2_20_regular,
      3 => FluentIcons.battery_3_20_regular,
      4 => FluentIcons.battery_4_20_regular,
      5 => FluentIcons.battery_5_20_regular,
      6 => FluentIcons.battery_6_20_regular,
      7 => FluentIcons.battery_7_20_regular,
      8 => FluentIcons.battery_8_20_regular,
      9 => FluentIcons.battery_9_20_regular,
      _ => FluentIcons.battery_10_20_regular,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = level;
    if (l == null) return const SizedBox.shrink();
    final colors = context.pepo;
    final clamped = l.clamp(0, 100);
    final tint = color ?? (clamped < 15 && !charging ? colors.critical : colors.textSecondary);
    return Semantics(
      label: '$clamped %',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLabel) ...[
            Text('$clamped %', style: context.text.caption.copyWith(color: tint)),
            const SizedBox(width: Space.xs),
          ],
          Icon(iconFor(clamped, charging), size: size, color: tint),
        ],
      ),
    );
  }
}
