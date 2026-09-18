import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/tokens.dart';

/// Unread counter: accent circle, 16 px, "99+" cap. Scales in when it
/// appears and disappears when [count] is 0.
class PepoBadge extends StatelessWidget {
  const PepoBadge({super.key, required this.count, this.dot = false});

  final int count;

  /// Show a 8 px dot without a number.
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final motion = Motion.of(context);
    final visible = count > 0;
    final label = count > 99 ? '99+' : '$count';
    return AnimatedScale(
      duration: motion.normal,
      curve: Motion.spring,
      scale: visible ? 1 : 0,
      child: AnimatedOpacity(
        duration: motion.fast,
        opacity: visible ? 1 : 0,
        child: dot
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
              )
            : Container(
                constraints: const BoxConstraints(minWidth: 16),
                height: 16,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: colors.onAccent,
                    fontFamily: context.text.caption.fontFamily,
                    fontFamilyFallback: context.text.caption.fontFamilyFallback,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Places a [PepoBadge] on the top-right corner of [child].
class Badged extends StatelessWidget {
  const Badged({
    super.key,
    required this.count,
    required this.child,
    this.offset = const Offset(6, -4),
  });

  final int count;
  final Widget child;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -offset.dx,
          top: offset.dy,
          child: IgnorePointer(child: PepoBadge(count: count)),
        ),
      ],
    );
  }
}
