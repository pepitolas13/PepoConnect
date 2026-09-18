import 'dart:async';
import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';

import '../../app/app_services.dart';
import '../../platform/open_helper.dart';
import '../../shared/i18n/l10n.dart';
import '../../shared/motion/fade_slide_switcher.dart';
import '../../shared/motion/motion.dart';
import '../../shared/motion/pressable.dart';
import '../../shared/motion/progress_ring.dart';
import '../../shared/motion/toast.dart';
import '../../shared/theme/pepo_theme.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/util/format.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fluent_button.dart';
import '../../shared/widgets/fluent_tooltip.dart';
import '../../state/engine_providers.dart';
import '../gallery/gallery_actions.dart';
import '../gallery/gallery_grouping.dart';
import '../gallery/gallery_tile.dart';
import '../gallery/thumbnail_lookup.dart';

bool get _touch =>
    defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

/// Full-screen photo / video viewer over the dark backdrop. Paints the
/// cached thumbnail at once (shared [Hero] with the grid tile) and fades to
/// the 1600 px preview when it arrives; arrows and ← → walk the current
/// gallery. In session mode (`?session=1`) it jumps to every new photo.
class ViewerPage extends ConsumerStatefulWidget {
  const ViewerPage({super.key, required this.deviceId, required this.id, this.session});

  final String deviceId;
  final String id;

  /// Forces session mode; when null it is read from the route (`?session=1`).
  final bool? session;

  /// Below this width the chrome uses icon-only buttons and the info panel
  /// docks at the bottom.
  static const double compactWidth = 700;

  static const double infoPanelWidth = 300;

