import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'motion.dart';

/// Placeholder block with a 1.4 s sweep. Nothing is shown during the first
/// 150 ms so quick loads never flash a skeleton.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = Radii.controlRadius,
    this.delay = const Duration(milliseconds: 150),
    this.child,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;
  final Duration delay;

  /// Optional content used only for sizing (rendered invisible).
  final Widget? child;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(vsync: this);
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _visible = true;
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final period = Motion.of(context).d(const Duration(milliseconds: 1400));
    if (period == Duration.zero) {
      _sweep.stop();
      _sweep.value = 0;
    } else if (!_sweep.isAnimating) {
      _sweep.repeat(period: period);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final box = SizedBox(
      width: widget.width,
      height: widget.child == null ? widget.height : null,
      child: widget.child == null ? null : Opacity(opacity: 0, child: widget.child),
    );
    if (!_visible) return box;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SweepPainter(
          progress: _sweep,
          base: colors.subtleHover,
          highlight: colors.isDark ? const Color(0x14FFFFFF) : const Color(0x66FFFFFF),
          radius: widget.borderRadius,
        ),
        child: box,
      ),
    );
  }
}

class _SweepPainter extends CustomPainter {
  _SweepPainter({
    required this.progress,
    required this.base,
    required this.highlight,
    required this.radius,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color base;
  final Color highlight;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect);
    canvas.drawRRect(rrect, Paint()..color = base);
    if (!progress.isAnimating && progress.value == 0) return;
    final t = progress.value;
    final x = -size.width * 0.6 + (size.width * 2.2) * t;
    final band = size.width * 0.6;
    canvas.save();
    canvas.clipRRect(rrect);
    final shader = LinearGradient(
      colors: [highlight.withValues(alpha: 0), highlight, highlight.withValues(alpha: 0)],
    ).createShader(Rect.fromLTWH(x, 0, band, size.height));
    canvas.drawRect(Rect.fromLTWH(x, 0, band, size.height), Paint()..shader = shader);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SweepPainter old) =>
      old.base != base || old.highlight != highlight || old.radius != radius;
}
