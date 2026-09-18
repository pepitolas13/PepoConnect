import 'package:flutter/material.dart';

import '../motion/pressable.dart';
import '../theme/tokens.dart';

/// Surface with a 1 px alpha stroke and radius 8. With [onTap] it becomes a
/// [Pressable] tile with the pointer light.
class PepoCard extends StatelessWidget {
  const PepoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.l),
    this.onTap,
    this.onSecondaryTap,
    this.selected = false,
    this.color,
    this.borderRadius = Radii.cardRadius,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final PositionCallback? onSecondaryTap;

  /// Accent border (selected thumbnail / card).
  final bool selected;
  final Color? color;
  final BorderRadius borderRadius;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    Widget body = Padding(padding: padding, child: child);
    if (clip) body = ClipRRect(borderRadius: borderRadius, child: body);
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? colors.card,
        borderRadius: borderRadius,
        border: Border.all(
          color: selected ? colors.accent : colors.cardStroke,
          width: selected ? 2 : 1,
        ),
      ),
      child: body,
    );
    if (onTap == null && onSecondaryTap == null) return box;
    return Pressable(
      onTap: onTap,
      onSecondaryTap: onSecondaryTap,
      borderRadius: borderRadius,
      hoverLight: true,
      child: box,
    );
  }
}