  @override
  ConsumerState<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends ConsumerState<ViewerPage> {
  late String _deviceId = widget.deviceId;
  late String _id = widget.id;

  Uint8List? _thumb;
  Uint8List? _preview;
  bool _previewFailed = false;
  String? _loadedKey;
  Object? _token;
  final Map<String, Uint8List> _previewCache = {};
  static const int _previewCacheSize = 8;

  bool _info = false;
  bool? _session;
  Set<String>? _sessionBaseline;
  DateTime? _sessionNewest;
  final Set<String> _sessionKeys = {};

  final Set<String> _downloading = {};
  bool _videoBusy = false;
  final FocusNode _focus = FocusNode(debugLabel: 'viewer');

  String get _key => galleryKeyOf(_deviceId, _id);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _session ??= widget.session ?? _sessionFromRoute(context);
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  static bool _sessionFromRoute(BuildContext context) {
    if (GoRouter.maybeOf(context) == null) return false;
    try {
      return GoRouterState.of(context).uri.queryParameters['session'] == '1';
    } catch (_) {
      return false;
    }
  }

  /// The gallery the arrows walk: the one on screen when it contains this
  /// device, otherwise the device's own.
  String? _scope(String? selected) =>
      selected == null || selected == _deviceId ? selected : _deviceId;

  // ---------------------------------------------------------------------------
  // Loading

  void _ensureLoaded(GalleryEntry entry, GalleryNotifier notifier, ThumbnailLookup lookup) {
    final key = galleryEntryKey(entry);
    if (_loadedKey == key) return;
    _loadedKey = key;
    final token = Object();
    _token = token;
    _thumb = lookup(entry.deviceId, entry.id);
    _preview = _previewCache[key];
    _previewFailed = false;
    if (_thumb == null) {
      unawaited(
        notifier.thumbnail(entry).then((bytes) {
          if (!mounted || _token != token || bytes == null) return;
          setState(() => _thumb = bytes);
        }, onError: (_) {}),
      );
    }
    if (_preview == null && !entry.item.isVideo) {
      unawaited(
        notifier
            .preview(entry)
            .then(
              (bytes) {
                if (!mounted || _token != token) return;
                setState(() {
                  if (bytes != null) {
                    _preview = bytes;
                    _remember(key, bytes);
                  } else {
                    _previewFailed = true;
                  }
                });
              },
              onError: (_) {
                if (mounted && _token == token) setState(() => _previewFailed = true);
              },
            ),
      );
    }
  }

  void _remember(String key, Uint8List bytes) {
    _previewCache.remove(key);
    _previewCache[key] = bytes;
    while (_previewCache.length > _previewCacheSize) {
      _previewCache.remove(_previewCache.keys.first);
    }
  }

  void _show(GalleryEntry e) {
    if (!mounted) return;
    setState(() {
      _deviceId = e.deviceId;
      _id = e.id;
    });
  }

  /// Session mode: every photo that arrives after the viewer opened is
  /// counted and shown.
  void _trackSession(List<GalleryEntry> entries) {
    if (_session != true) return;
    final baseline = _sessionBaseline;
    if (baseline == null) {
      _sessionBaseline = {for (final e in entries) galleryEntryKey(e)};
      for (final e in entries) {
        if (_sessionNewest == null || e.takenAt.isAfter(_sessionNewest!)) {
          _sessionNewest = e.takenAt;
        }
      }
      return;
    }
    GalleryEntry? newest;
    for (final e in entries) {
      final key = galleryEntryKey(e);
      if (!baseline.add(key)) continue;
      if (!e.isNew || (_sessionNewest != null && !e.takenAt.isAfter(_sessionNewest!))) continue;
      _sessionKeys.add(key);
      if (newest == null || e.takenAt.isAfter(newest.takenAt)) newest = e;
    }
    if (newest == null) return;
    _sessionNewest = newest.takenAt;
    if (galleryEntryKey(newest) != _key) {
      final target = newest;
      WidgetsBinding.instance.addPostFrameCallback((_) => _show(target));
    }
  }

  // ---------------------------------------------------------------------------
  // Actions

  Future<void> _download(GalleryEntry entry, GalleryNotifier notifier) async {
    final key = galleryEntryKey(entry);
    if (entry.isDownloaded || _downloading.contains(key)) return;
    final t = context.t;
    setState(() => _downloading.add(key));
    final path = await ensureDownloaded(ref, notifier, entry);
    if (!mounted) return;
    setState(() => _downloading.remove(key));
    if (path == null) {
      ref
          .read(toastServiceProvider)
          .show(
            ToastData(
              title: t.galDownloadFailed(entry.item.name),
              severity: ToastSeverity.critical,
            ),
          );
    }
  }

  Future<void> _playVideo(GalleryEntry entry, GalleryNotifier notifier) async {
    if (_videoBusy) return;
    final t = context.t;
    final toasts = ref.read(toastServiceProvider);
    setState(() => _videoBusy = true);
    try {
      final path = await ensureDownloaded(ref, notifier, entry);
      final opened = path != null && await OpenHelper.openFile(path);
      if (!opened) {
        toasts.show(ToastData(title: t.vwVideoOpenFailed, severity: ToastSeverity.critical));
      }
    } finally {
      if (mounted) setState(() => _videoBusy = false);
    }
  }

  Future<void> _delete(
    GalleryEntry entry,
    List<GalleryEntry> entries,
    int index,
    GalleryNotifier notifier,
  ) async {
    final next = index + 1 < entries.length
        ? entries[index + 1]
        : index > 0
        ? entries[index - 1]
        : null;
    final actions = GalleryActions(context: context, ref: ref, notifier: notifier);
    final deleted = await actions.deleteOnDevice([entry]);
    if (!deleted || !mounted) return;
    if (next == null) {
      Navigator.of(context).maybePop();
    } else {
      _show(next);
    }
  }

  // ---------------------------------------------------------------------------
  // Build

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedDeviceProvider);
    final scope = _scope(selected);
    final state = ref.watch(galleryProvider(scope));
    final notifier = ref.read(galleryProvider(scope).notifier);
    final lookup = ref.watch(thumbnailLookupProvider);
    final devices = ref.watch(devicesProvider);
    final entries = state.entries;
    final index = entries.indexWhere((e) => e.deviceId == _deviceId && e.id == _id);
    final entry = index >= 0 ? entries[index] : null;
    _trackSession(entries);
    if (entry != null) _ensureLoaded(entry, notifier, lookup);

