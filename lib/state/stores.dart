import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pepo_core/pepo_core.dart';

/// Atomic JSON file with debounced writes (write to `.tmp`, then rename).
class JsonFile {
  JsonFile(this.path, {this.debounce = const Duration(milliseconds: 150)});

  final String path;
  final Duration debounce;
  Object? _pending;
  Timer? _timer;
  Future<void>? _writing;

  Future<Object?> read() async {
    final f = File(path);
    if (!await f.exists()) return null;
    try {
      return jsonDecode(await f.readAsString());
    } catch (_) {
      // Corrupt file: keep a copy for diagnosis and start over.
      try {
        await f.rename('$path.corrupt');
      } catch (_) {}
      return null;
    }
  }

  /// Schedules a write; consecutive calls within [debounce] collapse.
  void write(Object value) {
    _pending = value;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(flush()));
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final value = _pending;
    if (value == null) return _writing ?? Future.value();
    _pending = null;
    final previous = _writing;
    _writing = () async {
      if (previous != null) await previous;
      final f = File(path);
      await f.parent.create(recursive: true);
      final tmp = File('$path.tmp');
      await tmp.writeAsString(jsonEncode(value), flush: true);
      try {
        await tmp.rename(path);
      } on FileSystemException {
        // Windows may refuse to replace an open file; fall back to copy.
        await tmp.copy(path);
        await tmp.delete();
      }
    }();
    await _writing;
  }
}

/// Paired devices (with PSK) in `devices.json` under the private data dir.
class JsonDeviceStore implements DeviceStore {
  JsonDeviceStore(String dataDir) : _file = JsonFile(p.join(dataDir, 'devices.json'));

  final JsonFile _file;
  Map<String, PairedDevice>? _cache;

  Future<Map<String, PairedDevice>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await _file.read();
    final map = <String, PairedDevice>{};
    if (raw is List) {
      for (final e in raw) {
        try {
          final d = PairedDevice.fromJson((e as Map).cast<String, dynamic>());
          map[d.deviceId] = d;
        } catch (_) {}
      }
    }
    return _cache = map;
  }

  void _persist(Map<String, PairedDevice> map) =>
      _file.write(map.values.map((d) => d.toJson()).toList());

  @override
  Future<List<PairedDevice>> all() async => (await _load()).values.toList();

  @override
  Future<PairedDevice?> find(String deviceId) async => (await _load())[deviceId];

  @override
  Future<void> save(PairedDevice device) async {
    final map = await _load();
    map[device.deviceId] = device;
    _persist(map);
  }

  @override
  Future<void> remove(String deviceId) async {
    final map = await _load();
    map.remove(deviceId);
    _persist(map);
  }

  Future<void> flush() => _file.flush();
}

/// Resumable transfers in `transfers.json`.
class JsonTransferStore implements TransferStore {
  JsonTransferStore(String dataDir) : _file = JsonFile(p.join(dataDir, 'transfers.json'));

  final JsonFile _file;
  Map<int, TransferRecord>? _cache;

  Future<Map<int, TransferRecord>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await _file.read();
    final map = <int, TransferRecord>{};
    if (raw is List) {
      for (final e in raw) {
        try {
          final r = TransferRecord.fromJson((e as Map).cast<String, dynamic>());
          map[r.id] = r;
        } catch (_) {}
      }
    }
    return _cache = map;
  }

  void _persist(Map<int, TransferRecord> map) =>
      _file.write(map.values.map((r) => r.toJson()).toList());

  @override
  Future<void> save(TransferRecord record) async {
    final map = await _load();
    // Only paused/queued records matter across restarts.
    if (record.state == TransferState.paused || record.state == TransferState.queued) {
      map[record.id] = record.copy();
    } else {
      map.remove(record.id);
    }
    _persist(map);
  }

  @override
  Future<void> remove(int id) async {
    final map = await _load();
    if (map.remove(id) != null) _persist(map);
  }

  @override
  Future<List<TransferRecord>> all() async => (await _load()).values.map((r) => r.copy()).toList();

  @override
  Future<TransferRecord?> findResumable({
    required String deviceId,
    required String name,
    required int size,
    DateTime? modifiedAt,
  }) async {
    for (final r in (await _load()).values) {
      if (r.deviceId == deviceId &&
          r.direction == TransferDirection.receive &&
          r.name == name &&
          r.size == size &&
          r.state == TransferState.paused &&
          r.tempPath != null &&
          (modifiedAt == null || r.modifiedAt == null || r.modifiedAt == modifiedAt)) {
        return r.copy();
      }
    }
    return null;
  }
}

