import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:pepo_core/pepo_core.dart';

import 'activity.dart';
import 'stores.dart';

/// The running engine. Overridden in `main` once the engine has started.
final engineProvider = Provider<PepoEngine>(
  (ref) => throw UnimplementedError('engineProvider must be overridden'),
);

/// Private data directory of this profile (overridden in `main`).
final dataDirProvider = Provider<String>(
  (ref) => throw UnimplementedError('dataDirProvider must be overridden'),
);

/// Raw engine events (broadcast).
final engineEventsProvider = StreamProvider<EngineEvent>((ref) => ref.watch(engineProvider).events);

// -----------------------------------------------------------------------------
// Devices

/// Paired devices with live connection state, most recently seen first.
class DevicesNotifier extends Notifier<List<DeviceView>> {
  @override
  List<DeviceView> build() {
    ref.listen(engineEventsProvider, (_, next) {
      final e = next.value;
      if (e is DevicesChangedEvent || e is DeviceConnectionEvent || e is DeviceStatusChangedEvent) {
        unawaited(refresh());
      }
    });
    unawaited(refresh());
    return const [];
  }

  Future<void> refresh() async {
    final list = await ref.read(engineProvider).devices();
    if (ref.mounted) state = list;
  }

  Future<void> forget(String deviceId) => ref.read(engineProvider).forget(deviceId);

  Future<void> rename(String deviceId, String name) =>
      ref.read(engineProvider).updateDevice(deviceId, name: name);

  Future<void> setAutoDownload(String deviceId, bool value) =>
      ref.read(engineProvider).updateDevice(deviceId, autoDownload: value);

  Future<void> setConvertHeic(String deviceId, bool value) =>
      ref.read(engineProvider).updateDevice(deviceId, convertHeic: value);

  Future<void> setShareClipboard(String deviceId, bool value) =>
      ref.read(engineProvider).updateDevice(deviceId, shareClipboard: value);

  void reconnect() => ref.read(engineProvider).reconnectAll();
}

final devicesProvider = NotifierProvider<DevicesNotifier, List<DeviceView>>(DevicesNotifier.new);

/// Connected devices only.
final connectedDevicesProvider = Provider<List<DeviceView>>(
  (ref) => ref.watch(devicesProvider).where((d) => d.connected).toList(),
);

/// Name of a device for labels (falls back to its short id).
String deviceLabel(List<DeviceView> devices, String deviceId) {
  for (final d in devices) {
    if (d.deviceId == deviceId) return d.device.name;
  }
  return 'PEPO-${deviceId.substring(0, 4)}';
}

/// Device selected in the gallery / hub menu. Null means "all devices".
class SelectedDeviceNotifier extends Notifier<String?> {
  @override
  String? build() {
    // Keep the selection valid when devices come and go, and pick the first
    // device paired on its own (so the header reads "Galería de <móvil>").
    ref.listen(devicesProvider, (prev, devices) {
      final current = state;
      if (current != null && !devices.any((d) => d.deviceId == current)) {
        state = null;
      } else if (current == null && (prev ?? const []).isEmpty && devices.length == 1) {
        state = devices.single.deviceId;
      }
    });
    final devices = ref.read(devicesProvider);
    return devices.length == 1 ? devices.single.deviceId : null;
  }

  void select(String? deviceId) => state = deviceId;
}

final selectedDeviceProvider = NotifierProvider<SelectedDeviceNotifier, String?>(
  SelectedDeviceNotifier.new,
);

// -----------------------------------------------------------------------------
// Transfers

@immutable
class TransfersState {
  const TransfersState({this.active = const [], this.history = const []});

  /// Queued/active/paused transfers, oldest first.
  final List<TransferRecord> active;

  /// Finished transfers, most recent first (capped).
  final List<TransferRecord> history;

  int get activeCount => active.where((t) => t.state == TransferState.active).length;

  double get overallProgress {
    var done = 0;
    var total = 0;
    for (final t in active) {
      done += t.bytesDone;
      total += t.size;
    }
    return total == 0 ? 0 : done / total;
  }

  TransfersState copyWith({List<TransferRecord>? active, List<TransferRecord>? history}) =>
      TransfersState(active: active ?? this.active, history: history ?? this.history);
}

class TransfersNotifier extends Notifier<TransfersState> {
  static const historyCap = 300;
  JsonListStore<TransferRecord>? _store;

