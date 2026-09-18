import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../motion/pressable.dart';
import '../theme/tokens.dart';

enum PepoCheckboxShape { square, circle }

/// Fluent check box. Square for forms; the circular variant is the one
/// drawn over thumbnails in the gallery.
class PepoCheckbox extends StatelessWidget {
  const PepoCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.shape = PepoCheckboxShape.square,
    this.label,
    this.size = 20,
    this.onDark = false,
    this.semanticLabel,
  });

  const PepoCheckbox.circle({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 20,
    this.onDark = true,
    this.semanticLabel,
  }) : shape = PepoCheckboxShape.circle,
       label = null;

  final bool value;
  final ValueChanged<bool>? onChanged;
  final PepoCheckboxShape shape;
  final String? label;
  final double size;

  /// Drawn over an image: white stroke and a dark scrim so it stays legible.
  final bool onDark;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final motion = Motion.of(context);
    final enabled = onChanged != null;
    final radius = shape == PepoCheckboxShape.circle
        ? BorderRadius.circular(size / 2)
        : Radii.controlRadius;
    return Semantics(
      checked: value,
      child: Pressable(
        onTap: enabled ? () => onChanged!(!value) : null,
        enabled: enabled,
        showHoverFill: false,
        showPressedOverlay: false,
        scaleOnPress: shape == PepoCheckboxShape.circle,
        borderRadius: radius,
        semanticLabel: semanticLabel ?? label,
        builder: (context, states, _) {
          Color fill;
          Color stroke;
          final Color check = value ? colors.onAccent : Colors.transparent;
          if (!states.enabled) {
            fill = value ? colors.textDisabled : Colors.transparent;
            stroke = colors.textDisabled;
          } else if (value) {
            fill = states.pressed
                ? colors.accentPressed
                : states.hovered
                ? colors.accentHover
                : colors.accent;
            stroke = fill;
          } else if (onDark) {
            fill = states.hovered ? const Color(0x59000000) : const Color(0x33000000);
            stroke = Colors.white;
          } else {
            fill = states.pressed
                ? colors.subtlePressed
                : states.hovered
                ? colors.subtleHover
                : colors.controlFill;
            stroke = colors.textSecondary;
          }
          final box = AnimatedContainer(
            duration: motion.fast,
            curve: Motion.standard,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: radius,
              border: Border.all(color: stroke, width: onDark && !value ? 1.5 : 1),
            ),
            child: AnimatedScale(
              duration: motion.normal,
              curve: Motion.spring,
              scale: value ? 1 : 0.6,
              child: Icon(FluentIcons.checkmark_12_filled, size: size * 0.6, color: check),
            ),
          );
          if (label == null) return box;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              box,
              const SizedBox(width: Space.s),
              Text(
                label!,
                style: context.text.body.copyWith(
                  color: states.enabled ? colors.textPrimary : colors.textDisabled,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
