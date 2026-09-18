import 'package:flutter/widgets.dart';

import 'motion.dart';

/// Provides the [Motion] tokens to the subtree. Place it once, above the
/// router, with `enabled: settings.animations`; the platform's
/// `disableAnimations` accessibility flag is honoured on top of that.
class MotionScope extends StatelessWidget {
  const MotionScope({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  /// Motion in scope, or a sensible default outside one.
  static Motion of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_MotionInherited>();
    if (scope != null) return scope.motion;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return reduce ? const Motion.off() : const Motion.on();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final motion = enabled && !reduce ? const Motion.on() : const Motion.off();
    return _MotionInherited(motion: motion, child: child);
  }
}

class _MotionInherited extends InheritedWidget {
  const _MotionInherited({required this.motion, required super.child});

  final Motion motion;

  @override
  bool updateShouldNotify(_MotionInherited oldWidget) => oldWidget.motion != motion;
}