/// Per-device gallery item states in `gallery/<deviceId>.json`:
/// `{"seenUntil": <ISO-8601>, "items": [...]}`. Files written before the
/// watermark existed are a bare list and still load.
class JsonMediaStateStore implements MediaStateStore {
  JsonMediaStateStore(String dataDir) : _dir = p.join(dataDir, 'gallery');

  final String _dir;
  final Map<String, JsonFile> _files = {};
  final Map<String, Map<String, MediaItemState>> _cache = {};
  final Map<String, DateTime?> _seenUntil = {};

  JsonFile _fileFor(String deviceId) =>
      _files.putIfAbsent(deviceId, () => JsonFile(p.join(_dir, '$deviceId.json')));

  @override
  Future<Map<String, MediaItemState>> load(String deviceId) async {
    final cached = _cache[deviceId];
    if (cached != null) return Map.of(cached);
    final raw = await _fileFor(deviceId).read();
    Object? items = raw;
    DateTime? seenUntil;
    if (raw is Map) {
      items = raw['items'];
      final s = raw['seenUntil'];
      if (s is String) seenUntil = DateTime.tryParse(s);
    }
    final map = <String, MediaItemState>{};
    if (items is List) {
      for (final e in items) {
        try {
          final s = MediaItemState.fromJson((e as Map).cast<String, dynamic>());
          map[s.id] = s;
        } catch (_) {}
      }
    }
    _cache[deviceId] = map;
    _seenUntil[deviceId] = seenUntil;
    return Map.of(map);
  }

  Future<void> _ensureLoaded(String deviceId) async {
    if (!_cache.containsKey(deviceId)) await load(deviceId);
  }

  void _write(String deviceId) {
    _fileFor(deviceId).write({
      'seenUntil': ?_seenUntil[deviceId]?.toUtc().toIso8601String(),
      'items': _cache[deviceId]!.values.map((s) => s.toJson()).toList(),
    });
  }

  @override
  Future<void> save(String deviceId, MediaItemState state) async {
    await _ensureLoaded(deviceId);
    _cache[deviceId]![state.id] = state;
    _write(deviceId);
  }

  @override
  Future<DateTime?> loadSeenUntil(String deviceId) async {
    await _ensureLoaded(deviceId);
    return _seenUntil[deviceId];
  }

  @override
  Future<void> saveSeenUntil(String deviceId, DateTime until) async {
    await _ensureLoaded(deviceId);
    _seenUntil[deviceId] = until;
    _write(deviceId);
  }

  @override
  Future<void> removeDevice(String deviceId) async {
    _cache.remove(deviceId);
    _seenUntil.remove(deviceId);
    _files.remove(deviceId);
    final f = File(p.join(_dir, '$deviceId.json'));
    if (await f.exists()) await f.delete();
  }
}

/// Activity/history entries in `history.json` (most recent first, capped).
class JsonListStore<T> {
  JsonListStore(String path, {required this.encode, required this.decode, this.cap = 300})
    : _file = JsonFile(path, debounce: const Duration(milliseconds: 400));

  final JsonFile _file;
  final Map<String, dynamic> Function(T) encode;
  final T Function(Map<String, dynamic>) decode;
  final int cap;

  Future<List<T>> load() async {
    final raw = await _file.read();
    if (raw is! List) return [];
    final out = <T>[];
    for (final e in raw) {
      try {
        out.add(decode((e as Map).cast<String, dynamic>()));
      } catch (_) {}
    }
    return out;
  }

  void save(List<T> items) => _file.write(items.take(cap).map(encode).toList());
}