  @override
  TransfersState build() {
    _store = JsonListStore<TransferRecord>(
      p.join(ref.watch(dataDirProvider), 'history.json'),
      encode: (r) => r.toJson(),
      decode: TransferRecord.fromJson,
      cap: historyCap,
    );
    unawaited(_loadHistory());
    ref.listen(engineEventsProvider, (_, next) {
      final e = next.value;
      if (e is TransferChangedEvent) _apply(e.record, removed: e.removed);
    });
    final engine = ref.read(engineProvider);
    return TransfersState(
      active: engine.activeTransfers.where((t) => !t.state.isTerminal).toList(),
    );
  }

  Future<void> _loadHistory() async {
    final items = await _store!.load();
    if (ref.mounted) state = state.copyWith(history: items);
  }

  void _apply(TransferRecord r, {bool removed = false}) {
    final active = List<TransferRecord>.of(state.active);
    final i = active.indexWhere((t) => t.id == r.id);
    if (removed) {
      if (i >= 0) {
        active.removeAt(i);
        state = state.copyWith(active: active);
      }
      return;
    }
    if (r.state.isTerminal) {
      if (i >= 0) active.removeAt(i);
      final history = [r, ...state.history.where((t) => t.id != r.id)].take(historyCap).toList();
      state = TransfersState(active: active, history: history);
      _store?.save(history);
      return;
    }
    if (i >= 0) {
      active[i] = r;
    } else {
      active.add(r);
    }
    state = state.copyWith(active: active);
  }

  Future<List<TransferRecord>> send(String deviceId, List<String> paths) =>
      ref.read(engineProvider).sendFiles(deviceId, paths);

  Future<void> cancel(int id) => ref.read(engineProvider).cancelTransfer(id);

  Future<void> pause(int id) => ref.read(engineProvider).cancelTransfer(id, pause: true);

  Future<void> resume(int id) => ref.read(engineProvider).resumeTransfer(id);

  void removeFromHistory(int id) {
    final history = state.history.where((t) => t.id != id).toList();
    state = state.copyWith(history: history);
    _store?.save(history);
  }

  void clearHistory() {
    state = state.copyWith(history: const []);
    _store?.save(const []);
  }
}

final transfersProvider = NotifierProvider<TransfersNotifier, TransfersState>(
  TransfersNotifier.new,
);

// -----------------------------------------------------------------------------
// Gallery

/// A gallery item together with the device it belongs to and its hub state.
@immutable
class GalleryEntry {
  const GalleryEntry({
    required this.deviceId,
    required this.item,
    required this.state,
    this.localPath,
  });

  final String deviceId;
  final MediaItem item;
  final MediaState state;
  final String? localPath;

  String get id => item.id;
  bool get isNew => state == MediaState.fresh;
  bool get isDownloaded => state == MediaState.downloaded;
  DateTime get takenAt => item.takenAt.toLocal();
}

@immutable
class GalleryState {
  const GalleryState({
    this.entries = const [],
    this.total = 0,
    this.hasMore = false,
    this.loading = false,
    this.loaded = false,
  });

  final List<GalleryEntry> entries;
  final int total;
  final bool hasMore;
  final bool loading;
  final bool loaded;

  int get newCount => entries.where((e) => e.isNew).length;
  bool get isEmpty => loaded && entries.isEmpty;

  GalleryState copyWith({
    List<GalleryEntry>? entries,
    int? total,
    bool? hasMore,
    bool? loading,
    bool? loaded,
  }) => GalleryState(
    entries: entries ?? this.entries,
    total: total ?? this.total,
    hasMore: hasMore ?? this.hasMore,
    loading: loading ?? this.loading,
    loaded: loaded ?? this.loaded,
  );
}

/// Gallery of one device (`deviceId`) or of all devices merged (`null`).
class GalleryNotifier extends Notifier<GalleryState> {
  GalleryNotifier(this.deviceId);

  final String? deviceId;
  Set<MediaKind>? _filter;

  @override
  GalleryState build() {
    ref.listen(engineEventsProvider, (_, next) {
      final e = next.value;
      if (e is GalleryChangedEvent && (deviceId == null || e.deviceId == deviceId)) _rebuild();
      if (e is DevicesChangedEvent && deviceId == null) _rebuild();
    });
    return _snapshot();
  }

  void _rebuild() => state = _snapshot();

