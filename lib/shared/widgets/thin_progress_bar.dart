import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/tokens.dart';

/// 4 px accent bar. When [value] reaches 1 it turns green and, after a
/// short pause, collapses to zero height (unless [collapseOnComplete] is
/// false). Null [value] shows an indeterminate sweep.
class ThinProgressBar extends StatefulWidget {
  const ThinProgressBar({
    super.key,
    required this.value,
    this.height = Sizes.progressBar,
    this.collapseOnComplete = true,
    this.color,
    this.trackColor,
    this.onCollapsed,
  });

  final double? value;
  final double height;
  final bool collapseOnComplete;
  final Color? color;
  final Color? trackColor;
  final VoidCallback? onCollapsed;

  @override
  State<ThinProgressBar> createState() => _ThinProgressBarState();
}

class _ThinProgressBarState extends State<ThinProgressBar> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(vsync: this);
  bool _collapsed = false;

  bool get _complete => widget.value != null && widget.value! >= 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSweep();
    _maybeCollapse();
  }

  @override
  void didUpdateWidget(ThinProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSweep();
    if (!_complete) _collapsed = false;
    _maybeCollapse();
  }

  void _syncSweep() {
    final period = Motion.of(context).d(const Duration(milliseconds: 1500));
    if (widget.value == null && period != Duration.zero) {
      if (!_sweep.isAnimating) _sweep.repeat(period: period);
    } else {
      _sweep.stop();
      _sweep.value = 0;
    }
  }

  Future<void> _maybeCollapse() async {
    if (!_complete || !widget.collapseOnComplete || _collapsed) return;
    final pause = Motion.of(context).d(const Duration(milliseconds: 600));
    if (pause == Duration.zero) {
      // Called from didChangeDependencies/didUpdateWidget: a build follows.
      _collapsed = true;
      return;
    }
    await Future<void>.delayed(pause);
    if (!mounted || !_complete || _collapsed) return;
    setState(() => _collapsed = true);
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final motion = Motion.of(context);
    final color = _complete ? colors.success : (widget.color ?? colors.accent);
    final track = widget.trackColor ?? colors.controlStroke;
    return AnimatedContainer(
      duration: motion.normal,
      curve: Motion.standard,
      height: _collapsed ? 0 : widget.height,
      onEnd: () {
        if (_collapsed && mounted) widget.onCollapsed?.call();
      },
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(widget.height / 2)),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _BarPainter(
            value: widget.value?.clamp(0, 1),
            sweep: _sweep,
            color: color,
            track: track,
            duration: motion.normal,
          ),
          child: const SizedBox(width: double.infinity),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.value,
    required this.sweep,
    required this.color,
    required this.track,
    required this.duration,
  }) : super(repaint: sweep);

  final double? value;
  final Animation<double> sweep;
  final Color color;
  final Color track;
  final Duration duration;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, r), Paint()..color = track);
    final paint = Paint()..color = color;
    if (value != null) {
      final w = size.width * value!;
      if (w > 0) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, size.height), r), paint);
      }
      return;
    }
    final t = sweep.value;
    final band = size.width * 0.3;
    final x = -band + (size.width + band) * t;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 0, band, size.height), r), paint);
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

/// Animates [ThinProgressBar] between values (200 ms) so progress ticks
/// read as one continuous motion.
class SmoothThinProgressBar extends StatelessWidget {
  const SmoothThinProgressBar({
    super.key,
    required this.value,
    this.height = Sizes.progressBar,
    this.collapseOnComplete = true,
    this.onCollapsed,
  });

  final double value;
  final double height;
  final bool collapseOnComplete;
  final VoidCallback? onCollapsed;

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0, 1)),
      duration: motion.normal,
      curve: Motion.standard,
      builder: (context, v, _) => ThinProgressBar(
        value: v,
        height: height,
        collapseOnComplete: collapseOnComplete,
        onCollapsed: onCollapsed,
      ),
    );
  }
}
