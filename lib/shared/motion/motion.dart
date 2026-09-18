import 'package:flutter/widgets.dart';

import 'motion_scope.dart';

/// Motion tokens. Widgets never branch on "are animations on": they take the
/// durations from here, and when motion is off every duration is zero so
/// controllers jump straight to their end state.
@immutable
class Motion {
  const Motion._({
    required this.enabled,
    required this.fast,
    required this.normal,
    required this.slow,
    required this.page,
    required this.glow,
    required this.pressScale,
    required this.hoverLight,
  });

  /// Full motion.
  const Motion.on()
    : this._(
        enabled: true,
        fast: const Duration(milliseconds: 100),
        normal: const Duration(milliseconds: 200),
        slow: const Duration(milliseconds: 300),
        page: const Duration(milliseconds: 180),
        glow: const Duration(milliseconds: 1500),
        pressScale: 0.97,
        hoverLight: true,
      );

  /// No motion: every duration is zero and geometry never moves. Colour
  /// feedback still switches instantly.
  const Motion.off()
    : this._(
        enabled: false,
        fast: Duration.zero,
        normal: Duration.zero,
        slow: Duration.zero,
        page: Duration.zero,
        glow: Duration.zero,
        pressScale: 1.0,
        hoverLight: false,
      );

  final bool enabled;

  /// 100 ms: hover and colour changes.
  final Duration fast;

  /// 200 ms: most state changes.
  final Duration normal;

  /// 300 ms: larger layout moves.
  final Duration slow;

  /// 180 ms: page and section changes.
  final Duration page;

  /// 1500 ms: "new item" glow fade.
  final Duration glow;

  /// Scale applied while a [Pressable] is held (1.0 when motion is off).
  final double pressScale;

  /// Whether tiles show the pointer-following light.
  final bool hoverLight;

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve exit = Curves.easeInCubic;
  static const Curve spring = Cubic(0.22, 1.2, 0.36, 1.0);

  /// Any custom duration, collapsed to zero when motion is off.
  Duration d(Duration value) => enabled ? value : Duration.zero;

  /// Milliseconds helper: `motion.ms(260)`.
  Duration ms(int milliseconds) => d(Duration(milliseconds: milliseconds));

  /// The motion in scope. Falls back to [Motion.on] (or [Motion.off] when the
  /// platform asks to disable animations) outside a [MotionScope].
  static Motion of(BuildContext context) => MotionScope.of(context);

  @override
  bool operator ==(Object other) => other is Motion && other.enabled == enabled;

  @override
  int get hashCode => enabled.hashCode;

  @override
  String toString() => 'Motion(${enabled ? 'on' : 'off'})';
}
