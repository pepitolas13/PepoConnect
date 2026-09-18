import 'package:flutter/widgets.dart';

import 'motion.dart';

/// Cross-fades between sections: the new child fades in while sliding up
/// 8 px (180 ms), the old one fades out quickly (90 ms).
///
/// Give each child a distinct [Key] (or pass [childKey]) so the switcher
/// knows when the content actually changed. Use [FadeSlideSwitcher.entrance]
/// when the child must stay a single instance (e.g. a navigation shell with
/// global keys): it replays the entrance whenever [trigger] changes and
/// never keeps the previous child around.
class FadeSlideSwitcher extends StatelessWidget {
  const FadeSlideSwitcher({
    super.key,
    required this.child,
    this.childKey,
    this.alignment = Alignment.topLeft,
    this.slide = 8,
  }) : trigger = null;

  const FadeSlideSwitcher.entrance({
    super.key,
    required Object this.trigger,
    required this.child,
    this.slide = 8,
  }) : childKey = null,
       alignment = Alignment.topLeft;

  final Widget child;
  final Key? childKey;
  final AlignmentGeometry alignment;
  final double slide;
  final Object? trigger;

  @override
  Widget build(BuildContext context) {
    if (trigger != null) {
      return _Entrance(trigger: trigger!, slide: slide, child: child);
    }
    final motion = Motion.of(context);
    final keyed = childKey == null ? child : KeyedSubtree(key: childKey, child: child);
    return AnimatedSwitcher(
      duration: motion.page,
      reverseDuration: motion.d(const Duration(milliseconds: 90)),
      switchInCurve: Motion.standard,
      switchOutCurve: Motion.exit,
      layoutBuilder: (current, previous) =>
          Stack(alignment: alignment, children: [...previous, ?current]),
      transitionBuilder: (child, animation) => _fadeSlide(animation, slide, child),
      child: keyed,
    );
  }
}

Widget _fadeSlide(Animation<double> animation, double slide, Widget child) => FadeTransition(
  opacity: animation,
  child: AnimatedBuilder(
    animation: animation,
    builder: (context, child) =>
        Transform.translate(offset: Offset(0, slide * (1 - animation.value)), child: child),
    child: child,
  ),
);

class _Entrance extends StatefulWidget {
  const _Entrance({required this.trigger, required this.slide, required this.child});

  final Object trigger;
  final double slide;
  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, value: 1);

  @override
  void didUpdateWidget(_Entrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      final motion = Motion.of(context);
      _controller.value = 0;
      _controller.animateTo(1, duration: motion.page, curve: Motion.standard);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _fadeSlide(_controller, widget.slide, widget.child);
}
