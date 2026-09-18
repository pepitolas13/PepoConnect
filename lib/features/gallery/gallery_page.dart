import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pepo_core/pepo_core.dart' show DeviceView, MediaKind;

import '../../app/router.dart';
import '../../shared/i18n/l10n.dart';
import '../../shared/motion/fade_slide_switcher.dart';
import '../../shared/motion/progress_ring.dart';
import '../../shared/motion/skeleton.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/device_icon.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fluent_button.dart';
import '../../shared/widgets/flyout.dart';
import '../../shared/widgets/pepo_checkbox.dart';
import '../../shared/widgets/section_header.dart';
import '../../state/app_settings.dart';
import '../../state/engine_providers.dart';
import 'gallery_actions.dart';
import 'gallery_grouping.dart';
import 'gallery_header.dart';
import 'gallery_selection.dart';
import 'gallery_tile.dart';
import 'thumbnail_lookup.dart';

bool get _touch =>
    defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

/// Gallery of the selected device (or of all of them), grouped by month with
/// today and yesterday apart, multi-selection, context menu, infinite
/// scroll and the viewer on double click / tap.
class GalleryPage extends ConsumerStatefulWidget {
  const GalleryPage({super.key});

  /// Grid gap.
  static const double gap = 4;

  /// Distance to the end of the list that triggers the next page.
  static const double loadMoreThreshold = 600;

  static double tileExtentFor(GalleryTileSize size) => switch (size) {
    GalleryTileSize.large => 232,
    GalleryTileSize.medium => 156,
    GalleryTileSize.small => 108,
  };

