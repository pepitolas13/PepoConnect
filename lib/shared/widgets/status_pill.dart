import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../motion/progress_ring.dart';
import '../theme/tokens.dart';

enum ConnectionStatus { connected, connecting, offline }

/// "Conectado" (green) / "Conectando…" (ring) / "Sin conexión" (grey).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, required this.label, this.compact = false});

  final ConnectionStatus status;

  /// Localized label for the current status.
  final String label;

  /// Dot only, no text.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final motion = Motion.of(context);
    final tint = switch (status) {
      ConnectionStatus.connected => colors.success,
      ConnectionStatus.connecting => colors.accent,
      ConnectionStatus.offline => colors.textTertiary,
    };
    final dot = status == ConnectionStatus.connecting
        ? ProgressRing(size: 10, strokeWidth: 2, color: tint, trackColor: Colors.transparent)
        : AnimatedContainer(
            duration: motion.normal,
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          );
    if (compact) return Semantics(label: label, child: dot);
    return Semantics(
      label: label,
      child: AnimatedContainer(
        duration: motion.normal,
        curve: Motion.standard,
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: Space.s),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot,
            const SizedBox(width: 6),
            Text(
              label,
              style: context.text.caption.copyWith(color: tint, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
