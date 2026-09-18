import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'motion.dart';

/// Interaction state exposed to [Pressable.builder].
@immutable
class PressableStates {
  const PressableStates({
    this.hovered = false,
    this.pressed = false,
    this.focused = false,
    this.enabled = true,
  });

  final bool hovered;
  final bool pressed;

  /// True only for keyboard focus (the focus ring is visible).
  final bool focused;
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is PressableStates &&
      other.hovered == hovered &&
      other.pressed == pressed &&
      other.focused == focused &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(hovered, pressed, focused, enabled);
}

typedef PressableBuilder = Widget Function(
  BuildContext context,
  PressableStates states,
  Widget? child,
);

typedef PositionCallback = void Function(Offset globalPosition);

/// Whether the last input came from the keyboard. Desktop platforms report
/// the "traditional" focus highlight mode from the start, so without this the
/// first item of a menu opened with the mouse would show a focus ring.
class InputModality {
  InputModality._();

  static final ValueNotifier<bool> keyboard = ValueNotifier<bool>(false);
  static int _clients = 0;

  static bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent) keyboard.value = true;
    return false;
  }

  static void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent) keyboard.value = false;
  }

  /// Installs the global listeners for the first client (reference counted
  /// so tests, which reset the bindings, always start clean).
  static void attach() {
    if (_clients++ > 0) return;
    keyboard.value = false;
    HardwareKeyboard.instance.addHandler(_onKey);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  static void detach() {
    if (--_clients > 0) return;
    HardwareKeyboard.instance.removeHandler(_onKey);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
  }
}

