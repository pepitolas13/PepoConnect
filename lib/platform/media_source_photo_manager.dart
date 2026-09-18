import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:pepo_core/pepo_core.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

/// Android/iOS gallery through `photo_manager` (MediaStore / PhotoKit),
/// including change notifications for the "new photo" event.
///
/// Change notifications are noisy and early: on Android the camera inserts
/// the MediaStore row as pending (invisible to queries), writes the file and
/// commits the row, and the observer fires at each step. The scans they
/// trigger go through a [RescanScheduler] so a burst becomes one scan, a
/// notification that lands mid-scan queues another scan instead of being
/// dropped, and a couple of delayed re-scans catch a row that was still
/// pending when the scan ran.
class MediaSourcePhotoManager extends MediaSource {
  MediaSourcePhotoManager({
    required this.cacheDir,
    this.pollFallback = const Duration(seconds: 10),
    this.debounce = const Duration(milliseconds: 300),
    this.settleDelays = const [Duration(milliseconds: 1500), Duration(seconds: 5)],
  });

  final String cacheDir;
  final Duration pollFallback;

  /// Quiet time after the last change notification before scanning.
  final Duration debounce;

  /// Re-scans after each burst of notifications.
  final List<Duration> settleDelays;

  final _changes = StreamController<MediaChange>.broadcast();
  final Map<String, pm.AssetEntity> _known = {};
  final Set<String> _seen = {};
  late final RescanScheduler _rescan = RescanScheduler(
    scan: _diff,
    debounce: debounce,
    settleDelays: settleDelays,
  );
  Timer? _poll;
  bool _running = false;
  bool _notifying = false;
  int _indexVersion = 0;
  pm.AssetPathEntity? _all;

  @override
  Stream<MediaChange> get changes => _changes.stream;

  /// Asks for photo permissions. Returns true when at least limited access
  /// was granted.
  static Future<bool> requestPermission() async {
    final state = await pm.PhotoManager.requestPermissionExtend(
      requestOption: const pm.PermissionRequestOption(
        androidPermission: pm.AndroidPermission(type: pm.RequestType.common, mediaLocation: true),
        iosAccessLevel: pm.IosAccessLevel.readWrite,
      ),
    );
    return state.hasAccess;
  }

  /// Current permission state without prompting.
  static Future<bool> hasPermission() async {
    try {
      final state = await pm.PhotoManager.getPermissionState(
        requestOption: const pm.PermissionRequestOption(
          androidPermission: pm.AndroidPermission(type: pm.RequestType.common, mediaLocation: true),
          iosAccessLevel: pm.IosAccessLevel.readWrite,
        ),
      );
      return state.hasAccess;
    } catch (_) {
      return false;
    }
  }

  bool _permissionMissing = false;