  GalleryState _snapshot() {
    final engine = ref.read(engineProvider);
    final galleries = deviceId == null
        ? engine.gallery.galleries.toList()
        : [engine.gallery.gallery(deviceId!)];
    final entries = <GalleryEntry>[];
    var total = 0;
    var hasMore = false;
    var loading = false;
    var loaded = galleries.isNotEmpty;
    for (final g in galleries) {
      total += g.total;
      hasMore |= g.nextPage != null;
      loading |= g.loading;
      loaded &= g.loaded;
      for (final item in g.items) {
        entries.add(
          GalleryEntry(
            deviceId: g.deviceId,
            item: item,
            state: g.stateOf(item.id),
            localPath: g.localPath(item.id),
          ),
        );
      }
    }
    if (galleries.length > 1) {
      entries.sort((a, b) => b.item.takenAt.compareTo(a.item.takenAt));
    }
    return GalleryState(
      entries: entries,
      total: total,
      hasMore: hasMore,
      loading: loading,
      loaded: loaded,
    );
  }

  Set<MediaKind>? get filter => _filter;

  Future<void> setFilter(Set<MediaKind>? kinds) async {
    _filter = kinds;
    await refresh();
  }

  Future<void> refresh() async {
    final engine = ref.read(engineProvider);
    state = state.copyWith(loading: true);
    final ids = deviceId == null
        ? engine.gallery.galleries.map((g) => g.deviceId).toList()
        : [deviceId!];
    for (final id in ids) {
      try {
        await engine.refreshGallery(id, kinds: _filter);
      } catch (_) {}
    }
    _rebuild();
  }

  Future<void> loadMore() async {
    final engine = ref.read(engineProvider);
    final ids = deviceId == null
        ? engine.gallery.galleries.map((g) => g.deviceId).toList()
        : [deviceId!];
    for (final id in ids) {
      try {
        await engine.loadMoreGallery(id);
      } catch (_) {}
    }
    _rebuild();
  }

  Future<Uint8List?> thumbnail(GalleryEntry e) =>
      ref.read(engineProvider).thumbnail(e.deviceId, e.id);

  Future<Uint8List?> preview(GalleryEntry e) => ref.read(engineProvider).preview(e.deviceId, e.id);

  Future<void> download(Iterable<GalleryEntry> entries) async {
    final engine = ref.read(engineProvider);
    final byDevice = <String, List<String>>{};
    for (final e in entries) {
      (byDevice[e.deviceId] ??= []).add(e.id);
    }
    for (final entry in byDevice.entries) {
      await engine.downloadItems(entry.key, entry.value);
    }
  }

  Future<void> dismiss(GalleryEntry e) => ref.read(engineProvider).dismissItem(e.deviceId, e.id);

  Future<List<String>> deleteOnDevice(Iterable<GalleryEntry> entries) async {
    final engine = ref.read(engineProvider);
    final deleted = <String>[];
    final byDevice = <String, List<String>>{};
    for (final e in entries) {
      (byDevice[e.deviceId] ??= []).add(e.id);
    }
    for (final entry in byDevice.entries) {
      deleted.addAll(await engine.deleteOnDevice(entry.key, entry.value));
    }
    return deleted;
  }
}

final galleryProvider = NotifierProvider.family<GalleryNotifier, GalleryState, String?>(
  GalleryNotifier.new,
);

/// Synchronous thumbnail lookup for widgets (memory cache only).
Uint8List? cachedThumbnail(WidgetRef ref, GalleryEntry e) =>
    ref.read(engineProvider).gallery.cachedThumbnail(e.deviceId, e.id);

// -----------------------------------------------------------------------------
// Pairing

class PairingNotifier extends Notifier<PairingInvite?> {
  @override
  PairingInvite? build() {
    ref.listen(engineEventsProvider, (_, next) {
      final e = next.value;
      if (e is PairingChangedEvent) state = e.invite;
    });
    return ref.read(engineProvider).currentInvite;
  }

  Future<PairingInvite> startQr() => ref.read(engineProvider).startQrPairing();

  Future<PairingInvite> startCode() => ref.read(engineProvider).startCodePairing();

  void cancel() {
    ref.read(engineProvider).cancelPairing();
    state = null;
  }

  /// Scanned or pasted `pepoconnect://pair/...` text.
  Future<PairedDevice> pairWithText(String text) => ref.read(engineProvider).pairWithQrText(text);

  Future<PairedDevice> pairWithCode({
    required String code,
    PeerCandidate? candidate,
    String? host,
    int? port,
  }) => ref
      .read(engineProvider)
      .pairWithCode(code: code, candidate: candidate, host: host, port: port);

  List<PeerCandidate> discovered() => ref.read(engineProvider).discoveredCandidates();

  Future<List<String>> localAddresses() => ref.read(engineProvider).localAddresses();
}

final pairingProvider = NotifierProvider<PairingNotifier, PairingInvite?>(PairingNotifier.new);

