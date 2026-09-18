import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../shared/i18n/l10n.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/util/format.dart';

/// "Expires in 1:52", ticking once a second. Calls [onExpired] once when the
/// invitation runs out so the caller can show a fresh one.
class InviteCountdown extends StatefulWidget {
  const InviteCountdown({super.key, required this.expiresAt, this.onExpired});

  final DateTime? expiresAt;
  final VoidCallback? onExpired;

  @override
  State<InviteCountdown> createState() => _InviteCountdownState();
}

class _InviteCountdownState extends State<InviteCountdown> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _notified = false;

  /// Beyond this gap between the ticked value and the wall clock (a sleep,
  /// a long stall) the wall clock wins.
  static const Duration _driftTolerance = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(InviteCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) {
      _notified = false;
      _sync();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Anchors the count on the wall clock and starts ticking. Runs inside
  /// the widget lifecycle, so an already expired value is reported after
  /// the frame rather than synchronously.
  void _sync() {
    _timer?.cancel();
    _timer = null;
    final at = widget.expiresAt;
    if (at == null) {
      _remaining = Duration.zero;
      return;
    }
    _remaining = at.difference(DateTime.now());
    if (_remaining <= Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _expire();
      });
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final at = widget.expiresAt;
    if (at == null || !mounted) return;
    // Ticks drive the display so it never skips a second; the wall clock
    // only steps in after a big drift.
    var remaining = _remaining - const Duration(seconds: 1);
    final wall = at.difference(DateTime.now());
    if ((wall - remaining).abs() > _driftTolerance) remaining = wall;
    setState(() => _remaining = remaining);
    if (remaining <= Duration.zero) {
      _timer?.cancel();
      _timer = null;
      _expire();
    }
  }

  void _expire() {
    if (_notified) return;
    _notified = true;
    widget.onExpired?.call();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = context.pepo;
    final text = context.text;
    if (widget.expiresAt == null) return const SizedBox.shrink();
    // Round up so a fresh two-minute invitation reads 2:00, not 1:59.
    final seconds = (_remaining.inMilliseconds / 1000).ceil();
    final expired = seconds <= 0;
    final label = expired
        ? t.pairExpired
        : t.pairExpiresInTime(formatDuration(Duration(seconds: seconds)));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          FluentIcons.history_24_regular,
          size: 16,
          color: expired ? colors.caution : colors.textSecondary,
        ),
        const SizedBox(width: Space.xs),
        Text(
          label,
          style: text.caption.copyWith(color: expired ? colors.caution : colors.textSecondary),
        ),
      ],
    );
  }
}
