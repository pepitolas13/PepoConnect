import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../protocol/models.dart';
import '../util/bytes.dart';
import 'image_ops.dart';
import 'media_source.dart';

final _log = Logger('pepo.media.fs');

/// Gallery backed by folders (Linux phones: `~/Pictures`, `~/DCIM`; desktop
/// tests). Ids are stable hashes of the absolute path.
class MediaSourceFs extends MediaSource {
  MediaSourceFs({
    required this.roots,
    required this.cacheDir,
    this.rescanInterval = const Duration(seconds: 30),
    this.settleTime = const Duration(milliseconds: 500),
    this.thumbnailQuality = 80,
  });

  final List<String> roots;
  final String cacheDir;
  final Duration rescanInterval;
  final Duration settleTime;
  final int thumbnailQuality;

  static const imageExt = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic', '.heif', '.tif', '.tiff'};
  static const videoExt = {'.mp4', '.m4v', '.mov', '.mkv', '.webm', '.3gp', '.avi'};

  final Map<String, _Entry> _entries = {};
  List<MediaItem> _sorted = const [];
  int _indexVersion = 0;
  final _changes = StreamController<MediaChange>.broadcast();
  final List<StreamSubscription<FileSystemEvent>> _watches = [];
  final Map<String, Timer> _pending = {};
  Timer? _rescan;
  bool _running = false;
  final Map<String, Uint8List> _thumbMemory = {};

  @override
  Stream<MediaChange> get changes => _changes.stream;

