import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:pepo_core/pepo_core.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

/// Android/iOS gallery through `photo_manager` (MediaStore / PhotoKit),
/// including change notifications for the "new photo" event.
class MediaSourcePhotoManager extends MediaSource {
  MediaSourcePhotoManager({required this.cacheDir, this.pollFallback = const Duration(seconds: 10)});

  final String cacheDir;
  final Duration pollFallback;

  final _changes = StreamController<MediaChange>.broadcast();
  final Map<String, pm.AssetEntity> _known = {};
  final Set<String> _seen = {};
  DateTime? _lastObserverEvent;
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

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;
    await Directory(cacheDir).create(recursive: true);
    await _loadRoot();
    await _snapshotIds();
    pm.PhotoManager.addChangeCallback(_onChange);
    try {
      await pm.PhotoManager.startChangeNotify();
      _notifying = true;
    } catch (_) {
      _notifying = false;
    }
    _poll = Timer.periodic(pollFallback, (_) => _pollTick());
  }

  @override
  Future<void> stop() async {
    _running = false;
    _poll?.cancel();
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
    _lastObserverEvent = DateTime.now();
    unawaited(_diff());
  }

  Future<void> _pollTick() async {
    // Only poll when the observer seems dead (some OEMs break it).
    final last = _lastObserverEvent;
    if (_notifying && last != null && DateTime.now().difference(last) < const Duration(minutes: 5)) return;
    await _diff();
  }

  bool _diffing = false;

  Future<void> _diff() async {
    if (_diffing || !_running) return;
    _diffing = true;
    try {
      await _loadRoot();
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
      if (added.isNotEmpty && !_changes.isClosed) {
        _changes.add(MediaChange(added: added));
      }
    } catch (_) {
      // Transient errors (permission revoked, etc.) are ignored.
    } finally {
      _diffing = false;
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
  Future<MediaPage> index({int page = 0, int pageSize = 200, Set<MediaKind>? kinds, DateTime? since}) async {
    final root = _all;
    if (root == null) return MediaPage(items: const [], total: 0, nextPage: null, indexVersion: _indexVersion);
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
    return MediaPage(items: items, total: total, nextPage: end < total ? page + 1 : null, indexVersion: _indexVersion);
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
    return a.thumbnailDataWithSize(pm.ThumbnailSize.square(maxPx), quality: 80, format: pm.ThumbnailFormat.jpeg);
  }

  @override
  Future<Uint8List?> preview(String id, {int maxPx = 1600}) async {
    final a = await _asset(id);
    if (a == null) return null;
    return a.thumbnailDataWithSize(pm.ThumbnailSize(maxPx, maxPx), quality: 85, format: pm.ThumbnailFormat.jpeg);
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
