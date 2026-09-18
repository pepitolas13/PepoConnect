import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../motion/pressable.dart';
import '../motion/progress_ring.dart';
import '../theme/tokens.dart';
import 'fluent_tooltip.dart';

enum FluentButtonStyle { primary, secondary, subtle }

enum FluentButtonSize { small, medium, large }

/// Fluent button: 32 px high, radius 4, 12 px padding, 16 px icon.
class FluentButton extends StatelessWidget {
  const FluentButton({
    super.key,
    required this.label,
    this.onPressed,
    this.style = FluentButtonStyle.secondary,
    this.size = FluentButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.tooltip,
    this.focusNode,
    this.autofocus = false,
  });

  const FluentButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = FluentButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.tooltip,
    this.focusNode,
    this.autofocus = false,
  }) : style = FluentButtonStyle.primary;

  const FluentButton.subtle({
    super.key,
    required this.label,
    this.onPressed,
    this.size = FluentButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.tooltip,
    this.focusNode,
    this.autofocus = false,
  }) : style = FluentButtonStyle.subtle;

  final String label;
  final VoidCallback? onPressed;
  final FluentButtonStyle style;
  final FluentButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;

  /// Shows a ring in place of the icon and disables the button.
  final bool loading;
  final bool expand;
  final String? tooltip;
  final FocusNode? focusNode;
  final bool autofocus;

  double get _height => switch (size) {
    FluentButtonSize.small => 24,
    FluentButtonSize.medium => Sizes.buttonHeight,
    FluentButtonSize.large => 40,
  };

  double get _paddingX => switch (size) {
    FluentButtonSize.small => Space.s,
    FluentButtonSize.medium => Sizes.buttonPaddingX,
    FluentButtonSize.large => Space.l,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final motion = Motion.of(context);
    final enabled = onPressed != null && !loading;
    final button = Pressable(
      onTap: enabled ? onPressed : null,
      enabled: enabled,
      focusNode: focusNode,
      autofocus: autofocus,
      showHoverFill: false,
      showPressedOverlay: false,
      semanticLabel: label,
      builder: (context, states, _) {
        final spec = _resolve(colors, states);
        final textStyle =
            (size == FluentButtonSize.small ? context.text.caption : context.text.body).copyWith(
              color: spec.foreground,
              fontWeight: FontWeight.w400,
            );
        return AnimatedContainer(
          duration: motion.fast,
          curve: Motion.standard,
          height: _height,
          padding: EdgeInsets.symmetric(horizontal: _paddingX),
          decoration: BoxDecoration(
            color: spec.background,
            borderRadius: Radii.controlRadius,
            border: spec.stroke == null ? null : Border.all(color: spec.stroke!),
            // Fluent's darker 1 px bottom edge, drawn as an offset hard shadow
            // because a rounded border must have one colour.
            boxShadow: spec.bottomStroke == null
                ? null
                : [BoxShadow(color: spec.bottomStroke!, offset: const Offset(0, 1))],
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                Padding(
                  padding: const EdgeInsets.only(right: Space.s),
                  child: ProgressRing(size: 16, strokeWidth: 2, color: spec.foreground),
                )
              else if (icon != null)
                Padding(
                  padding: const EdgeInsets.only(right: Space.s),
                  child: Icon(icon, size: Sizes.buttonIcon, color: spec.foreground),
                ),
              Flexible(
                child: Text(
                  label,
                  style: textStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              if (trailingIcon != null)
                Padding(
                  padding: const EdgeInsets.only(left: Space.s),
                  child: Icon(trailingIcon, size: 12, color: spec.foreground),
                ),
            ],
          ),
        );
      },
    );
    final sized = expand ? SizedBox(width: double.infinity, child: button) : button;
    if (tooltip == null) return sized;
    return FluentTooltip(message: tooltip!, child: sized);
  }

  _ButtonSpec _resolve(PepoColors c, PressableStates s) {
    switch (style) {
      case FluentButtonStyle.primary:
        if (!s.enabled) {
          return _ButtonSpec(
            background: c.isDark ? const Color(0x28FFFFFF) : const Color(0x37000000),
            foreground: c.isDark ? const Color(0x87FFFFFF) : const Color(0xFFFFFFFF),
          );
        }
        final bg = s.pressed ? c.accentPressed : (s.hovered ? c.accentHover : c.accent);
        return _ButtonSpec(
          background: bg,
          foreground: s.pressed ? c.onAccent.withValues(alpha: 0.8) : c.onAccent,
          stroke: c.onAccent.withValues(alpha: c.isDark ? 0.06 : 0.08),
          bottomStroke: s.pressed ? null : Colors.black.withValues(alpha: c.isDark ? 0.14 : 0.4),
        );
      case FluentButtonStyle.secondary:
        if (!s.enabled) {
          return _ButtonSpec(
            background: c.isDark ? const Color(0x0BFFFFFF) : const Color(0x7FF9F9F9),
            foreground: c.textDisabled,
            stroke: c.controlStroke,
          );
        }
        final bg = s.pressed ? c.controlPressed : (s.hovered ? c.controlHover : c.controlFill);
        return _ButtonSpec(
          background: bg,
          foreground: s.pressed ? c.textSecondary : c.textPrimary,
          stroke: c.controlStroke,
          bottomStroke: s.pressed
              ? null
              : (c.isDark ? const Color(0x18FFFFFF) : const Color(0x29000000)),
        );
      case FluentButtonStyle.subtle:
        if (!s.enabled) {
          return _ButtonSpec(background: Colors.transparent, foreground: c.textDisabled);
        }
        final bg = s.pressed ? c.subtlePressed : (s.hovered ? c.subtleHover : Colors.transparent);
        return _ButtonSpec(background: bg, foreground: s.pressed ? c.textSecondary : c.textPrimary);
    }
  }
}