/// The single micro-interaction primitive. Every clickable surface in the app
/// goes through it: press scale (1 → 0.97, spring back), hover fill, optional
/// pointer-following light, keyboard activation, focus ring, haptics on
/// mobile and button semantics.
///
/// With motion off the durations are zero and [Motion.pressScale] is 1, so
/// the colour feedback still switches instantly while nothing moves.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onDoubleTap,
    this.borderRadius = Radii.controlRadius,
    this.hoverLight = false,
    this.showHoverFill = true,
    this.showPressedOverlay = true,
    this.scaleOnPress = true,
    this.showFocusRing = true,
    this.hoverColor,
    this.pressedColor,
    this.enabled,
    this.semanticLabel,
    this.excludeSemantics = false,
    this.focusNode,
    this.autofocus = false,
    this.cursor,
    this.behavior = HitTestBehavior.opaque,
    this.builder,
    this.child,
  }) : assert(child != null || builder != null, 'Pass a child or a builder');

  final VoidCallback? onTap;

  /// Long press (touch) — receives the global position for context menus.
  final PositionCallback? onLongPress;

  /// Right click — receives the global position for context menus.
  final PositionCallback? onSecondaryTap;
  final VoidCallback? onDoubleTap;
  final BorderRadius borderRadius;

  /// Radial light that follows the pointer (tiles and cards).
  final bool hoverLight;

  /// Paint the subtle hover fill behind the child.
  final bool showHoverFill;

  /// Paint the pressed overlay while held.
  final bool showPressedOverlay;
  final bool scaleOnPress;
  final bool showFocusRing;
  final Color? hoverColor;
  final Color? pressedColor;

  /// Defaults to "has any callback".
  final bool? enabled;
  final String? semanticLabel;
  final bool excludeSemantics;
  final FocusNode? focusNode;
  final bool autofocus;
  final MouseCursor? cursor;
  final HitTestBehavior behavior;
  final PressableBuilder? builder;
  final Widget? child;

  bool get _hasCallbacks =>
      onTap != null || onLongPress != null || onSecondaryTap != null || onDoubleTap != null;

  bool get isEnabled => enabled ?? _hasCallbacks;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with TickerProviderStateMixin {
  late final AnimationController _scale = AnimationController(
    vsync: this,
    lowerBound: -0.25,
    upperBound: 1,
    value: 0,
  );
  late final AnimationController _hover = AnimationController(vsync: this, value: 0);
  late final AnimationController _press = AnimationController(vsync: this, value: 0);
  final ValueNotifier<Offset?> _pointer = ValueNotifier<Offset?>(null);

  bool _hovered = false;
  bool _pressed = false;
  bool _focusVisible = false;
  int _pointersDown = 0;

  // Cached in didChangeDependencies: gesture callbacks may fire while the
  // element is already deactivated (a cancelled tap during teardown).
  Motion _motion = const Motion.on();

  @override
  void initState() {
    super.initState();
    InputModality.attach();
    InputModality.keyboard.addListener(_onModality);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion = Motion.of(context);
  }

  void _onModality() {
    // Only nodes that hold focus need to redraw their ring.
    if (_focusVisible && mounted) setState(() {});
  }

  @override
  void dispose() {
    InputModality.keyboard.removeListener(_onModality);
    InputModality.detach();
    _scale.dispose();
    _hover.dispose();
    _press.dispose();
    _pointer.dispose();
    super.dispose();
  }

  void _setHovered(bool value) {
    if (_hovered == value || !mounted) return;
    _hovered = value;
    if (!value) _pointer.value = null;
    _hover.animateTo(value ? 1 : 0, duration: _motion.fast, curve: Motion.standard);
    setState(() {});
  }

  void _down({bool haptic = true}) {
    if (_pressed || !mounted) return;
    _pressed = true;
    if (haptic && _isTouchPlatform) HapticFeedback.selectionClick();
    _press.animateTo(1, duration: _motion.fast, curve: Motion.standard);
    if (widget.scaleOnPress) {
      _scale.animateTo(1, duration: _motion.ms(120), curve: Motion.standard);
    }
    setState(() {});
  }

  void _up() {
    if (!_pressed || !mounted) return;
    _pressed = false;
    _press.animateTo(0, duration: _motion.fast, curve: Motion.standard);
    if (widget.scaleOnPress) {
      _scale.animateTo(0, duration: _motion.ms(250), curve: Motion.spring);
    }
    setState(() {});
  }

  bool get _isTouchPlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _activateFromKeyboard() async {
    if (!widget.isEnabled || widget.onTap == null) return;
    _down(haptic: false);
    await Future<void>.delayed(_motion.ms(90));
    if (!mounted) return;
    _up();
    widget.onTap?.call();
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointersDown++;
    if (event.buttons == kPrimaryButton || event.kind == PointerDeviceKind.touch) _down();
  }

  void _onPointerUpOrCancel(PointerEvent event) {
    _pointersDown = (_pointersDown - 1).clamp(0, 1 << 16);
    if (_pointersDown == 0) _up();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final motion = _motion;
    final enabled = widget.isEnabled;
    final states = PressableStates(
      hovered: enabled && _hovered,
      pressed: enabled && _pressed,
      focused: enabled && _focusVisible && InputModality.keyboard.value,
      enabled: enabled,
    );
    final content = widget.builder != null
        ? widget.builder!(context, states, widget.child)
        : widget.child!;

    final painted = CustomPaint(
      painter: _BackgroundPainter(
        hover: _hover,
        press: _press,
        hoverColor: widget.showHoverFill ? (widget.hoverColor ?? colors.subtleHover) : null,
        pressedColor: widget.showPressedOverlay
            ? (widget.pressedColor ?? colors.pressedOverlay)
            : null,
        radius: widget.borderRadius,
      ),
      foregroundPainter: _ForegroundPainter(
        pointer: _pointer,
        hover: _hover,
        lightColor: widget.hoverLight && motion.hoverLight ? colors.hoverLight : null,
        radius: widget.borderRadius,
        focusVisible: widget.showFocusRing && states.focused,
        focusOuter: colors.focusOuter,
        focusInner: colors.focusInner,
      ),
      child: content,
    );

    final scaled = widget.scaleOnPress
        ? AnimatedBuilder(
            animation: _scale,
            builder: (context, child) {
              final v = _scale.value;
              final scale = 1 - (1 - motion.pressScale) * v;
              return Transform.scale(
                scale: scale,
                filterQuality: v == 0 ? null : FilterQuality.low,
                child: child,
              );
            },
            child: painted,
          )
        : painted;

    final cursor = widget.cursor ?? (enabled ? SystemMouseCursors.click : SystemMouseCursors.basic);

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      excludeSemantics: widget.excludeSemantics,
      onTap: enabled ? widget.onTap : null,
      onLongPress: enabled && widget.onLongPress != null
          ? () => widget.onLongPress!(Offset.zero)
          : null,
      child: FocusableActionDetector(
        enabled: enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        mouseCursor: cursor,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activateFromKeyboard();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) {
              _activateFromKeyboard();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (v) {
          if (_focusVisible != v) setState(() => _focusVisible = v);
        },
        // Hover is tracked here rather than through onShowHoverHighlight so a
        // mouse gets feedback even while the focus highlight mode is "touch".
        child: MouseRegion(
          onEnter: enabled ? (_) => _setHovered(true) : null,
          onExit: enabled ? (_) => _setHovered(false) : null,
          onHover: widget.hoverLight ? (e) => _pointer.value = e.localPosition : null,
          opaque: false,
          child: Listener(
            onPointerDown: enabled ? _onPointerDown : null,
            onPointerUp: enabled ? _onPointerUpOrCancel : null,
            onPointerCancel: enabled ? _onPointerUpOrCancel : null,
            behavior: widget.behavior,
            child: GestureDetector(
              behavior: widget.behavior,
              onTap: enabled ? widget.onTap : null,
              onTapCancel: enabled ? _up : null,
              onDoubleTap: enabled ? widget.onDoubleTap : null,
              onLongPressStart: enabled && widget.onLongPress != null
                  ? (d) => widget.onLongPress!(d.globalPosition)
                  : null,
              onSecondaryTapUp: enabled && widget.onSecondaryTap != null
                  ? (d) => widget.onSecondaryTap!(d.globalPosition)
                  : null,
              child: scaled,
            ),
          ),
        ),
      ),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter({
    required this.hover,
    required this.press,
    required this.hoverColor,
    required this.pressedColor,
    required this.radius,
  }) : super(repaint: Listenable.merge([hover, press]));

  final Animation<double> hover;
  final Animation<double> press;
  final Color? hoverColor;
  final Color? pressedColor;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = radius.toRRect(Offset.zero & size);
    final h = hover.value;
    final p = press.value;
    if (hoverColor != null && h > 0) {
      canvas.drawRRect(rrect, Paint()..color = hoverColor!.withValues(alpha: hoverColor!.a * h));
    }
    if (pressedColor != null && p > 0) {
      canvas.drawRRect(
        rrect,
        Paint()..color = pressedColor!.withValues(alpha: pressedColor!.a * p),
      );
    }
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) =>
      old.hoverColor != hoverColor || old.pressedColor != pressedColor || old.radius != radius;
}