/// Devices found on the network that are not paired, refreshed while watched.
final discoveredDevicesProvider = StreamProvider<List<PeerCandidate>>((ref) async* {
  final engine = ref.watch(engineProvider);
  while (true) {
    yield engine.discoveredCandidates();
    await Future<void>.delayed(const Duration(seconds: 2));
  }
});

// -----------------------------------------------------------------------------
// Activity

class ActivityNotifier extends Notifier<List<ActivityEntry>> {
  static const cap = 300;
  JsonListStore<ActivityEntry>? _store;
  int _seq = 0;

  @override
  List<ActivityEntry> build() {
    _store = JsonListStore<ActivityEntry>(
      p.join(ref.watch(dataDirProvider), 'activity.json'),
      encode: (a) => a.toJson(),
      decode: ActivityEntry.fromJson,
      cap: cap,
    );
    unawaited(_load());
    ref.listen(engineEventsProvider, (_, next) {
      final e = next.value;
      if (e != null) _onEvent(e);
    });
    return const [];
  }

  Future<void> _load() async {
    final items = await _store!.load();
    if (ref.mounted && state.isEmpty) state = items;
  }

  String _name(String deviceId) {
    final engine = ref.read(engineProvider);
    return engine.device(deviceId)?.device.name ?? deviceLabel(ref.read(devicesProvider), deviceId);
  }

  void _onEvent(EngineEvent e) {
    final engine = ref.read(engineProvider);
    switch (e) {
      case GalleryChangedEvent(change: GalleryChange.newItem):
        for (final id in e.ids) {
          final item = engine.gallery.gallery(e.deviceId).byId[id];
          _add(
            ActivityEntry(
              id: _nextId(),
              at: DateTime.now(),
              kind: item?.isVideo == true ? ActivityKind.newVideo : ActivityKind.newPhoto,
              deviceId: e.deviceId,
              deviceName: _name(e.deviceId),
              fileName: item?.name,
              mediaId: id,
            ),
          );
        }
      case TransferChangedEvent(record: final r) when r.state.isTerminal:
        final kind = switch (r.state) {
          TransferState.done => r.isIncoming ? ActivityKind.received : ActivityKind.sent,
          TransferState.failed => ActivityKind.failed,
          _ => null,
        };
        if (kind != null) {
          _add(
            ActivityEntry(
              id: _nextId(),
              at: DateTime.now(),
              kind: kind,
              deviceId: r.deviceId,
              deviceName: _name(r.deviceId),
              fileName: r.name,
              transferId: r.id,
              path: r.finalPath,
              mediaId: r.sourceId,
              text: r.error,
            ),
          );
        }
      case DeviceConnectionEvent():
        _add(
          ActivityEntry(
            id: _nextId(),
            at: DateTime.now(),
            kind: e.connected ? ActivityKind.connected : ActivityKind.disconnected,
            deviceId: e.deviceId,
            deviceName: _name(e.deviceId),
            read: true,
          ),
        );
      case DevicePairedEngineEvent():
        _add(
          ActivityEntry(
            id: _nextId(),
            at: DateTime.now(),
            kind: ActivityKind.paired,
            deviceId: e.device.deviceId,
            deviceName: e.device.name,
          ),
        );
      case ClipboardReceivedEvent():
        _add(
          ActivityEntry(
            id: _nextId(),
            at: DateTime.now(),
            kind: ActivityKind.clipboard,
            deviceId: e.deviceId,
            deviceName: _name(e.deviceId),
            text: e.text,
          ),
        );
      default:
        break;
    }
  }

  String _nextId() => '${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  void _add(ActivityEntry entry) {
    final next = [entry, ...state].take(cap).toList();
    state = next;
    _store?.save(next);
  }

  int get unreadCount => state.where((a) => !a.read).length;

  void markAllRead() {
    if (state.every((a) => a.read)) return;
    final next = state.map((a) => a.read ? a : a.copyWith(read: true)).toList();
    state = next;
    _store?.save(next);
  }

  void clear() {
    state = const [];
    _store?.save(const []);
  }
}

final activityProvider = NotifierProvider<ActivityNotifier, List<ActivityEntry>>(
  ActivityNotifier.new,
);

final unreadActivityProvider = Provider<int>(
  (ref) => ref.watch(activityProvider).where((a) => !a.read).length,
);

/// Text pushed from another device's clipboard (platform layer applies it).
final clipboardEventsProvider = StreamProvider<ClipboardReceivedEvent>(
  (ref) => ref.watch(engineProvider).events.where((e) => e is ClipboardReceivedEvent).cast(),
);
