import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../net/frame.dart';
import '../net/peer_connection.dart';
import '../net/session.dart';
import '../protocol/message_types.dart';
import '../protocol/models.dart';
import '../transfer/transfer_engine.dart';
import '../transfer/transfer_record.dart';
import 'media_server.dart';

final _log = Logger('pepo.media.gallery');

/// Hub-side state of a remote gallery item.
enum MediaState { fresh, previewed, downloaded, dismissed }

/// Persists per-item states and local paths (implemented by the app with
/// a JSON file per device; [MemoryMediaStateStore] for tests), plus the
/// per-device "seen until" watermark (see [DeviceGallery.seenUntil]).
abstract class MediaStateStore {
  Future<Map<String, MediaItemState>> load(String deviceId);
  Future<void> save(String deviceId, MediaItemState state);
  Future<void> removeDevice(String deviceId);
  Future<DateTime?> loadSeenUntil(String deviceId);
  Future<void> saveSeenUntil(String deviceId, DateTime until);
}

class MediaItemState {
  MediaItemState({
    required this.id,
    required this.state,
    this.localPath,
    this.firstSeen,
    this.hash,
  });

  final String id;
  MediaState state;
  String? localPath;
  DateTime? firstSeen;
  String? hash;

  Map<String, dynamic> toJson() => {
    'id': id,
    'state': state.name,
    'localPath': ?localPath,
    'firstSeen': ?firstSeen?.toUtc().toIso8601String(),
    'hash': ?hash,
  };

  factory MediaItemState.fromJson(Map<String, dynamic> j) => MediaItemState(
    id: j['id'] as String,
    state: MediaState.values.byName(j['state'] as String),
    localPath: j['localPath'] as String?,
    firstSeen: j['firstSeen'] == null ? null : DateTime.parse(j['firstSeen'] as String),
    hash: j['hash'] as String?,
  );
}

class MemoryMediaStateStore implements MediaStateStore {
  final Map<String, Map<String, MediaItemState>> _data = {};
  final Map<String, DateTime> _seenUntil = {};

  @override
  Future<Map<String, MediaItemState>> load(String deviceId) async => Map.of(_data[deviceId] ?? {});

  @override
  Future<void> save(String deviceId, MediaItemState state) async =>
      (_data[deviceId] ??= {})[state.id] = state;

  @override
  Future<void> removeDevice(String deviceId) async {
    _data.remove(deviceId);
    _seenUntil.remove(deviceId);
  }

  @override
  Future<DateTime?> loadSeenUntil(String deviceId) async => _seenUntil[deviceId];

  @override
  Future<void> saveSeenUntil(String deviceId, DateTime until) async => _seenUntil[deviceId] = until;
}

/// What changed in a device gallery.
enum GalleryChange { reset, added, removed, updated, thumbnail, newItem }

class GalleryEvent {
  GalleryEvent(this.deviceId, this.change, {this.ids = const []});
  final String deviceId;
  final GalleryChange change;
  final List<String> ids;
}

/// One remote gallery as seen from the hub.
class DeviceGallery {
  DeviceGallery(this.deviceId);

  final String deviceId;
  final List<MediaItem> items = [];
  final Map<String, MediaItem> byId = {};
  final Map<String, MediaItemState> states = {};
  int total = 0;
  int? nextPage;
  int indexVersion = 0;
  bool loaded = false;
  bool loading = false;
  bool statesLoaded = false;
  Set<MediaKind>? filter;

  /// Newest capture time the user has already looked at in the gallery
  /// (bumped by [GalleryClient.markSeen]). Items without a stored state are
  /// "new" only when captured after it; before the first look nothing is.
  DateTime? seenUntil;

  /// Hub state of [id]: the stored one when there is any; otherwise `fresh`
  /// for an item captured after [seenUntil] (it arrived while the hub was
  /// not looking, e.g. through a reload after a reconnect) and `dismissed`
  /// for the rest.
  MediaState stateOf(String id) {
    final stored = states[id]?.state;
    if (stored != null) return stored;
    final until = seenUntil;
    final item = byId[id];
    if (until == null || item == null) return MediaState.dismissed;
    return item.takenAt.isAfter(until) ? MediaState.fresh : MediaState.dismissed;
  }

  bool isDownloaded(String id) => states[id]?.state == MediaState.downloaded;
  String? localPath(String id) => states[id]?.localPath;

  int get newCount => items.where((i) => stateOf(i.id) == MediaState.fresh).length;

  void _insert(MediaItem item) {
    if (byId.containsKey(item.id)) return;
    byId[item.id] = item;
    var i = 0;
    while (i < items.length && !items[i].takenAt.isBefore(item.takenAt)) {
      i++;
    }
    items.insert(i, item);
    total++;
  }