class _ForegroundPainter extends CustomPainter {
  _ForegroundPainter({
    required this.pointer,
    required this.hover,
    required this.lightColor,
    required this.radius,
    required this.focusVisible,
    required this.focusOuter,
    required this.focusInner,
  }) : super(repaint: Listenable.merge([pointer, hover]));

  final ValueListenable<Offset?> pointer;
  final Animation<double> hover;
  final Color? lightColor;
  final BorderRadius radius;
  final bool focusVisible;
  final Color focusOuter;
  final Color focusInner;

  static const double lightRadius = 120;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect);
    final p = pointer.value;
    if (lightColor != null && p != null && hover.value > 0) {
      canvas.save();
      canvas.clipRRect(rrect);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            lightColor!.withValues(alpha: lightColor!.a * hover.value),
            lightColor!.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: p, radius: lightRadius));
      canvas.drawCircle(p, lightRadius, paint);
      canvas.restore();
    }
    if (focusVisible) {
      final outer = rrect.inflate(2);
      canvas.drawRRect(
        outer.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = focusOuter,
      );
      canvas.drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = focusInner,
      );
    }
  }

  @override
  bool shouldRepaint(_ForegroundPainter old) =>
      old.lightColor != lightColor ||
      old.radius != radius ||
      old.focusVisible != focusVisible ||
      old.focusOuter != focusOuter ||
      old.focusInner != focusInner;
}