    final dark = Theme.of(context)
        .copyWith(extensions: [PepoColors.dark, PepoTheme.typography(PepoColors.dark)]);
    return Theme(
      data: dark,
      child: Builder(
        builder: (context) => _buildScaffold(
          context,
          entry: entry,
          entries: entries,
          index: index,
          notifier: notifier,
          deviceName: deviceLabel(devices, _deviceId),
        ),
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context, {
    required GalleryEntry? entry,
    required List<GalleryEntry> entries,
    required int index,
    required GalleryNotifier notifier,
    required String deviceName,
  }) {
    final colors = context.pepo;
    final t = context.t;
    final compact = MediaQuery.sizeOf(context).width < ViewerPage.compactWidth;
    final session = _session == true;
    final hasPrev = index > 0;
    final hasNext = index >= 0 && index < entries.length - 1;
    final panelOpen = _info && entry != null;

    void prev() {
      if (hasPrev) _show(entries[index - 1]);
    }

    void next() {
      if (hasNext) _show(entries[index + 1]);
    }

    final Widget stage;
    if (entry == null) {
      stage = EmptyState(
        icon: FluentIcons.image_24_regular,
        title: t.vwNotFound,
        actionLabel: t.close,
        onAction: () => Navigator.of(context).maybePop(),
      );
    } else if (entry.item.isVideo) {
      stage = _VideoStage(
        entry: entry,
        thumb: _thumb,
        busy: _videoBusy,
        onPlay: () => _playVideo(entry, notifier),
      );
    } else {
      stage = _PhotoStage(
        entry: entry,
        thumb: _thumb,
        preview: _preview,
        failed: _previewFailed,
        onTap: () {
          if (_info) setState(() => _info = false);
        },
      );
    }

    final sessionDownloaded = entries
        .where((e) => _sessionKeys.contains(galleryEntryKey(e)) && e.isDownloaded)
        .length;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): prev,
        const SingleActivator(LogicalKeyboardKey.arrowRight): next,
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop(),
        const SingleActivator(LogicalKeyboardKey.space): () {
          if (entry != null) unawaited(_download(entry, notifier));
        },
        const SingleActivator(LogicalKeyboardKey.keyI): () => setState(() => _info = !_info),
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: Scaffold(
          backgroundColor: colors.viewerBackdrop,
          body: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: panelOpen && !compact ? ViewerPage.infoPanelWidth : 0,
                  ),
                  child: stage,
                ),
              ),
              if (hasPrev)
                Positioned(
                  left: Space.s,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _NavArrow(
                      icon: FluentIcons.chevron_left_24_regular,
                      tooltip: t.viewerPrevious,
                      onTap: prev,
                    ),
                  ),
                ),
              if (hasNext)
                Positioned(
                  right: Space.s + (panelOpen && !compact ? ViewerPage.infoPanelWidth : 0),
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _NavArrow(
                      icon: FluentIcons.chevron_right_24_regular,
                      tooltip: t.viewerNext,
                      onTap: next,
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _topBar(
                  context,
                  entry: entry,
                  index: index,
                  total: entries.length,
                  deviceName: deviceName,
                  compact: compact,
                  onDelete: entry == null ? null : () => _delete(entry, entries, index, notifier),
                  onDownload: entry == null ? null : () => _download(entry, notifier),
                ),
              ),
              if (entry != null)
                Positioned(
                  right: 0,
                  top: compact ? null : _TopBar.height,
                  bottom: 0,
                  left: compact ? 0 : null,
                  child: FadeSlideSwitcher(
                    child: panelOpen
                        ? _InfoPanel(
                            key: const ValueKey('info'),
                            entry: entry,
                            deviceName: deviceName,
                            compact: compact,
                            onClose: () => setState(() => _info = false),
                          )
                        : const SizedBox.shrink(key: ValueKey('no-info')),
                  ),
                ),
              if (session)
                Positioned(
                  left: 0,
                  right: panelOpen && !compact ? ViewerPage.infoPanelWidth : 0,
                  bottom: Space.xl,
                  child: IgnorePointer(
                    child: Center(
                      child: _SessionBadge(
                        photos: _sessionKeys.length,
                        downloaded: sessionDownloaded,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(
    BuildContext context, {
    required GalleryEntry? entry,
    required int index,
    required int total,
    required String deviceName,
    required bool compact,
    required VoidCallback? onDelete,
    required VoidCallback? onDownload,
  }) {
    final t = context.t;
    final key = entry == null ? null : galleryEntryKey(entry);
    final downloading = key != null && _downloading.contains(key);
    final localPath = entry?.localPath;
    final onPc = entry != null && entry.isDownloaded && localPath != null;
    final actions = <Widget>[
      if (entry != null) ...[
        if (onPc) ...[
          if (compact)
            FluentIconButton(
              icon: FluentIcons.open_20_regular,
              tooltip: t.open,
              onPressed: () => OpenHelper.openFile(localPath),
            )
          else
            FluentButton(
              label: t.open,
              icon: FluentIcons.open_16_regular,
              onPressed: () => OpenHelper.openFile(localPath),
            ),
          FluentIconButton(
            icon: FluentIcons.folder_20_regular,
            tooltip: t.showInFolder,
            onPressed: () => OpenHelper.showInFolder(localPath),
          ),
        ] else if (compact)
          downloading
              ? const Padding(
                  padding: EdgeInsets.all(6),
                  child: ProgressRing(size: 20, strokeWidth: 2),
                )
              : FluentIconButton(
                  icon: FluentIcons.arrow_download_20_regular,
                  tooltip: t.download,
                  onPressed: onDownload,
                )
        else
          FluentButton(
            label: t.download,
            icon: FluentIcons.arrow_download_16_regular,
            loading: downloading,
            onPressed: onDownload,
          ),
        FluentIconButton(
          icon: FluentIcons.delete_20_regular,
          tooltip: t.deleteFromPhone,
          onPressed: onDelete,
        ),
        FluentIconButton(
          icon: FluentIcons.info_20_regular,
          tooltip: t.viewerInfo,
          selected: _info,
          onPressed: () => setState(() => _info = !_info),
        ),
      ],
    ];
    return _TopBar(
      title: entry?.item.name ?? '',
      subtitle: index < 0 ? deviceName : '${t.vwPosition(index + 1, total)} · $deviceName',
      onBack: () => Navigator.of(context).maybePop(),
      actions: actions,
    );
  }
}

/// Translucent strip with back, title and the actions.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.actions,
  });

  static const double height = 56;

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final t = context.t;
    return ColoredBox(
      color: const Color(0x8A000000),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s),
            child: Row(
              children: [
                FluentIconButton(
                  icon: FluentIcons.arrow_left_20_regular,
                  tooltip: t.back,
                  onPressed: onBack,
                ),
                const SizedBox(width: Space.s),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: text.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: text.caption.copyWith(color: colors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                for (final a in actions) ...[const SizedBox(width: Space.xs), a],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The photo: thumbnail first, preview faded in on top, zoomable.
class _PhotoStage extends StatelessWidget {
  const _PhotoStage({
    required this.entry,
    required this.thumb,
    required this.preview,
    required this.failed,
    required this.onTap,
  });

  final GalleryEntry entry;
  final Uint8List? thumb;
  final Uint8List? preview;

  /// The preview could not be fetched; a local copy is used when there is one.
  final bool failed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        final w = entry.item.width.toDouble();
        final h = entry.item.height.toDouble();
        final childSize = w > 0 && h > 0
            ? applyBoxFit(BoxFit.contain, Size(w, h), viewport).destination
            : viewport;
        Widget? full;
        final bytes = preview;
        final localPath = entry.localPath;
        if (bytes != null) {
          full = Image.memory(
            bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          );
        } else if (failed && localPath != null && File(localPath).existsSync()) {
          full = Image.file(
            File(localPath),
            fit: BoxFit.contain,
            cacheWidth: 2048,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          );
        }
        final thumbBytes = thumb;
        final stage = Stack(
          fit: StackFit.expand,
          children: [
            if (thumbBytes != null)
              Image.memory(
                thumbBytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              ),
            AnimatedOpacity(
              opacity: full == null ? 0 : 1,
              duration: motion.slow,
              curve: Motion.standard,
              child: full ?? const SizedBox.shrink(),
            ),
            if (thumbBytes == null && full == null) const Center(child: ProgressRing(size: 28)),
          ],
        );
        return PhotoView.customChild(
          childSize: childSize,
          backgroundDecoration: const BoxDecoration(color: Colors.transparent),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 4,
          initialScale: PhotoViewComputedScale.contained,
          onTapUp: (_, _, _) => onTap(),
          child: Hero(
            tag: GalleryTile.heroTag(entry),
            child: SizedBox(width: childSize.width, height: childSize.height, child: stage),
          ),
        );
      },
    );
  }
}

/// A video: its thumbnail and a play button that downloads (if needed) and
/// hands the file to the system player.
class _VideoStage extends StatelessWidget {
  const _VideoStage({
    required this.entry,
    required this.thumb,
    required this.busy,
    required this.onPlay,
  });

  final GalleryEntry entry;
  final Uint8List? thumb;
  final bool busy;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final t = context.t;
    final bytes = thumb;
    return Stack(
      fit: StackFit.expand,
      children: [
        Hero(
          tag: GalleryTile.heroTag(entry),
          child: bytes == null
              ? const SizedBox.shrink()
              : Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                ),
        ),
        Center(
          child: busy
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ProgressRing(size: 32),
                    const SizedBox(height: Space.s),
                    Text(t.vwDownloading, style: text.body),
                  ],
                )
              : _PlayButton(onTap: onPlay),
        ),
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      showHoverFill: false,
      showPressedOverlay: false,
      semanticLabel: context.t.viewerPlay,
      builder: (context, states, _) => AnimatedContainer(
        duration: motion.fast,
        curve: Motion.standard,
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: states.pressed
              ? const Color(0xCC000000)
              : states.hovered
              ? const Color(0xB3000000)
              : const Color(0x99000000),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(FluentIcons.play_24_filled, size: 28, color: Colors.white),
      ),
    );
  }
}

