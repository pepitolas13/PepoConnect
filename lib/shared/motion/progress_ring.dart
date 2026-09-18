import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'motion.dart';

/// Fluent progress ring: 20 px, 3 px round stroke. Determinate values tween
/// over 200 ms; without a value a 90° arc spins every 1.1 s.
class ProgressRing extends StatefulWidget {
  const ProgressRing({
    super.key,
    this.value,
    this.size = 20,
    this.strokeWidth = 3,
    this.color,
    this.trackColor,
    this.semanticLabel,
  });

  /// 0..1, or null for indeterminate.
  final double? value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final String? semanticLabel;

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSpin();
  }

  @override
  void didUpdateWidget(ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSpin();
  }

  void _syncSpin() {
    final period = Motion.of(context).d(const Duration(milliseconds: 1100));
    if (widget.value == null && period != Duration.zero) {
      if (!_spin.isAnimating) _spin.repeat(period: period);
    } else {
      _spin.stop();
      _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final color = widget.color ?? colors.accent;
    final track = widget.trackColor ?? colors.controlStroke;
    final motion = Motion.of(context);
    final value = widget.value;
    final ring = SizedBox.square(
      dimension: widget.size,
      child: value == null
          ? CustomPaint(
              painter: _RingPainter(
                progress: _spin,
                value: null,
                color: color,
                track: track,
                stroke: widget.strokeWidth,
              ),
            )
          : TweenAnimationBuilder<double>(
              tween: Tween(end: value.clamp(0, 1)),
              duration: motion.normal,
              curve: Motion.standard,
              builder: (context, v, _) => CustomPaint(
                painter: _RingPainter(
                  progress: null,
                  value: v,
                  color: color,
                  track: track,
                  stroke: widget.strokeWidth,
                ),
              ),
            ),
    );
    return Semantics(
      label: widget.semanticLabel,
      value: value == null ? null : '${(value * 100).round()} %',
      child: RepaintBoundary(child: ring),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.value,
    required this.color,
    required this.track,
    required this.stroke,
  }) : super(repaint: progress);

  final Animation<double>? progress;
  final double? value;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    paint.color = color;
    if (value != null) {
      if (value! > 0) {
        canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value!, false, paint);
      }
      return;
    }
    final t = progress?.value ?? 0;
    // A quarter arc that travels around; when motion is off it sits still.
    canvas.drawArc(rect, -math.pi / 2 + math.pi * 2 * t, math.pi / 2, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track || old.stroke != stroke;
}
