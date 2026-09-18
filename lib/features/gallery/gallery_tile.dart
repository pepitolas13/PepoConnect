import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../shared/i18n/l10n.dart';
import '../../shared/motion/motion.dart';
import '../../shared/motion/new_item_glow.dart';
import '../../shared/motion/pressable.dart';
import '../../shared/motion/skeleton.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/util/format.dart';
import '../../shared/widgets/fluent_tooltip.dart';
import '../../shared/widgets/pepo_checkbox.dart';
import '../../state/engine_providers.dart';
import 'gallery_grouping.dart';
import 'thumbnail_lookup.dart';

bool get _touch =>
    defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

/// One thumbnail of the grid. Paints the cached bytes at once, otherwise a
/// skeleton until `loadThumbnail` completes. Shows the "new" badge, the
/// "on the PC" mark, the video length, the circular check box (on hover, or
/// always on touch) and the selection overlay; new arrivals glow.
class GalleryTile extends StatefulWidget {
  const GalleryTile({
    super.key,
    required this.entry,
    required this.extent,
    required this.square,
    required this.selected,
    required this.selecting,
    required this.glow,
    required this.lookup,
    required this.loadThumbnail,
    required this.onTap,
    required this.onOpen,
    required this.onToggle,
    required this.onContextMenu,
    this.onGlowFinished,
  });

  final GalleryEntry entry;

  /// Maximum cell width, used to size the decoded bitmap.
  final double extent;

  /// Crop to a square (true) or letterbox the whole picture (false).
  final bool square;
  final bool selected;

  /// A selection exists somewhere in the grid: show every check box.
  final bool selecting;

  /// Play the new-item glow once.
  final bool glow;
  final ThumbnailLookup lookup;
  final Future<Uint8List?> Function(GalleryEntry entry) loadThumbnail;

  /// Single tap or click.
  final VoidCallback onTap;

  /// Double click (desktop).
  final VoidCallback onOpen;

  /// The check box.
  final VoidCallback onToggle;

  /// Right click or long press, with the global position.
  final PositionCallback onContextMenu;
  final VoidCallback? onGlowFinished;

  static String heroTag(GalleryEntry e) => 'media:${e.deviceId}/${e.id}';

  /// Two taps closer than this open the item.
  static const Duration doubleTapWindow = Duration(milliseconds: 350);

  @override
  State<GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends State<GalleryTile> {
  Uint8List? _bytes;
  Future<Uint8List?>? _future;
  String? _loadedKey;
  DateTime? _lastTap;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(GalleryTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (galleryEntryKey(oldWidget.entry) != galleryEntryKey(widget.entry)) {
      _bytes = null;
      _future = null;
      _load();
    }
  }

  void _load() {
    final key = galleryEntryKey(widget.entry);
    if (_loadedKey == key && (_bytes != null || _future != null)) return;
    _loadedKey = key;
    _bytes = widget.lookup(widget.entry.deviceId, widget.entry.id);
    _future = _bytes == null ? widget.loadThumbnail(widget.entry) : null;
  }

  void _handleTap() {
    if (_touch) {
      widget.onTap();
      return;
    }
    final now = DateTime.now();
    final last = _lastTap;
    _lastTap = now;
    if (last != null && now.difference(last) < GalleryTile.doubleTapWindow) {
      _lastTap = null;
      widget.onOpen();
      return;
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final motion = Motion.of(context);
    final t = context.t;
    final e = widget.entry;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (widget.extent * dpr).round();
    final fit = widget.square ? BoxFit.cover : BoxFit.contain;

    Widget image(Uint8List bytes) => Image.memory(
      bytes,
      fit: fit,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => _Fallback(video: e.item.isVideo),
    );

    final Widget thumb;
    final bytes = _bytes;
    if (bytes != null) {
      thumb = image(bytes);
    } else {
      thumb = FutureBuilder<Uint8List?>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data != null) return image(data);
          if (snapshot.connectionState == ConnectionState.done) {
            return _Fallback(video: e.item.isVideo);
          }
          return const Skeleton(
            width: double.infinity,
            height: double.infinity,
            borderRadius: Radii.controlRadius,
          );
        },
      );
    }

    final durationMs = e.item.durationMs;
    final duration = e.item.isVideo && durationMs != null
        ? formatDuration(Duration(milliseconds: durationMs))
        : null;

    return RepaintBoundary(
      child: NewItemGlow(
        play: widget.glow,
        borderRadius: Radii.controlRadius,
        onFinished: widget.onGlowFinished,
        child: Pressable(
          onTap: _handleTap,
          onSecondaryTap: widget.onContextMenu,
          onLongPress: _touch ? widget.onContextMenu : null,
          borderRadius: Radii.controlRadius,
          showHoverFill: false,
          showPressedOverlay: false,
          scaleOnPress: false,
          semanticLabel: e.item.name,
          builder: (context, states, _) {
            final showCheck = _touch || widget.selected || widget.selecting || states.hovered;
            return ClipRRect(
              borderRadius: Radii.controlRadius,
              child: ColoredBox(
                color: colors.controlFill,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(tag: GalleryTile.heroTag(e), child: thumb),
                    if (widget.selected)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.accent.withValues(alpha: 0.2),
                              border: Border.all(color: colors.accent, width: 2),
                              borderRadius: Radii.controlRadius,
                            ),
                          ),
                        ),
                      ),
                    if (e.isNew) Positioned(top: 6, left: 6, child: _NewBadge(label: t.newLabel)),
                    if (duration != null)
                      Positioned(bottom: 6, left: 6, child: _DurationPill(label: duration)),
                    if (e.isDownloaded)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: FluentTooltip(message: t.onPc, child: const _OnPcMark()),
                      ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: AnimatedOpacity(
                        duration: motion.fast,
                        opacity: showCheck ? 1 : 0,
                        child: IgnorePointer(
                          ignoring: !showCheck,
                          child: PepoCheckbox.circle(
                            value: widget.selected,
                            onChanged: (_) => widget.onToggle(),
                            semanticLabel: t.select,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Shown when there is no thumbnail to paint.
class _Fallback extends StatelessWidget {
  const _Fallback({required this.video});

  final bool video;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        video ? FluentIcons.video_clip_24_regular : FluentIcons.image_24_regular,
        size: 24,
        color: context.pepo.textTertiary,
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: colors.accent, borderRadius: Radii.controlRadius),
        child: Text(
          label,
          style: context.text.caption.copyWith(
            color: colors.onAccent,
            fontWeight: FontWeight.w600,
            fontSize: 11,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _DurationPill extends StatelessWidget {
  const _DurationPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 2, 6, 2),
        decoration: BoxDecoration(
          color: const Color(0x99000000),
          borderRadius: Radii.controlRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(FluentIcons.play_12_filled, size: 10, color: Colors.white),
            const SizedBox(width: 3),
            Text(
              label,
              style: context.text.caption.copyWith(color: Colors.white, fontSize: 11, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Green check: the original is already on the PC.
class _OnPcMark extends StatelessWidget {
  const _OnPcMark();

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: colors.success,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: const Icon(FluentIcons.checkmark_12_filled, size: 10, color: Colors.white),
    );
  }
}