  void _remove(String id) {
    if (byId.remove(id) == null) return;
    items.removeWhere((i) => i.id == id);
    total = total > 0 ? total - 1 : 0;
  }
}

/// Talks to the [MediaServer] of each paired device: index, thumbnails (with
/// coalesced batches and a disk cache), previews, downloads and live events.
class GalleryClient implements MessageHandler {
  GalleryClient({
    required this.sessions,
    required this.transfers,
    required this.stateStore,
    required this.cacheDir,
    this.thumbPx = 320,
    this.previewPx = 1600,
    this.pageSize = 200,
    this.memoryThumbs = 2000,
  }) {
    _transferSub = transfers.events.listen(_onTransfer);
    _sessionSub = sessions.events.listen(_onSession);
  }

  final SessionManager sessions;
  final TransferEngine transfers;
  final MediaStateStore stateStore;
  final String cacheDir;
  final int thumbPx;
  final int previewPx;
  final int pageSize;
  final int memoryThumbs;

  final Map<String, DeviceGallery> _galleries = {};
  final Map<String, Uint8List> _thumbCache = {};
  final Map<String, Future<Uint8List?>> _thumbInFlight = {};
  final Map<String, List<String>> _thumbQueue = {};
  final Map<String, Timer> _thumbTimers = {};
  final Map<String, Completer<Uint8List?>> _thumbWaiters = {};
  final _events = StreamController<GalleryEvent>.broadcast();
  late final StreamSubscription<TransferEvent> _transferSub;
  late final StreamSubscription<SessionEvent> _sessionSub;

  Stream<GalleryEvent> get events => _events.stream;

  DeviceGallery gallery(String deviceId) =>
      _galleries.putIfAbsent(deviceId, () => DeviceGallery(deviceId));
  Iterable<DeviceGallery> get galleries => _galleries.values;

  void _emit(String deviceId, GalleryChange change, [List<String> ids = const []]) {
    if (!_events.isClosed) _events.add(GalleryEvent(deviceId, change, ids: ids));
  }

  // ---------------------------------------------------------------------------
  // Index

  /// Loads the first page (and persisted states). Safe to call repeatedly.
  Future<void> refresh(String deviceId, {Set<MediaKind>? kinds}) async {
    final g = gallery(deviceId);
    if (g.loading) return;
    g.loading = true;
    try {
      await _loadStates(g);
      final control = sessions.controlFor(deviceId);
      if (control == null) return;
      g.filter = kinds;
      final page = await _requestPage(control, 0, kinds);
      g.items.clear();
      g.byId.clear();
      for (final item in page.items) {
        g.byId[item.id] = item;
        g.items.add(item);
      }
      g.total = page.total;
      g.nextPage = page.nextPage;
      g.indexVersion = page.indexVersion;
      g.loaded = true;
      _emit(deviceId, GalleryChange.reset);
    } finally {
      g.loading = false;
    }
  }

  Future<void> _loadStates(DeviceGallery g) async {
    if (g.statesLoaded) return;
    g.statesLoaded = true;
    g.states.addAll(await stateStore.load(g.deviceId));
    g.seenUntil ??= await stateStore.loadSeenUntil(g.deviceId);
  }

  /// Loads the next page, if any.
  Future<bool> loadMore(String deviceId) async {
    final g = gallery(deviceId);
    final next = g.nextPage;
    if (next == null || g.loading) return false;
    final control = sessions.controlFor(deviceId);
    if (control == null) return false;
    g.loading = true;
    try {
      final page = await _requestPage(control, next, g.filter);
      final added = <String>[];
      for (final item in page.items) {
        if (g.byId.containsKey(item.id)) continue;
        g.byId[item.id] = item;
        g.items.add(item);
        added.add(item.id);
      }
      g.total = page.total;
      g.nextPage = page.nextPage;
      if (added.isNotEmpty) _emit(deviceId, GalleryChange.added, added);
      return page.nextPage != null;
    } finally {
      g.loading = false;
    }
  }

  Future<MediaPage> _requestPage(PeerConnection control, int page, Set<MediaKind>? kinds) async {
    final reply = await control.request(
      MsgType.mediaIndex,
      data: {
        'page': page,
        'pageSize': pageSize,
        if (kinds != null) 'kinds': kinds.map((k) => k.code).toList(),
      },
      timeout: const Duration(seconds: 30),
    );
    return MediaPage.fromJson(reply.data);
  }

  // ---------------------------------------------------------------------------
  // Thumbnails

  String _thumbKey(String deviceId, String id) => '$deviceId/$id';

  /// Cached thumbnail bytes if present (synchronous, for widgets).
  Uint8List? cachedThumbnail(String deviceId, String id) => _thumbCache[_thumbKey(deviceId, id)];