  @override
  ConsumerState<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<GalleryPage> {
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode(debugLabel: 'gallery');
  GallerySelection _selection = const GallerySelection.empty();

  /// 0 photos, 1 videos, 2 all.
  int _filterIndex = 2;
  bool _loadingMore = false;
  final Set<String?> _kicked = {};

  // New-arrival tracking for the glow: keys seen so far for the current
  // scope, the newest capture time seen, and the keys still glowing.
  String? _trackedScope;
  bool _tracked = false;
  final Set<String> _seen = {};
  DateTime? _newestSeen;
  final Set<String> _arrived = {};

  @override
  void dispose() {
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Set<MediaKind>? get _kinds => switch (_filterIndex) {
    0 => {MediaKind.image},
    1 => {MediaKind.video},
    _ => null,
  };

  GalleryNotifier _notifier(String? scope) => ref.read(galleryProvider(scope).notifier);

  GalleryActions _actions(String? scope) =>
      GalleryActions(context: context, ref: ref, notifier: _notifier(scope));

  // ---------------------------------------------------------------------------
  // Data

  void _trackArrivals(String? scope, GalleryState state) {
    if (scope != _trackedScope) {
      _trackedScope = scope;
      _tracked = false;
      _seen.clear();
      _newestSeen = null;
      _arrived.clear();
    }
    final entries = state.entries;
    if (!_tracked) {
      if (!state.loaded && entries.isEmpty) return;
      _tracked = true;
      for (final e in entries) {
        _seen.add(galleryEntryKey(e));
        if (_newestSeen == null || e.takenAt.isAfter(_newestSeen!)) _newestSeen = e.takenAt;
      }
      return;
    }
    var newest = _newestSeen;
    final stillNew = <String>{};
    for (final e in entries) {
      final key = galleryEntryKey(e);
      if (e.isNew) stillNew.add(key);
      if (_seen.add(key) &&
          e.isNew &&
          (_newestSeen == null || e.takenAt.isAfter(_newestSeen!))) {
        _arrived.add(key);
      }
      if (newest == null || e.takenAt.isAfter(newest)) newest = e.takenAt;
    }
    _newestSeen = newest;
    // Once an item stops being new (seen, downloaded, dismissed) it must not
    // glow again when its tile comes back on screen.
    if (_arrived.isNotEmpty) _arrived.removeWhere((k) => !stillNew.contains(k));
  }

  /// First page for a scope that has never loaded while a device is
  /// connected (the engine also refreshes on connect; this covers the rest).
  void _maybeInitialRefresh(String? scope, GalleryState state, List<DeviceView> devices) {
    if (_kicked.contains(scope) || state.loaded || state.loading) return;
    final connected = scope == null
        ? devices.any((d) => d.connected)
        : devices.any((d) => d.deviceId == scope && d.connected);
    if (!connected) return;
    _kicked.add(scope);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_notifier(scope).refresh());
    });
  }

  void _applyFilter(String? scope) {
    final notifier = _notifier(scope);
    if (!setEquals(notifier.filter, _kinds)) unawaited(notifier.setFilter(_kinds));
  }

  void _onFilterChanged(String? scope, int index) {
    setState(() => _filterIndex = index);
    _applyFilter(scope);
  }

  Future<void> _loadMore(String? scope) async {
    if (_loadingMore) return;
    final state = ref.read(galleryProvider(scope));
    if (!state.hasMore || state.loading) return;
    _loadingMore = true;
    try {
      await _notifier(scope).loadMore();
    } finally {
      _loadingMore = false;
    }
  }

  bool _onScroll(ScrollNotification n, String? scope) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (n.metrics.pixels >= n.metrics.maxScrollExtent - GalleryPage.loadMoreThreshold) {
      unawaited(_loadMore(scope));
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Selection

  void _select(GallerySelection next) => setState(() => _selection = next);

  void _onTileTap(GalleryEntry e, String key, List<String> ordered) {
    if (_touch) {
      if (_selection.isNotEmpty) {
        _select(_selection.toggled(key));
      } else {
        _open(e);
      }
      return;
    }
    final keyboard = HardwareKeyboard.instance;
    final ctrl = keyboard.isControlPressed || keyboard.isMetaPressed;
    final shift = keyboard.isShiftPressed;
    if (shift && _selection.anchor != null) {
      _select(_selection.withRange(ordered, key));
    } else if (ctrl) {
      _select(_selection.toggled(key));
    } else if (_selection.length == 1 && _selection.contains(key)) {
      _select(const GallerySelection.empty());
    } else {
      _select(_selection.only(key));
    }
    _focus.requestFocus();
  }

  void _toggleGroup(List<String> keys, bool allSelected) {
    _select(allSelected ? _selection.without(keys) : _selection.withAll(keys));
    _focus.requestFocus();
  }

  void _contextMenu(
    String? scope,
    GalleryEntry e,
    String key,
    Offset position,
    List<GalleryEntry> entries,
  ) {
    if (!_selection.contains(key)) _select(_selection.only(key));
    final targets = _selection.entriesFrom(entries);
    final t = context.t;
    showContextMenu(
      context,
      position: position,
      items: [
        ..._actions(scope).menuItems(targets, onOpenViewer: () => _open(e)),
        if (entries.any((x) => x.isNew)) ...[
          const MenuDivider(),
          MenuItem(label: t.galSelectNew, onTap: () => _selectNew(entries)),
        ],
      ],
    );
  }

  /// Selects every item still marked as new, so they can be downloaded in
  /// one go (also Ctrl+Shift+N).
  void _selectNew(List<GalleryEntry> entries) {
    final keys = [
      for (final e in entries)
        if (e.isNew) galleryEntryKey(e),
    ];
    if (keys.isNotEmpty) _select(const GallerySelection.empty().withAll(keys));
  }

  void _open(GalleryEntry e, {bool session = false}) {
    if (_selection.isNotEmpty && !_touch) _select(const GallerySelection.empty());
    final path = AppRoutes.viewer(e.deviceId, e.id);
    context.push(session ? '$path?session=1' : path);
  }

  Future<void> _delete(String? scope, List<GalleryEntry> entries) async {
    final deleted = await _actions(scope).deleteOnDevice(entries);
    if (deleted && mounted) _select(const GallerySelection.empty());
  }

  // ---------------------------------------------------------------------------
  // Build

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final scope = ref.watch(selectedDeviceProvider);
    final devices = ref.watch(devicesProvider);
    final settings = ref.watch(settingsProvider);
    final lookup = ref.watch(thumbnailLookupProvider);
    final state = ref.watch(galleryProvider(scope));
    final notifier = _notifier(scope);
    ref.listen(selectedDeviceProvider, (_, next) => _applyFilter(next));
    _trackArrivals(scope, state);
    _maybeInitialRefresh(scope, state, devices);

    final entries = state.entries;
    final ordered = [for (final e in entries) galleryEntryKey(e)];
    _selection = _selection.retain(ordered.toSet());
    final selectedEntries = _selection.entriesFrom(entries);
    final extent = GalleryPage.tileExtentFor(settings.galleryTileSize);
    final meta = defaultTargetPlatform == TargetPlatform.macOS;

    final options = [
      for (final d in devices)
        GalleryDeviceOption(
          id: d.deviceId,
          name: d.device.name,
          kind: DeviceKind.fromPlatform(d.device.platform, model: d.device.model),
          connected: d.connected,
        ),
    ];
    final newCount = state.newCount;
    final summary = entries.isEmpty
        ? null
        : newCount > 0
        ? '${t.galleryItemsCount(state.total)} · ${t.newPhotosCount(newCount)}'
        : t.galleryItemsCount(state.total);

    final Widget top = _selection.isEmpty
        ? GalleryHeader(
            key: const ValueKey('header'),
            devices: options,
            selectedDeviceId: scope,
            onDeviceChanged: (id) => ref.read(selectedDeviceProvider.notifier).select(id),
            filterIndex: _filterIndex,
            onFilterChanged: (i) => _onFilterChanged(scope, i),
            tileSize: settings.galleryTileSize,
            square: settings.gallerySquare,
            onTileSizeChanged: (size) => ref
                .read(settingsProvider.notifier)
                .update((s) => s.copyWith(galleryTileSize: size)),
            onSquareChanged: (square) => ref
                .read(settingsProvider.notifier)
                .update((s) => s.copyWith(gallerySquare: square)),
            onRefresh: devices.isEmpty ? null : () => unawaited(notifier.refresh()),
            onSession: entries.isEmpty ? null : () => _open(entries.first, session: true),
            summary: summary,
          )
        : GallerySelectionBar(
            key: const ValueKey('selection'),
            count: _selection.length,
            bytes: GallerySelection.bytesOf(selectedEntries),
            onClear: () => _select(const GallerySelection.empty()),
            onDownload: selectedEntries.any((e) => !e.isDownloaded)
                ? () => _actions(scope).download(selectedEntries)
                : null,
            onSaveAs: () => _actions(scope).saveAs(selectedEntries),
            onDelete: () => _delete(scope, selectedEntries),
            menuItems: () => _actions(scope).menuItems(
              selectedEntries,
              onOpenViewer: selectedEntries.length == 1 ? () => _open(selectedEntries.first) : null,
            ),
          );

    final Widget body;
    if (devices.isEmpty) {
      body = EmptyState(
        icon: FluentIcons.phone_desktop_24_regular,
        title: t.noDevicesYet,
        message: t.pairFirstDevice,
        actionLabel: t.addDevice,
        onAction: () => context.go(AppRoutes.pair),
      );
    } else if (entries.isEmpty) {
      final connected = scope == null
          ? devices.any((d) => d.connected)
          : devices.any((d) => d.deviceId == scope && d.connected);
      if (!connected) {
        body = EmptyState(
          icon: FluentIcons.plug_disconnected_24_regular,
          title: t.galleryOffline,
          message: t.galOfflineBody,
        );
      } else if (!state.loaded || state.loading) {
        body = _SkeletonGrid(extent: extent);
      } else {
        body = EmptyState(
          icon: FluentIcons.image_24_regular,
          title: t.galleryEmptyTitle,
          message: t.galleryEmptyBody,
        );
      }
    } else {
      body = _grid(
        scope: scope,
        state: state,
        entries: entries,
        ordered: ordered,
        extent: extent,
        square: settings.gallerySquare,
        lookup: lookup,
        notifier: notifier,
      );
    }

    SingleActivator ctrl(LogicalKeyboardKey key) =>
        SingleActivator(key, control: !meta, meta: meta);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CallbackShortcuts(
        bindings: {
          ctrl(LogicalKeyboardKey.keyA): () {
            if (entries.isNotEmpty) _select(_selection.withAll(ordered));
          },
          SingleActivator(LogicalKeyboardKey.keyN, control: !meta, meta: meta, shift: true): () =>
              _selectNew(entries),
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_selection.isNotEmpty) _select(const GallerySelection.empty());
          },
        },
        child: Focus(
          focusNode: _focus,
          skipTraversal: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeSlideSwitcher(child: top),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid({
    required String? scope,
    required GalleryState state,
    required List<GalleryEntry> entries,
    required List<String> ordered,
    required double extent,
    required bool square,
    required ThumbnailLookup lookup,
    required GalleryNotifier notifier,
  }) {
    final t = context.t;
    final groups = groupGalleryEntries(entries);
    final slivers = <Widget>[];
    for (final g in groups) {
      final keys = [for (final e in g.entries) galleryEntryKey(e)];
      final allSelected = keys.every(_selection.contains);
      final title = galleryGroupTitle(context, g);
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.xl),
            child: SectionHeader(
              title: title,
              count: g.length,
              padding: const EdgeInsets.fromLTRB(0, Space.m, 0, Space.s),
              leading: PepoCheckbox(
                value: allSelected,
                onChanged: (_) => _toggleGroup(keys, allSelected),
                semanticLabel: t.galSelectGroup(title),
              ),
            ),
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: extent,
              mainAxisSpacing: GalleryPage.gap,
              crossAxisSpacing: GalleryPage.gap,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final e = g.entries[i];
                final key = keys[i];
                return GalleryTile(
                  key: ValueKey(key),
                  entry: e,
                  extent: extent,
                  square: square,
                  selected: _selection.contains(key),
                  selecting: _selection.isNotEmpty,
                  glow: e.isNew && _arrived.contains(key),
                  lookup: lookup,
                  loadThumbnail: notifier.thumbnail,
                  onTap: () => _onTileTap(e, key, ordered),
                  onOpen: () => _open(e),
                  onToggle: () {
                    _select(_selection.toggled(key));
                    _focus.requestFocus();
                  },
                  onContextMenu: (position) => _contextMenu(scope, e, key, position, entries),
                  onGlowFinished: () => _arrived.remove(key),
                );
              },
              childCount: g.length,
              findChildIndexCallback: (key) {
                final i = keys.indexOf((key as ValueKey<String>).value);
                return i < 0 ? null : i;
              },
              addRepaintBoundaries: false,
            ),
          ),
        ),
      );
    }
    slivers.add(
      SliverToBoxAdapter(
        child: _Trailer(
          hasMore: state.hasMore,
          loading: state.loading,
          onLoadMore: () => unawaited(_loadMore(scope)),
        ),
      ),
    );
    Widget scroll = NotificationListener<ScrollNotification>(
      onNotification: (n) => _onScroll(n, scope),
      child: CustomScrollView(
        controller: _scroll,
        scrollCacheExtent: const ScrollCacheExtent.pixels(800),
        slivers: slivers,
      ),
    );
    if (_touch) scroll = RefreshIndicator(onRefresh: notifier.refresh, child: scroll);
    return scroll;
  }
}

/// Bottom of the grid: a ring while the next page loads, "Load more" when
/// the list did not fill the viewport, or breathing room.
class _Trailer extends StatelessWidget {
  const _Trailer({required this.hasMore, required this.loading, required this.onLoadMore});

  final bool hasMore;
  final bool loading;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (!hasMore && !loading) return const SizedBox(height: Space.xl);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.l),
      child: Center(
        child: loading
            ? const ProgressRing()
            : FluentButton.subtle(label: context.t.galleryLoadMore, onPressed: onLoadMore),
      ),
    );
  }
}

/// Placeholder grid shown while the first page loads.
class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid({required this.extent});

  final double extent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.l, Space.xl, Space.xl),
      child: Wrap(
        spacing: GalleryPage.gap,
        runSpacing: GalleryPage.gap,
        children: [
          for (var i = 0; i < 12; i++)
            Skeleton(width: extent, height: extent, borderRadius: Radii.controlRadius),
        ],
      ),
    );
  }
}
