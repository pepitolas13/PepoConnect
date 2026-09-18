import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pepo_core/pepo_core.dart' show TransferRecord, TransferState;

import '../../shared/i18n/l10n.dart';
import '../../shared/motion/motion.dart';
import '../../shared/motion/pressable.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/util/format.dart';
import '../../shared/widgets/fluent_button.dart';
import '../../shared/widgets/flyout.dart';
import '../../shared/widgets/thin_progress_bar.dart';
import 'file_type_icon.dart';

bool get _touch =>
    defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

/// "8 s" / "2 min" for an ETA.
String formatEta(BuildContext context, Duration eta) {
  final t = context.t;
  if (eta.inSeconds < 60) return t.etaSeconds(eta.inSeconds.clamp(1, 59));
  return t.etaMinutes(eta.inMinutes.clamp(1, 1 << 20));
}

/// Square leading of a transfer row: a thumbnail when one is known (gallery
/// item or local image), the file-type glyph otherwise.
class TransferLeading extends StatelessWidget {
  const TransferLeading({
    super.key,
    required this.name,
    this.mime,
    this.thumbnail,
    this.localImagePath,
    this.size = 40,
  });

  final String name;
  final String? mime;
  final Uint8List? thumbnail;

  /// Local file shown as a thumbnail when it is an image and no bytes are cached.
  final String? localImagePath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (size * dpr).round();
    Widget? image;
    if (thumbnail != null) {
      image = Image.memory(
        thumbnail!,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      );
    } else if (localImagePath != null && fileFamilyOf(name, mime) == FileFamily.image) {
      final file = File(localImagePath!);
      if (file.existsSync()) {
        image = Image.file(
          file,
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => FileTypeIcon(name: name, mime: mime, size: size * 0.8),
        );
      }
    }
    return ClipRRect(
      borderRadius: Radii.controlRadius,
      child: Container(
        width: size,
        height: size,
        color: image == null ? colors.controlFill : null,
        alignment: Alignment.center,
        child: image ?? FileTypeIcon(name: name, mime: mime, size: size * 0.8),
      ),
    );
  }
}

/// Row of the "In progress" section: name, device, thin progress bar,
/// speed and ETA, pause/resume and cancel.
class ActiveTransferRow extends StatelessWidget {
  const ActiveTransferRow({
    super.key,
    required this.record,
    required this.deviceName,
    this.thumbnail,
    this.onPause,
    this.onResume,
    this.onCancel,
  });

  final TransferRecord record;
  final String deviceName;
  final Uint8List? thumbnail;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final t = context.t;
    final locale = Localizations.localeOf(context).toString();
    final r = record;
    final direction = r.isIncoming ? t.receivingFrom(deviceName) : t.sendingTo(deviceName);
    final String status;
    switch (r.state) {
      case TransferState.queued:
        status = t.transferQueued;
      case TransferState.paused:
        status = t.transferPaused;
      default:
        final eta = r.eta;
        status = r.bytesPerSecond > 0 && eta != null
            ? t.speedAndEta(
                formatBytes(r.bytesPerSecond.round(), locale: locale),
                formatEta(context, eta),
              )
            : formatPercent(r.progress);
    }
    final canPause = r.state == TransferState.active || r.state == TransferState.queued;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TransferLeading(
            name: r.name,
            mime: r.mime,
            thumbnail: thumbnail,
            localImagePath: r.sourcePath,
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r.name, style: text.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '$direction · ${formatBytes(r.size, locale: locale)}',
                  style: text.caption.copyWith(color: colors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Space.s),
                r.state == TransferState.queued
                    ? const ThinProgressBar(value: null)
                    : SmoothThinProgressBar(value: r.progress, collapseOnComplete: false),
                const SizedBox(height: Space.xs),
                Text(status, style: text.caption.copyWith(color: colors.textTertiary), maxLines: 1),
              ],
            ),
          ),
          const SizedBox(width: Space.s),
          if (onPause != null && canPause)
            FluentIconButton(
              icon: FluentIcons.pause_16_regular,
              tooltip: t.pauseTransfer,
              onPressed: onPause,
            ),
          if (onResume != null && r.state == TransferState.paused)
            FluentIconButton(
              icon: FluentIcons.play_16_regular,
              tooltip: t.resumeTransfer,
              onPressed: onResume,
            ),
          if (onCancel != null)
            FluentIconButton(
              icon: FluentIcons.dismiss_16_regular,
              tooltip: t.cancelTransfer,
              onPressed: onCancel,
            ),
        ],
      ),
    );
  }
}

