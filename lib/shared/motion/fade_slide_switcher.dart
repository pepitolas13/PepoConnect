import 'package:flutter/widgets.dart';

import 'motion.dart';

/// Dissolves between two pieces of content: the new child fades in on top
/// while rising [slide] px (ease-out, 180 ms); the old one stays put
/// underneath and dims linearly over the same 180 ms, so the background
/// never shows bare between the two (under 11 % shows through, briefly) and
/// the old content is a short tail rather than a double exposure.
///
/// Give each child a distinct [Key] (or pass [childKey]) so the switcher
/// knows when the content actually changed.
class FadeSlideSwitcher extends StatelessWidget {
  const FadeSlideSwitcher({
    super.key,
    required this.child,
    this.childKey,
    this.alignment = Alignment.topLeft,
    this.slide = 8,
  });

  final Widget child;
  final Key? childKey;
  final AlignmentGeometry alignment;
  final double slide;

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    final keyed = childKey == null ? child : KeyedSubtree(key: childKey, child: child);
    return AnimatedSwitcher(
      duration: motion.page,
      reverseDuration: motion.page,
      switchInCurve: Motion.standard,
      // The outgoing child's controller runs 1 → 0: its opacity is 1 - t.
      switchOutCurve: Curves.linear,
      layoutBuilder: (current, previous) =>
          Stack(alignment: alignment, children: [...previous, ?current]),
      transitionBuilder: (child, animation) => fadeSlide(animation, slide, child),
      child: keyed,
    );
  }
}

/// Fade with the rise of an entering child. A child on its way out (its
/// animation running in reverse) fades in place, so the two never cross.
Widget fadeSlide(Animation<double> animation, double slide, Widget child) => FadeTransition(
  opacity: animation,
  child: AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final leaving = animation.status == AnimationStatus.reverse;
      return Transform.translate(
        offset: leaving ? Offset.zero : Offset(0, slide * (1 - animation.value)),
        child: child,
      );
    },
    child: child,
  ),
);