class _ButtonSpec {
  const _ButtonSpec({
    required this.background,
    required this.foreground,
    this.stroke,
    this.bottomStroke,
  });

  final Color background;
  final Color foreground;
  final Color? stroke;
  final Color? bottomStroke;
}

/// Square icon-only button (32 px, subtle by default).
class FluentIconButton extends StatelessWidget {
  const FluentIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.size = 32,
    this.iconSize = Sizes.buttonIcon,
    this.color,
    this.style = FluentButtonStyle.subtle,
    this.selected = false,
    this.focusNode,
  });

  final IconData icon;

  /// Also used as the semantic label; pass an empty string for none.
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? color;
  final FluentButtonStyle style;

  /// Highlighted (toggle buttons).
  final bool selected;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final motion = Motion.of(context);
    final enabled = onPressed != null;
    final button = Pressable(
      onTap: onPressed,
      enabled: enabled,
      focusNode: focusNode,
      showHoverFill: false,
      showPressedOverlay: false,
      semanticLabel: tooltip.isEmpty ? null : tooltip,
      builder: (context, states, _) {
        Color bg;
        Color fg;
        BoxBorder? border;
        if (!states.enabled) {
          bg = Colors.transparent;
          fg = colors.textDisabled;
        } else if (style == FluentButtonStyle.primary) {
          bg = states.pressed
              ? colors.accentPressed
              : (states.hovered ? colors.accentHover : colors.accent);
          fg = colors.onAccent;
        } else if (style == FluentButtonStyle.secondary) {
          bg = states.pressed
              ? colors.controlPressed
              : (states.hovered ? colors.controlHover : colors.controlFill);
          fg = color ?? colors.textPrimary;
          border = Border.all(color: colors.controlStroke);
        } else {
          bg = states.pressed
              ? colors.subtlePressed
              : (states.hovered || selected ? colors.subtleHover : Colors.transparent);
          fg = color ?? (selected ? colors.accent : colors.textPrimary);
        }
        return AnimatedContainer(
          duration: motion.fast,
          curve: Motion.standard,
          width: size,
          height: size,
          decoration: BoxDecoration(color: bg, borderRadius: Radii.controlRadius, border: border),
          alignment: Alignment.center,
          child: Icon(icon, size: iconSize, color: fg),
        );
      },
    );
    if (tooltip.isEmpty) return button;
    return FluentTooltip(message: tooltip, child: button);
  }
}