  int get count => _entries.length;

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;
    await Directory(cacheDir).create(recursive: true);
    await _scanAll(initial: true);
    for (final root in roots) {
      _watchTree(Directory(root));
    }
    _rescan = Timer.periodic(rescanInterval, (_) => _scanAll());
  }

  @override
  Future<void> stop() async {
    _running = false;
    _rescan?.cancel();
    for (final w in _watches) {
      await w.cancel();
    }
    _watches.clear();
    for (final t in _pending.values) {
      t.cancel();
    }
    _pending.clear();
  }

  void dispose() {
    stop();
    _changes.close();
  }

  // ---------------------------------------------------------------------------
  // Scanning

  static String idFor(String path) => toHex(sha1.convert(utf8.encode(path)).bytes).substring(0, 24);

  static MediaKind? kindFor(String path) {
    final ext = p.extension(path).toLowerCase();
    if (imageExt.contains(ext)) return MediaKind.image;
    if (videoExt.contains(ext)) return MediaKind.video;
    return null;
  }

  Future<void> _scanAll({bool initial = false}) async {
    final seen = <String>{};
    final added = <MediaItem>[];
    for (final root in roots) {
      final dir = Directory(root);
      if (!await dir.exists()) continue;
      try {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          final kind = kindFor(entity.path);
          if (kind == null) continue;
          if (p.basename(entity.path).startsWith('.')) continue;
          final id = idFor(entity.path);
          seen.add(id);
          if (_entries.containsKey(id)) continue;
          final item = await _describe(entity, id, kind);
          if (item == null) continue;
          _entries[id] = _Entry(item, entity.path);
          added.add(item);
        }
      } catch (e) {
        _log.fine('scan of $root failed: $e');
      }
    }
    final removed = _entries.keys.where((id) => !seen.contains(id)).toList();
    for (final id in removed) {
      _entries.remove(id);
      _thumbMemory.remove(id);
    }
    if (added.isNotEmpty || removed.isNotEmpty) {
      _rebuild();
      if (!initial && !_changes.isClosed) {
        _changes.add(MediaChange(added: added, removed: removed));
      }
    } else if (initial) {
      _rebuild();
    }
  }

  void _rebuild() {
    final list = _entries.values.map((e) => e.item).toList()
      ..sort((a, b) => b.takenAt.compareTo(a.takenAt));
    _sorted = list;
    _indexVersion++;
  }

  Future<MediaItem?> _describe(File file, String id, MediaKind kind) async {
    try {
      final stat = await file.stat();
      var width = 0;
      var height = 0;
      if (kind == MediaKind.image && stat.size > 0) {
        final head = await _readHead(file, 256 * 1024);
        final dims = ImageOps.dimensions(head);
        if (dims != null) {
          width = dims.width;
          height = dims.height;
        }
      }
      return MediaItem(
        id: id,
        kind: kind,
        name: p.basename(file.path),
        width: width,
        height: height,
        takenAt: stat.modified.toUtc(),
        size: stat.size,
        mime: _mimeFor(file.path, kind),
        album: p.basename(file.parent.path),
      );
    } catch (e) {
      _log.fine('cannot describe ${file.path}: $e');
      return null;
    }
  }

  static Future<Uint8List> _readHead(File file, int bytes) async {
    final raf = await file.open();
    try {
      return await raf.read(bytes);
    } finally {
      await raf.close();
    }
  }

  static String _mimeFor(String path, MediaKind kind) {
    final ext = p.extension(path).toLowerCase();
    return switch (ext) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.heic' || '.heif' => 'image/heic',
      '.bmp' => 'image/bmp',
      '.tif' || '.tiff' => 'image/tiff',
      '.mp4' || '.m4v' => 'video/mp4',
      '.mov' => 'video/quicktime',
      '.mkv' => 'video/x-matroska',
      '.webm' => 'video/webm',
      '.3gp' => 'video/3gpp',
      '.avi' => 'video/x-msvideo',
      _ => kind == MediaKind.video ? 'video/*' : 'image/*',
    };
  }

  // ---------------------------------------------------------------------------
  // Watching

  void _watchTree(Directory dir) {
    if (!dir.existsSync()) return;
    _watchDir(dir);
    try {
      for (final e in dir.listSync(recursive: true, followLinks: false)) {
        if (e is Directory && !p.basename(e.path).startsWith('.')) _watchDir(e);
      }
    } catch (_) {}
  }

  void _watchDir(Directory dir) {
    try {
      _watches.add(dir.watch().listen(_onEvent, onError: (Object e) {
        _log.fine('watch error on ${dir.path}: $e');
      }));
    } catch (e) {
      _log.fine('cannot watch ${dir.path}: $e');
    }
  }

  void _onEvent(FileSystemEvent event) {
    if (!_running) return;
    final path = event.path;
    if (event.isDirectory) {
      if (event is FileSystemCreateEvent) _watchDir(Directory(path));
      return;
    }
    if (event is FileSystemDeleteEvent || (event is FileSystemMoveEvent && event.destination == null)) {
      _removePath(path);
      return;
    }
    if (event is FileSystemMoveEvent && event.destination != null) {
      _removePath(path);
      _schedule(event.destination!);
      return;
    }
    if (kindFor(path) == null) return;
    _schedule(path);
  }

  /// Waits for the file to stop growing before indexing it (cameras write
  /// in several steps).
  void _schedule(String path) {
    _pending[path]?.cancel();
    _pending[path] = Timer(settleTime, () => _settle(path, -1));
  }

  Future<void> _settle(String path, int lastSize) async {
    final file = File(path);
    if (!await file.exists()) {
      _pending.remove(path);
      return;
    }
    final size = await file.length();
    if (size != lastSize) {
      _pending[path] = Timer(settleTime, () => _settle(path, size));
      return;
    }
    _pending.remove(path);
    final kind = kindFor(path);
    if (kind == null) return;
    final id = idFor(path);
    final existing = _entries[id];
    if (existing != null && existing.item.size == size) return;
    final item = await _describe(file, id, kind);
    if (item == null) return;
    _entries[id] = _Entry(item, path);
    _thumbMemory.remove(id);
    _rebuild();
    if (!_changes.isClosed) _changes.add(MediaChange(added: [item], removed: existing == null ? const [] : [id]));
  }

  void _removePath(String path) {
    final id = idFor(path);
    if (_entries.remove(id) == null) return;
    _thumbMemory.remove(id);
    _rebuild();
    if (!_changes.isClosed) _changes.add(MediaChange(removed: [id]));
  }

  // ---------------------------------------------------------------------------
  // MediaSource

  @override
  Future<MediaPage> index({int page = 0, int pageSize = 200, Set<MediaKind>? kinds, DateTime? since}) async {
    Iterable<MediaItem> items = _sorted;
    if (kinds != null && kinds.isNotEmpty) items = items.where((i) => kinds.contains(i.kind));
    if (since != null) items = items.where((i) => i.takenAt.isAfter(since));
    final all = items.toList();
    final start = page * pageSize;
    final end = (start + pageSize).clamp(0, all.length);
    final slice = start >= all.length ? <MediaItem>[] : all.sublist(start, end);
    return MediaPage(
      items: slice,
      total: all.length,
      nextPage: end < all.length ? page + 1 : null,
      indexVersion: _indexVersion,
    );
  }

  @override
  Future<MediaItem?> item(String id) async => _entries[id]?.item;

  @override
  Future<Uint8List?> thumbnail(String id, {int maxPx = 320}) async {
    final cached = _thumbMemory[id];
    if (cached != null) return cached;
    final entry = _entries[id];
    if (entry == null) return null;
    final cacheFile = File(p.join(cacheDir, 'thumb-$id-$maxPx.jpg'));
    if (await cacheFile.exists()) {
      final bytes = await cacheFile.readAsBytes();
      _remember(id, bytes);
      return bytes;
    }
    final bytes = await _render(entry, maxPx, thumbnailQuality);
    if (bytes != null) {
      _remember(id, bytes);
      try {
        await cacheFile.writeAsBytes(bytes, flush: true);
      } catch (_) {}
    }
    return bytes;
  }

  void _remember(String id, Uint8List bytes) {
    if (_thumbMemory.length > 300) _thumbMemory.remove(_thumbMemory.keys.first);
    _thumbMemory[id] = bytes;
  }

  @override
  Future<Uint8List?> preview(String id, {int maxPx = 1600}) async {
    final entry = _entries[id];
    if (entry == null) return null;
    return _render(entry, maxPx, 85);
  }

  Future<Uint8List?> _render(_Entry entry, int maxPx, int quality) async {
    if (entry.item.kind == MediaKind.video) return _videoFrame(entry.path, maxPx);
    try {
      final bytes = await File(entry.path).readAsBytes();
      return await ImageOps.resizeToJpeg(bytes, maxPx, quality: quality);
    } catch (e) {
      _log.fine('cannot render ${entry.path}: $e');
      return null;
    }
  }

  /// First frame of a video via ffmpeg when it is installed.
  Future<Uint8List?> _videoFrame(String path, int maxPx) async {
    try {
      final result = await Process.run('ffmpeg', [
        '-v', 'quiet', '-ss', '1', '-i', path, '-frames:v', '1',
        '-vf', 'scale=$maxPx:-2', '-f', 'image2', '-c:v', 'mjpeg', 'pipe:1',
      ], stdoutEncoding: null);
      if (result.exitCode != 0) return null;
      final out = result.stdout as List<int>;
      return out.isEmpty ? null : Uint8List.fromList(out);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> originalPath(String id) async => _entries[id]?.path;

  @override
  Future<List<String>> delete(List<String> ids) async {
    final deleted = <String>[];
    for (final id in ids) {
      final e = _entries[id];
      if (e == null) continue;
      try {
        await File(e.path).delete();
        deleted.add(id);
        _entries.remove(id);
        _thumbMemory.remove(id);
      } catch (err) {
        _log.fine('cannot delete ${e.path}: $err');
      }
    }
    if (deleted.isNotEmpty) {
      _rebuild();
      if (!_changes.isClosed) _changes.add(MediaChange(removed: deleted));
    }
    return deleted;
  }
}

class _Entry {
  _Entry(this.item, this.path);
  final MediaItem item;
  final String path;
}