/// Row of the history: leading, name, size · device · time; failed and
/// cancelled transfers say so. Open / show in folder / remove appear on
/// hover (always on touch) and in the context menu.
class HistoryTransferRow extends StatefulWidget {
  const HistoryTransferRow({
    super.key,
    required this.record,
    required this.deviceName,
    this.thumbnail,
    this.onOpen,
    this.onShowInFolder,
    this.onRemove,
    this.onTap,
    this.showDevice = true,
  });

  final TransferRecord record;
  final String deviceName;
  final Uint8List? thumbnail;
  final VoidCallback? onOpen;
  final VoidCallback? onShowInFolder;
  final VoidCallback? onRemove;

  /// Tap on the row itself (mobile: open the file).
  final VoidCallback? onTap;
  final bool showDevice;

  @override
  State<HistoryTransferRow> createState() => _HistoryTransferRowState();
}

class _HistoryTransferRowState extends State<HistoryTransferRow> {
  bool _hovered = false;

  List<MenuEntry> _menu(BuildContext context) {
    final t = context.t;
    return [
      if (widget.onOpen != null)
        MenuItem(label: t.open, icon: FluentIcons.open_16_regular, onTap: widget.onOpen),
      if (widget.onShowInFolder != null)
        MenuItem(
          label: t.showInFolder,
          icon: FluentIcons.folder_16_regular,
          onTap: widget.onShowInFolder,
        ),
      if (widget.onRemove != null) ...[
        if (widget.onOpen != null || widget.onShowInFolder != null) const MenuDivider(),
        MenuItem(
          label: t.removeFromList,
          icon: FluentIcons.dismiss_16_regular,
          onTap: widget.onRemove,
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final t = context.t;
    final motion = Motion.of(context);
    final locale = Localizations.localeOf(context).toString();
    final r = widget.record;
    final when = formatDayTime(
      r.finishedAt ?? r.createdAt,
      today: t.today,
      yesterday: t.yesterday,
      locale: locale,
    );
    final parts = [
      formatBytes(r.size, locale: locale),
      if (widget.showDevice) widget.deviceName,
      when,
    ];
    final String? problem = switch (r.state) {
      TransferState.failed => r.error ?? t.errorGeneric,
      TransferState.cancelled => t.errorCancelled,
      _ => null,
    };
    final showActions = _hovered || _touch;
    final actions = [
      if (widget.onOpen != null)
        FluentIconButton(
          icon: FluentIcons.open_16_regular,
          tooltip: t.open,
          onPressed: widget.onOpen,
        ),
      if (widget.onShowInFolder != null)
        FluentIconButton(
          icon: FluentIcons.folder_16_regular,
          tooltip: t.showInFolder,
          onPressed: widget.onShowInFolder,
        ),
      if (widget.onRemove != null)
        FluentIconButton(
          icon: FluentIcons.dismiss_16_regular,
          tooltip: t.removeFromList,
          onPressed: widget.onRemove,
        ),
    ];
    return ContextMenuRegion(
      items: _menu,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Pressable(
          onTap: widget.onTap,
          enabled: widget.onTap != null,
          scaleOnPress: false,
          showFocusRing: widget.onTap != null,
          semanticLabel: r.name,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.s),
            child: Row(
              children: [
                TransferLeading(
                  name: r.name,
                  mime: r.mime,
                  thumbnail: widget.thumbnail,
                  localImagePath: r.isIncoming ? r.finalPath : r.sourcePath,
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(r.name, style: text.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        problem == null ? parts.join(' · ') : '$problem · $when',
                        style: text.caption.copyWith(
                          color: problem == null ? colors.textSecondary : colors.critical,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: Space.s),
                  AnimatedOpacity(
                    duration: motion.fast,
                    opacity: showActions ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !showActions,
                      child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
