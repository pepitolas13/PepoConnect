import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'motion.dart';

/// Marks a freshly arrived item: it slides in from -30 % of its height
/// (260 ms) with a 2 px accent border and an accent glow that fades out
/// over [Motion.glow] (1.5 s). Plays once when [play] turns true.
class NewItemGlow extends StatefulWidget {
  const NewItemGlow({
    super.key,
    required this.child,
    this.play = true,
    this.borderRadius = Radii.controlRadius,
    this.onFinished,
  });

  final Widget child;

  /// Set to true to play (typically `entry.isNew`). Changing it back to
  /// false stops the glow immediately.
  final bool play;
  final BorderRadius borderRadius;
  final VoidCallback? onFinished;

  @override
  State<NewItemGlow> createState() => _NewItemGlowState();
}

class _NewItemGlowState extends State<NewItemGlow> with TickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(vsync: this, value: 1);
  late final AnimationController _glow = AnimationController(vsync: this, value: 0);
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _glow.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && _started) widget.onFinished?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.play && !_started) _start();
  }

  @override
  void didUpdateWidget(NewItemGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.play && !oldWidget.play) {
      _started = false;
      _start();
    } else if (!widget.play && oldWidget.play) {
      _glow.value = 0;
      _slide.value = 1;
    }
  }

  Future<void> _start() async {
    _started = true;
    final motion = Motion.of(context);
    _slide.value = 0;
    _glow.value = 1;
    final slideIn = _slide.animateTo(1, duration: motion.ms(260), curve: Motion.emphasized);
    await slideIn;
    if (!mounted) return;
    await _glow.animateTo(0, duration: motion.glow, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _slide.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    return AnimatedBuilder(
      animation: Listenable.merge([_slide, _glow]),
      builder: (context, child) {
        final g = _glow.value;
        final decorated = g == 0
            ? child!
            : DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  border: Border.all(color: colors.accent.withValues(alpha: g), width: 2),
                  boxShadow: [
                    BoxShadow(color: colors.accent.withValues(alpha: 0.35 * g), blurRadius: 16),
                  ],
                ),
                child: child,
              );
        final s = _slide.value;
        if (s == 1) return decorated;
        return FractionalTranslation(
          translation: Offset(0, -0.3 * (1 - s)),
          child: Opacity(opacity: s.clamp(0, 1), child: decorated),
        );
      },
      child: widget.child,
    );
  }
}
