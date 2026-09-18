import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../shared/i18n/l10n.dart';
import '../../shared/motion/motion.dart';
import '../../shared/motion/pressable.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/device_icon.dart';

/// Flattens dropped items into file paths (folders are expanded).
List<String> dropItemPaths(Iterable<DropItem> items) {
  final out = <String>[];
  for (final item in items) {
    if (item is DropItemDirectory) {
      out.addAll(dropItemPaths(item.children));
    } else if (item.path.isNotEmpty) {
      out.add(item.path);
    }
  }
  return out;
}

/// One drop target per paired device: dashed rounded rectangle with the
/// device silhouette, its name and an "Add files…" link. While files hover
/// over it the border turns solid accent and the icon grows a little.
class DeviceDropZone extends StatefulWidget {
  const DeviceDropZone({
    super.key,
    required this.name,
    required this.kind,
    required this.connected,
    required this.onFiles,
    required this.onAddFiles,
    this.width = 264,
    this.height = 196,
  });

  final String name;
  final DeviceKind kind;
  final bool connected;

  /// Files dropped on the zone.
  final ValueChanged<List<String>> onFiles;

  /// "Add files…" link and click on the zone.
  final VoidCallback onAddFiles;
  final double width;
  final double height;

  @override
  State<DeviceDropZone> createState() => _DeviceDropZoneState();
}

class _DeviceDropZoneState extends State<DeviceDropZone> {
  bool _dragging = false;

  void _setDragging(bool value) {
    if (_dragging != value && mounted) setState(() => _dragging = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final motion = Motion.of(context);
    final t = context.t;
    final enabled = widget.connected;
    final active = _dragging && enabled;
    final fill = active ? colors.accent.withValues(alpha: 0.06) : colors.dropFill;
    final border = active ? colors.accent : colors.dropBorder;

    final zone = Pressable(
      onTap: enabled ? widget.onAddFiles : null,
      enabled: enabled,
      borderRadius: Radii.dropZoneRadius,
      showHoverFill: false,
      showPressedOverlay: false,
      scaleOnPress: false,
      semanticLabel: enabled ? t.sendToDevice(widget.name) : '${widget.name}, ${t.statusOffline}',
      builder: (context, states, _) => CustomPaint(
        foregroundPainter: _DashedBorderPainter(
          color: enabled ? border : colors.controlStroke,
          dashed: !active,
          radius: Radii.dropZone,
          strokeWidth: active ? 2 : 1.5,
        ),
        child: AnimatedContainer(
          duration: motion.fast,
          curve: Motion.standard,
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: enabled ? fill : colors.controlFill,
            borderRadius: Radii.dropZoneRadius,
          ),
          child: Opacity(
            opacity: enabled ? 1 : 0.55,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  duration: motion.normal,
                  curve: Motion.spring,
                  scale: active ? 1.06 : 1,
                  child: DeviceIcon(kind: widget.kind, size: 48, color: colors.textPrimary),
                ),
                const SizedBox(height: Space.m),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.l),
                  child: Text(
                    widget.name,
                    style: text.bodyStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: Space.xs),
                if (enabled)
                  _LinkText(
                    label: active ? t.dropHere(widget.name) : t.addFiles,
                    hovered: states.hovered,
                    onTap: widget.onAddFiles,
                  )
                else
                  Text(t.statusOffline, style: text.caption.copyWith(color: colors.textTertiary)),
              ],
            ),
          ),
        ),
      ),
    );

    return DropTarget(
      enable: enabled,
      onDragEntered: (_) => _setDragging(true),
      onDragExited: (_) => _setDragging(false),
      onDragDone: (details) {
        _setDragging(false);
        final paths = dropItemPaths(details.files);
        if (paths.isNotEmpty) widget.onFiles(paths);
      },
      child: zone,
    );
  }
}

/// Accent link inside the zone ("Add files…").
class _LinkText extends StatelessWidget {
  const _LinkText({required this.label, required this.hovered, required this.onTap});

  final String label;
  final bool hovered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    return Pressable(
      onTap: onTap,
      showHoverFill: false,
      showPressedOverlay: false,
      scaleOnPress: false,
      showFocusRing: false,
      excludeSemantics: true,
      builder: (context, states, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.xs),
        child: Text(
          label,
          style: context.text.body.copyWith(
            color: states.pressed ? colors.accentPressed : colors.accent,
            decoration: hovered || states.hovered ? TextDecoration.underline : null,
            decorationColor: colors.accent,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// 1.5 px border, dashed (6/4) or solid, on a 12 px rounded rectangle.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.dashed,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final bool dashed;
  final double radius;
  final double strokeWidth;

  static const double _dash = 6;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    if (!dashed) {
      canvas.drawRRect(rrect, paint);
      return;
    }
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var start = 0.0;
      while (start < metric.length) {
        final end = math.min(start + _dash, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
        start = end + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.dashed != dashed ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;
}
