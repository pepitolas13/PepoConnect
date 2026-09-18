import '../protocol/models.dart';

/// Lifecycle of a transfer.
enum TransferState {
  queued,
  active,
  paused,
  done,
  failed,
  cancelled;

  bool get isTerminal => this == done || this == failed || this == cancelled;
}

/// Why a transfer stopped before completion.
enum CancelReason { pause, abort }

/// One file moving between this device and a peer. Mutable; the engine owns
/// it and publishes snapshots through [TransferEvent]s.
class TransferRecord {
  TransferRecord({
    required this.id,
    required this.deviceId,
    required this.direction,
    required this.name,
    required this.size,
    required this.mime,
    required this.createdAt,
    this.modifiedAt,
    this.mediaKind,
    this.sourceId,
    this.sourcePath,
    this.tempPath,
    this.finalPath,
    this.state = TransferState.queued,
    this.bytesDone = 0,
    this.bytesPerSecond = 0,
    this.error,
    this.hash,
    this.fast = false,
  });

  final int id;
  final String deviceId;
  final TransferDirection direction;
  final String name;
  final int size;
  final String mime;
  final DateTime createdAt;
  final DateTime? modifiedAt;
  final MediaKind? mediaKind;

  /// Gallery id on the source device, when the file is a media item.
  final String? sourceId;

  /// Local path being sent (outgoing).
  final String? sourcePath;

  /// `.pepopart` being written (incoming).
  String? tempPath;

  /// Final path once completed.
  String? finalPath;
  TransferState state;
  int bytesDone;
  double bytesPerSecond;
  String? error;
  String? hash;
  DateTime? finishedAt;

  /// Moved (or moving) on the fast lane.
  bool fast;

  bool get isIncoming => direction == TransferDirection.receive;
  double get progress => size == 0 ? 1 : bytesDone / size;
  int get bytesLeft => size - bytesDone;
  Duration? get eta => bytesPerSecond <= 0
      ? null
      : Duration(milliseconds: (bytesLeft / bytesPerSecond * 1000).round());

  TransferRecord copy() => TransferRecord(
    id: id,
    deviceId: deviceId,
    direction: direction,
    name: name,
    size: size,
    mime: mime,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
    mediaKind: mediaKind,
    sourceId: sourceId,
    sourcePath: sourcePath,
    tempPath: tempPath,
    finalPath: finalPath,
    state: state,
    bytesDone: bytesDone,
    bytesPerSecond: bytesPerSecond,
    error: error,
    hash: hash,
    fast: fast,
  )..finishedAt = finishedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceId': deviceId,
    'direction': direction.name,
    'name': name,
    'size': size,
    'mime': mime,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'modifiedAt': ?modifiedAt?.toUtc().toIso8601String(),
    'mediaKind': ?mediaKind?.code,
    'sourceId': ?sourceId,
    'sourcePath': ?sourcePath,
    'tempPath': ?tempPath,
    'finalPath': ?finalPath,
    'state': state.name,
    'bytesDone': bytesDone,
    'bytesPerSecond': bytesPerSecond,
    'error': ?error,
    'hash': ?hash,
    'finishedAt': ?finishedAt?.toUtc().toIso8601String(),
    if (fast) 'fast': true,
  };

  factory TransferRecord.fromJson(Map<String, dynamic> j) => TransferRecord(
    id: j['id'] as int,
    deviceId: j['deviceId'] as String,
    direction: TransferDirection.values.byName(j['direction'] as String),
    name: j['name'] as String,
    size: j['size'] as int,
    mime: j['mime'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    modifiedAt: j['modifiedAt'] == null ? null : DateTime.parse(j['modifiedAt'] as String),
    mediaKind: j['mediaKind'] == null ? null : MediaKind.fromCode(j['mediaKind'] as String),
    sourceId: j['sourceId'] as String?,
    sourcePath: j['sourcePath'] as String?,
    tempPath: j['tempPath'] as String?,
    finalPath: j['finalPath'] as String?,
    state: TransferState.values.byName(j['state'] as String),
    bytesDone: j['bytesDone'] as int? ?? 0,
    bytesPerSecond: (j['bytesPerSecond'] as num?)?.toDouble() ?? 0,
    error: j['error'] as String?,
    hash: j['hash'] as String?,
    fast: j['fast'] as bool? ?? false,
  )..finishedAt = j['finishedAt'] == null ? null : DateTime.parse(j['finishedAt'] as String);

  @override
  String toString() => 'Transfer#$id(${direction.name} $name ${state.name} $bytesDone/$size)';
}

/// Published whenever a transfer changes. [record] is a snapshot.
class TransferEvent {
  TransferEvent(this.record, {this.progressOnly = false, this.removed = false});
  final TransferRecord record;

  /// True for throttled progress ticks (no state change).
  final bool progressOnly;

  /// True when [record] was dropped without finishing: a paused transfer that
  /// was superseded by its own resumption under another id.
  final bool removed;
}

/// Persists transfer records so paused/interrupted transfers can resume.
abstract class TransferStore {
  Future<void> save(TransferRecord record);
  Future<void> remove(int id);
  Future<List<TransferRecord>> all();

  /// An incoming transfer from [deviceId] whose partial file can be resumed.
  Future<TransferRecord?> findResumable({
    required String deviceId,
    required String name,
    required int size,
    DateTime? modifiedAt,
  });
}

/// In-memory store (tests, or when the platform provides none).
class MemoryTransferStore implements TransferStore {
  final Map<int, TransferRecord> _records = {};

  @override
  Future<void> save(TransferRecord record) async => _records[record.id] = record.copy();

  @override
  Future<void> remove(int id) async => _records.remove(id);

  @override
  Future<List<TransferRecord>> all() async => _records.values.map((r) => r.copy()).toList();

  @override
  Future<TransferRecord?> findResumable({
    required String deviceId,
    required String name,
    required int size,
    DateTime? modifiedAt,
  }) async {
    for (final r in _records.values) {
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