  /// Thumbnail of [id]: memory → disk → network (batched with other
  /// requests made within a few milliseconds).
  Future<Uint8List?> thumbnail(String deviceId, String id) {
    final key = _thumbKey(deviceId, id);
    final cached = _thumbCache[key];
    if (cached != null) return Future.value(cached);
    return _thumbInFlight.putIfAbsent(key, () async {
      try {
        final disk = await _readDisk(deviceId, id);
        if (disk != null) {
          _rememberThumb(key, disk);
          return disk;
        }
        return await _fetchThumb(deviceId, id);
      } finally {
        _thumbInFlight.remove(key);
      }
    });
  }

  Future<Uint8List?> _fetchThumb(String deviceId, String id) {
    final key = _thumbKey(deviceId, id);
    final completer = Completer<Uint8List?>();
    _thumbWaiters[key] = completer;
    (_thumbQueue[deviceId] ??= []).add(id);
    _thumbTimers[deviceId] ??= Timer(
      const Duration(milliseconds: 15),
      () => _flushThumbs(deviceId),
    );
    if (_thumbQueue[deviceId]!.length >= 32) {
      _thumbTimers[deviceId]?.cancel();
      _thumbTimers.remove(deviceId);
      _flushThumbs(deviceId);
    }
    return completer.future;
  }

  Future<void> _flushThumbs(String deviceId) async {
    _thumbTimers.remove(deviceId);
    final ids = _thumbQueue.remove(deviceId) ?? const [];
    if (ids.isEmpty) return;
    final control = sessions.controlFor(deviceId);
    Map<String, Uint8List> got = const {};
    if (control != null) {
      try {
        final reply = await control.request(
          MsgType.mediaThumb,
          data: {'ids': ids, 'px': thumbPx},
          timeout: const Duration(seconds: 30),
        );
        got = MediaServer.parseThumbBatch(reply);
      } catch (e) {
        _log.fine('thumb batch failed: $e');
      }
    }
    for (final id in ids) {
      final key = _thumbKey(deviceId, id);
      final bytes = got[id];
      if (bytes != null) {
        _rememberThumb(key, bytes);
        unawaited(_writeDisk(deviceId, id, bytes));
      }
      _thumbWaiters.remove(key)?.complete(bytes);
    }
    _emit(deviceId, GalleryChange.thumbnail, ids);
  }

  void _rememberThumb(String key, Uint8List bytes) {
    if (_thumbCache.length >= memoryThumbs) _thumbCache.remove(_thumbCache.keys.first);
    _thumbCache[key] = bytes;
  }

  File _diskFile(String deviceId, String id) =>
      File(p.join(cacheDir, deviceId.substring(0, 8), 'thumbs', '$id.jpg'));

  Future<Uint8List?> _readDisk(String deviceId, String id) async {
    try {
      final f = _diskFile(deviceId, id);
      if (await f.exists()) return await f.readAsBytes();
    } catch (_) {}
    return null;
  }