/// Round translucent arrow at the side of the stage.
class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    return FluentTooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        showHoverFill: false,
        showPressedOverlay: false,
        semanticLabel: tooltip,
        builder: (context, states, _) => AnimatedContainer(
          duration: motion.fast,
          curve: Motion.standard,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: states.pressed
                ? const Color(0xB3000000)
                : states.hovered
                ? const Color(0x99000000)
                : const Color(0x66000000),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 24, color: Colors.white),
        ),
      ),
    );
  }
}

/// Name, date, resolution, size, device and where the copy lives.
class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    super.key,
    required this.entry,
    required this.deviceName,
    required this.compact,
    required this.onClose,
  });

  final GalleryEntry entry;
  final String deviceName;
  final bool compact;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final t = context.t;
    final locale = Localizations.localeOf(context).toString();
    final item = entry.item;
    final at = entry.takenAt;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(at),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final size = item.size;
    final rows = <(String, String)>[
      (t.viewerFileName, item.name),
      (t.vwDate, '${formatDate(at, locale: locale)}, $time'),
      if (item.width > 0 && item.height > 0)
        (t.vwResolution, t.viewerDimensions(item.width, item.height)),
      if (size != null) (t.viewerFileSize, formatBytes(size, locale: locale)),
      (t.vwDevice, deviceName),
      (t.onPc, entry.isDownloaded && entry.localPath != null ? entry.localPath! : t.vwStateOnPhone),
    ];
    return Container(
      width: compact ? double.infinity : ViewerPage.infoPanelWidth,
      constraints: compact ? const BoxConstraints(maxHeight: 320) : null,
      decoration: BoxDecoration(
        color: const Color(0xF21F1F1F),
        border: compact
            ? Border(top: BorderSide(color: colors.divider))
            : Border(left: BorderSide(color: colors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.s, Space.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text(t.viewerInfo, style: text.bodyStrong)),
                  FluentIconButton(
                    icon: FluentIcons.dismiss_16_regular,
                    tooltip: t.close,
                    onPressed: onClose,
                  ),
                ],
              ),
              const SizedBox(height: Space.s),
              for (final (label, value) in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.m, right: Space.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: text.caption.copyWith(color: colors.textSecondary)),
                      const SizedBox(height: 2),
                      SelectableText(value, style: text.body),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Sesión · 14 fotos · 9 descargadas" and the waiting hint.
class _SessionBadge extends StatelessWidget {
  const _SessionBadge({required this.photos, required this.downloaded});

  final int photos;
  final int downloaded;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final t = context.t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.s),
      decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: Radii.cardRadius),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t.vwSessionCounter(photos, downloaded), style: text.bodyStrong),
          if (photos == 0) ...[
            const SizedBox(height: Space.xs),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ProgressRing(size: 12, strokeWidth: 2, color: colors.textSecondary),
                const SizedBox(width: 6),
                Text(t.vwSessionWaiting, style: text.caption.copyWith(color: colors.textSecondary)),
              ],
            ),
          ],
          if (!_touch) ...[
            const SizedBox(height: 2),
            Text(t.vwSessionHint, style: text.caption.copyWith(color: colors.textTertiary)),
          ],
        ],
      ),
    );
  }
}