  /// True when the library could not be read (permission not granted yet).
  bool get permissionMissing => _permissionMissing;

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;
    await Directory(cacheDir).create(recursive: true);
    try {
      await _loadRoot();
      await _snapshotIds();
      _permissionMissing = false;
    } catch (_) {
      // No permission yet: the index stays empty until [restart] is called.
      _permissionMissing = true;
    }
    pm.PhotoManager.addChangeCallback(_onChange);
    try {
      await pm.PhotoManager.startChangeNotify();
      _notifying = true;
    } catch (_) {
      _notifying = false;
    }
    _poll = Timer.periodic(pollFallback, (_) => _pollTick());
  }

  /// Re-reads the library after the permission was granted.
  Future<void> restart() async {
    await stop();
    await start();
  }

  @override
  Future<void> stop() async {
    _running = false;
    _poll?.cancel();
    _rescan.cancel();
    pm.PhotoManager.removeChangeCallback(_onChange);
    if (_notifying) {
      try {
        await pm.PhotoManager.stopChangeNotify();
      } catch (_) {}
    }
  }

  void dispose() {
    stop();
    _changes.close();
  }

  Future<void> _loadRoot() async {
    final paths = await pm.PhotoManager.getAssetPathList(
      onlyAll: true,
      type: pm.RequestType.common,
      filterOption: pm.FilterOptionGroup(
        // This path lives as long as the engine (also in the background).
        // The default max is DateTime.now(), which freezes every later query
        // at startup and hides photos/videos created until the next restart.
        createTimeCond: pm.DateTimeCond.def().copyWith(ignore: true),
        orders: [const pm.OrderOption(type: pm.OrderOptionType.createDate, asc: false)],
        containsPathModified: true,
      ),
    );
    _all = paths.isEmpty ? null : paths.first;
    _indexVersion++;
  }

  Future<void> _snapshotIds() async {
    final root = _all;
    if (root == null) return;
    final count = await root.assetCountAsync;
    final page = await root.getAssetListRange(start: 0, end: count.clamp(0, 5000));
    _seen
      ..clear()
      ..addAll(page.map((a) => a.id));
    for (final a in page) {
      _known[a.id] = a;
    }
  }

  void _onChange(MethodCall call) {
    _rescan.signal();
  }

  Future<void> _pollTick() async {
    // A working observer can still miss an individual commit notification.
    // Never disable recovery for minutes just because another event arrived.
    await _rescan.run();
  }

  /// One scan of the newest assets; anything not seen before is reported.
  /// Only runs through [_rescan], which keeps scans from overlapping.
  Future<void> _diff() async {
    if (!_running) return;
    try {
      // The root path is loaded once: listing paths walks the whole store
      // on Android, and the range query below is fresh on every call.
      if (_all == null) await _loadRoot();
      final root = _all;
      if (root == null) return;
      final recent = await root.getAssetListRange(start: 0, end: 30);
      final added = <MediaItem>[];
      for (final a in recent) {
        if (_seen.contains(a.id)) continue;
        _seen.add(a.id);
        _known[a.id] = a;
        final item = await _toItem(a);
        if (item != null) added.add(item);
      }
      if (added.isNotEmpty) {
        _indexVersion++;
        if (!_changes.isClosed) _changes.add(MediaChange(added: added));
      }
    } catch (_) {
      // Transient errors (permission revoked, etc.) are ignored.
    }
  }

  Future<MediaItem?> _toItem(pm.AssetEntity a) async {
    if (a.type != pm.AssetType.image && a.type != pm.AssetType.video) return null;
    final title = a.title ?? await a.titleAsync;
    return MediaItem(
      id: a.id,
      kind: a.type == pm.AssetType.video ? MediaKind.video : MediaKind.image,
      name: title.isEmpty ? '${a.id}.${a.type == pm.AssetType.video ? 'mp4' : 'jpg'}' : title,
      width: a.orientatedWidth,
      height: a.orientatedHeight,
      takenAt: a.createDateTime.toUtc(),
      durationMs: a.type == pm.AssetType.video ? a.videoDuration.inMilliseconds : null,
      mime: a.mimeType ?? (a.type == pm.AssetType.video ? 'video/mp4' : 'image/jpeg'),
      album: null,
    );
  }

  @override
  Future<MediaPage> index({
    int page = 0,
    int pageSize = 200,
    Set<MediaKind>? kinds,
    DateTime? since,
  }) async {
    final root = _all;
    if (root == null) {
      return MediaPage(items: const [], total: 0, nextPage: null, indexVersion: _indexVersion);
    }
    final total = await root.assetCountAsync;
    final assets = await root.getAssetListPaged(page: page, size: pageSize);
    final items = <MediaItem>[];
    for (final a in assets) {
      if (kinds != null && kinds.isNotEmpty) {
        final k = a.type == pm.AssetType.video ? MediaKind.video : MediaKind.image;
        if (!kinds.contains(k)) continue;
      }
      if (since != null && !a.createDateTime.toUtc().isAfter(since)) continue;
      _known[a.id] = a;
      _seen.add(a.id);
      final item = await _toItem(a);
      if (item != null) items.add(item);
    }
    final end = (page + 1) * pageSize;
    return MediaPage(
      items: items,
      total: total,
      nextPage: end < total ? page + 1 : null,
      indexVersion: _indexVersion,
    );
  }

  Future<pm.AssetEntity?> _asset(String id) async => _known[id] ?? await pm.AssetEntity.fromId(id);

  @override
  Future<MediaItem?> item(String id) async {
    final a = await _asset(id);
    return a == null ? null : _toItem(a);
  }

  @override
  Future<Uint8List?> thumbnail(String id, {int maxPx = 320}) async {
    final a = await _asset(id);
    if (a == null) return null;
    return a.thumbnailDataWithSize(
      pm.ThumbnailSize.square(maxPx),
      quality: 80,
      format: pm.ThumbnailFormat.jpeg,
    );
  }

  @override
  Future<Uint8List?> preview(String id, {int maxPx = 1600}) async {
    final a = await _asset(id);
    if (a == null) return null;
    return a.thumbnailDataWithSize(
      pm.ThumbnailSize(maxPx, maxPx),
      quality: 85,
      format: pm.ThumbnailFormat.jpeg,
    );
  }

  @override
  Future<String?> originalPath(String id) async {
    final a = await _asset(id);
    if (a == null) return null;
    final file = await a.originFile;
    return file?.path;
  }

  @override
  Future<List<String>> delete(List<String> ids) async {
    try {
      final deleted = await pm.PhotoManager.editor.deleteWithIds(ids);
      for (final id in deleted) {
        _known.remove(id);
      }
      if (deleted.isNotEmpty && !_changes.isClosed) _changes.add(MediaChange(removed: deleted));
      return deleted;
    } catch (_) {
      return const [];
    }
  }

  /// Converts a HEIC/HEIF file to JPEG next to the cache dir, keeping EXIF.
  Future<String?> convertHeicToJpeg(String path) async {
    try {
      final target = p.join(cacheDir, '${p.basenameWithoutExtension(path)}.jpg');
      final result = await FlutterImageCompress.compressAndGetFile(
        path,
        target,
        quality: 92,
        format: CompressFormat.jpeg,
        keepExif: true,
      );
      return result?.path;
    } catch (_) {
      return null;
    }
  }
}
