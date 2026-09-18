import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../motion/pressable.dart';
import '../theme/tokens.dart';

/// Fluent toggle: 40×20 track, 12 px knob that grows to 14 px on hover and
/// slides with the emphasized curve (200 ms).
class ToggleSwitch extends StatelessWidget {
  const ToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Optional text to the right of the track.
  final String? label;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final motion = Motion.of(context);
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      child: Pressable(
        onTap: enabled ? () => onChanged!(!value) : null,
        enabled: enabled,
        showHoverFill: false,
        showPressedOverlay: false,
        scaleOnPress: false,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        semanticLabel: semanticLabel ?? label,
        builder: (context, states, _) {
          final Color track;
          final Color knob;
          final Color stroke;
          if (!states.enabled) {
            track = value ? colors.textDisabled : Colors.transparent;
            knob = value ? colors.bgBase : colors.textDisabled;
            stroke = value ? Colors.transparent : colors.textDisabled;
          } else if (value) {
            track = states.pressed
                ? colors.accentPressed
                : states.hovered
                ? colors.accentHover
                : colors.accent;
            knob = colors.onAccent;
            stroke = Colors.transparent;
          } else {
            track = states.pressed
                ? colors.subtlePressed
                : states.hovered
                ? colors.subtleHover
                : Colors.transparent;
            knob = colors.textSecondary;
            stroke = colors.textSecondary;
          }
          final knobSize = states.pressed ? 17.0 : (states.hovered && states.enabled ? 14.0 : 12.0);
          final switchWidget = AnimatedContainer(
            duration: motion.fast,
            curve: Motion.standard,
            width: Sizes.toggleWidth,
            height: Sizes.toggleHeight,
            decoration: BoxDecoration(
              color: track,
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              border: Border.all(color: stroke),
            ),
            child: AnimatedAlign(
              duration: motion.normal,
              curve: Motion.emphasized,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: AnimatedContainer(
                  duration: motion.fast,
                  curve: Motion.standard,
                  width: states.pressed ? knobSize + 3 : knobSize,
                  height: knobSize,
                  decoration: BoxDecoration(
                    color: knob,
                    borderRadius: BorderRadius.circular(knobSize / 2),
                  ),
                ),
              ),
            ),
          );
          if (label == null) return switchWidget;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              switchWidget,
              const SizedBox(width: Space.m),
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