  Future<void> _writeDisk(String deviceId, String id, Uint8List bytes) async {
    try {
      final f = _diskFile(deviceId, id);
      await f.parent.create(recursive: true);
      await f.writeAsBytes(bytes, flush: true);
    } catch (e) {
      _log.fine('thumb cache write failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Previews, downloads, deletes

  /// Medium-resolution preview fetched over the media channel. Marks the item
  /// as previewed.
  Future<Uint8List?> preview(String deviceId, String id) async {
    PeerConnection conn;
    try {
      conn = await sessions.mediaChannel(deviceId);
    } catch (e) {
      final control = sessions.controlFor(deviceId);
      if (control == null) return null;
      conn = control;
    }
    try {
      final reply = await conn.request(
        MsgType.mediaPreview,
        data: {'id': id, 'maxPx': previewPx},
        timeout: const Duration(seconds: 30),
      );
      await _setState(deviceId, id, MediaState.previewed, onlyIfFresh: true);
      return reply.body;
    } on PeerError catch (e) {
      _log.fine('preview $id failed: $e');
      return null;
    }
  }

  /// Asks the device to send the original. The transfer engine reports
  /// progress; on completion the item becomes `downloaded`.
  Future<void> download(String deviceId, String id, {bool convertHeic = false}) async {
    final control = sessions.controlFor(deviceId);
    if (control == null) throw PeerClosedException('device offline');
    await control.request(
      MsgType.fileRequest,
      data: {'id': id, 'convert': convertHeic ? 'jpeg' : 'none'},
      timeout: const Duration(seconds: 30),
    );
  }

  /// Deletes items on the device (the device may ask its user).
  Future<List<String>> deleteOnDevice(String deviceId, List<String> ids) async {
    final control = sessions.controlFor(deviceId);
    if (control == null) throw PeerClosedException('device offline');
    final reply = await control.request(
      MsgType.mediaDelete,
      data: {'ids': ids},
      timeout: const Duration(seconds: 60),
    );
    final deleted = reply.list<String>('deleted');
    final g = gallery(deviceId);
    for (final id in deleted) {
      g._remove(id);
    }
    if (deleted.isNotEmpty) _emit(deviceId, GalleryChange.removed, deleted);
    return deleted;
  }

  Future<void> dismiss(String deviceId, String id) => _setState(deviceId, id, MediaState.dismissed);

  /// The user has looked at [ids] (what the gallery had on screen) and moved
  /// on: their "new" mark goes away and [DeviceGallery.seenUntil] advances
  /// to the newest of them, so only items captured later can still show as
  /// new. One `updated` event for every item that changed.
  Future<void> markSeen(String deviceId, Iterable<String> ids) async {
    final g = gallery(deviceId);
    await _loadStates(g);
    final changed = <String>[];
    DateTime? newest = g.seenUntil;
    for (final id in ids) {
      final item = g.byId[id];
      if (item != null && (newest == null || item.takenAt.isAfter(newest))) {
        newest = item.takenAt;
      }
      final s = g.states[id];
      if (s != null && s.state == MediaState.fresh) {
        s.state = MediaState.dismissed;
        await stateStore.save(deviceId, s);
        changed.add(id);
      } else if (s == null && g.stateOf(id) == MediaState.fresh) {
        changed.add(id);
      }
    }
    if (newest != null && newest != g.seenUntil) {
      g.seenUntil = newest;
      await stateStore.saveSeenUntil(deviceId, newest);
    }
    if (changed.isNotEmpty) _emit(deviceId, GalleryChange.updated, changed);
  }

  Future<void> _setState(
    String deviceId,
    String id,
    MediaState state, {
    String? localPath,
    String? hash,
    bool onlyIfFresh = false,
  }) async {
    final g = gallery(deviceId);
    final current = g.states[id];
    if (onlyIfFresh && current != null && current.state != MediaState.fresh) return;
    final s = current ?? MediaItemState(id: id, state: state, firstSeen: DateTime.now());
    s.state = state;
    if (localPath != null) s.localPath = localPath;
    if (hash != null) s.hash = hash;
    g.states[id] = s;
    await stateStore.save(deviceId, s);
    _emit(deviceId, GalleryChange.updated, [id]);
  }

  // ---------------------------------------------------------------------------
  // Incoming events

  @override
  Future<bool> handleMessage(String deviceId, PeerConnection conn, ControlMessage m) async {
    switch (m.type) {
      case MsgType.mediaNew:
        final item = MediaItem.fromJson(m.map('item')!);
        final g = gallery(deviceId);
        g._insert(item);
        if (m.body.isNotEmpty) {
          final key = _thumbKey(deviceId, item.id);
          _rememberThumb(key, m.body);
          unawaited(_writeDisk(deviceId, item.id, m.body));
        }
        g.states[item.id] ??= MediaItemState(
          id: item.id,
          state: MediaState.fresh,
          firstSeen: DateTime.now(),
        );
        await stateStore.save(deviceId, g.states[item.id]!);
        _emit(deviceId, GalleryChange.newItem, [item.id]);
        return true;
      case MsgType.mediaRemoved:
        final ids = m.list<String>('ids');
        final g = gallery(deviceId);
        for (final id in ids) {
          g._remove(id);
        }
        _emit(deviceId, GalleryChange.removed, ids);
        return true;
      case MsgType.mediaChanged:
        unawaited(refresh(deviceId, kinds: gallery(deviceId).filter));
        return true;
      default:
        return false;
    }
  }

  void _onTransfer(TransferEvent e) {
    final r = e.record;
    if (r.direction != TransferDirection.receive || r.sourceId == null) return;
    if (r.state == TransferState.done && r.finalPath != null) {
      unawaited(
        _setState(
          r.deviceId,
          r.sourceId!,
          MediaState.downloaded,
          localPath: r.finalPath,
          hash: r.hash,
        ),
      );
    }
  }

  void _onSession(SessionEvent e) {
    if (e is DeviceConnectedEvent) {
      unawaited(
        refresh(e.deviceId, kinds: gallery(e.deviceId).filter).catchError((Object err) {
          _log.fine('refresh after connect failed: $err');
        }),
      );
    } else if (e is DeviceForgottenEvent) {
      _galleries.remove(e.deviceId);
      _thumbCache.removeWhere((k, _) => k.startsWith('${e.deviceId}/'));
      unawaited(stateStore.removeDevice(e.deviceId));
      _emit(e.deviceId, GalleryChange.reset);
    }
  }

  Future<void> dispose() async {
    await _transferSub.cancel();
    await _sessionSub.cancel();
    for (final t in _thumbTimers.values) {
      t.cancel();
    }
    await _events.close();
  }
}
