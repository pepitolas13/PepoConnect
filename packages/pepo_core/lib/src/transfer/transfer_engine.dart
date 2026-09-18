import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../native/native_bulk.dart';
import '../native/native_route.dart';
import '../net/frame.dart';
import '../net/peer_connection.dart';
import '../protocol/message_types.dart';
import '../protocol/models.dart';
import 'chunked_file_reader.dart';
import 'name_sanitizer.dart';
import 'transfer_record.dart';

final _log = Logger('pepo.transfer');

/// Gives the engine access to the channels of a peer. Implemented by the
/// session layer.
abstract class ChannelProvider {
  /// The authenticated control channel of [deviceId], or null if offline.
  PeerConnection? controlFor(String deviceId);

  /// An idle bulk channel to [deviceId] (opens one if needed).
  Future<PeerConnection> acquireBulk(String deviceId);

  /// Returns a bulk channel to the pool. [broken] channels are discarded.
  void releaseBulk(String deviceId, PeerConnection conn, {bool broken = false});

  /// How to reach [deviceId] on the fast lane (Rust engine) right now, or
  /// null when either side cannot use it.
  NativeRoute? nativeRouteFor(String deviceId) => null;
}

/// Directory where an incoming file should be stored.
typedef DestinationResolver = Future<String> Function(String deviceId, FileOffer offer);

/// Whether an incoming offer is accepted. Defaults to accepting everything
/// from paired devices.
typedef OfferPolicy = Future<bool> Function(String deviceId, FileOffer offer);

/// Moves files between paired devices with resume, integrity check and
/// backpressure. One instance serves all peers.
class TransferEngine {
  TransferEngine({
    required this.channels,
    required this.store,
    required this.destination,
    OfferPolicy? policy,
    this.maxActivePerDevice = 3,
    this.chunkSize = 256 * 1024,
    this.progressInterval = const Duration(milliseconds: 100),
  }) : policy = policy ?? ((_, _) async => true),
       _nextId = Random().nextInt(1 << 30) + 1;

  final ChannelProvider channels;
  final TransferStore store;
  final DestinationResolver destination;
  final OfferPolicy policy;
  final int maxActivePerDevice;
  final int chunkSize;
  final Duration progressInterval;

  final _events = StreamController<TransferEvent>.broadcast();
  final Map<int, _Outgoing> _outgoing = {};
  final Map<int, _Incoming> _incoming = {};
  final Map<String, List<_Outgoing>> _queues = {};
  final Map<String, int> _activeOutgoing = {};
  final Map<PeerConnection, StreamSubscription<DataChunk>> _bulkSubs = {};

  /// Devices whose fast lane failed to connect: use TLS until this time.
  final Map<String, DateTime> _fastLaneBlockedUntil = {};
  int _nextId;
  bool _disposed = false;

  /// Fast lane route for [deviceId], unless it is temporarily blocked.
  NativeRoute? _fastRoute(String deviceId) {
    final until = _fastLaneBlockedUntil[deviceId];
    if (until != null) {
      if (DateTime.now().isBefore(until)) return null;
      _fastLaneBlockedUntil.remove(deviceId);
    }
    return channels.nativeRouteFor(deviceId);
  }

  /// Every state change and throttled progress tick.
  Stream<TransferEvent> get events => _events.stream;

  /// Snapshots of all transfers known to the engine (active, queued, recent).
  List<TransferRecord> get transfers => [
    ..._outgoing.values.map((o) => o.record.copy()),
    ..._incoming.values.map((i) => i.record.copy()),
  ];

  TransferRecord? find(int id) => (_outgoing[id]?.record ?? _incoming[id]?.record)?.copy();

  // ---------------------------------------------------------------------------
  // Sending

  /// Queues [path] to be sent to [deviceId]. Returns the record snapshot.
  Future<TransferRecord> send({
    required String deviceId,
    required String path,
    String? name,
    String? mime,
    MediaKind? mediaKind,
    String? sourceId,
  }) async {
    final file = File(path);
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw FileSystemException('not a file', path);
    }
    final record = TransferRecord(
      id: _allocateId(),
      deviceId: deviceId,
      direction: TransferDirection.send,
      name: NameSanitizer.sanitize(name ?? p.basename(path)),
      size: stat.size,
      mime: mime ?? _guessMime(path),
      createdAt: DateTime.now(),
      modifiedAt: stat.modified.toUtc(),
      mediaKind: mediaKind,
      sourceId: sourceId,
      sourcePath: path,
    );
    final out = _Outgoing(record);
    _outgoing[record.id] = out;
    _queues.putIfAbsent(deviceId, () => []).add(out);
    await store.save(record);
    _emit(record);
    _pump(deviceId);
    return record.copy();
  }

  /// Re-queues every paused outgoing transfer to [deviceId] (after a reconnect).
  Future<void> resumePending(String deviceId) async {
    for (final r in await store.all()) {
      if (r.deviceId == deviceId && r.direction == TransferDirection.send) {
        await _requeue(r);
      }
    }
  }

  /// Re-queues one paused outgoing transfer under the same id, so the receiver
  /// continues from the bytes it kept. Returns null when [id] is not a paused
  /// outgoing transfer, or its source file is gone (the record is dropped).
  Future<TransferRecord?> resume(int id) async {
    final live = _outgoing[id]?.record;
    final r = live ?? (await store.all()).where((r) => r.id == id).firstOrNull;
    return r == null ? null : _requeue(r);
  }

  Future<TransferRecord?> _requeue(TransferRecord stored) async {
    final r = _outgoing[stored.id]?.record ?? stored;
    if (r.direction != TransferDirection.send ||
        r.state != TransferState.paused ||
        r.sourcePath == null) {
      return null;
    }
    if (!await File(r.sourcePath!).exists()) {
      _outgoing.remove(r.id);
      await store.remove(r.id);
      r.state = TransferState.failed;
      r.error = 'source file missing';
      _emit(r);
      return null;
    }
    r.state = TransferState.queued;
    r.bytesDone = 0;
    r.bytesPerSecond = 0;
    r.error = null;
    final out = _Outgoing(r);
    _outgoing[r.id] = out;
    _queues.putIfAbsent(r.deviceId, () => []).add(out);
    await store.save(r);
    _emit(r);
    _pump(r.deviceId);
    return r.copy();
  }

  void _pump(String deviceId) {
    final queue = _queues[deviceId];
    if (queue == null) return;
    while (queue.isNotEmpty && (_activeOutgoing[deviceId] ?? 0) < maxActivePerDevice) {
      final control = channels.controlFor(deviceId);
      if (control == null) return; // offline: stays queued until reconnect
      final out = queue.removeAt(0);
      _activeOutgoing[deviceId] = (_activeOutgoing[deviceId] ?? 0) + 1;
      unawaited(
        _runOutgoing(out, control).whenComplete(() {
          _activeOutgoing[deviceId] = (_activeOutgoing[deviceId] ?? 1) - 1;
          _pump(deviceId);
        }),
      );
    }
  }

  /// Called by the session layer when [deviceId] came online.
  void onDeviceConnected(String deviceId) => _pump(deviceId);

  /// Called by the session layer when the control channel of [deviceId]
  /// dropped: active transfers become resumable.
  Future<void> onDeviceDisconnected(String deviceId) async {
    for (final out in _outgoing.values.where((o) => o.record.deviceId == deviceId)) {
      if (out.record.state == TransferState.active) {
        out.cancel.cancel();
        out.pauseOnDrop = true;
        out.nativeJob?.cancel();
      }
    }
    for (final inc in _incoming.values.where((i) => i.record.deviceId == deviceId).toList()) {
      if (!inc.record.state.isTerminal) {
        await _pauseIncoming(inc);
      }
    }
  }

  Future<void> _runOutgoing(_Outgoing out, PeerConnection control) async {
    final r = out.record;
    final route = _fastRoute(r.deviceId);
    final offer = FileOffer(
      transferId: r.id,
      name: r.name,
      size: r.size,
      mime: r.mime,
      modifiedAt: r.modifiedAt,
      mediaKind: r.mediaKind,
      sourceId: r.sourceId,
      fast: route != null,
    );
    ControlMessage reply;
    try {
      reply = await control.request(
        MsgType.fileOffer,
        data: offer.toJson(),
        timeout: const Duration(seconds: 90),
      );
    } on PeerError catch (e) {
      return _finishOutgoing(
        out,
        e.code == ErrorCode.timeout ? TransferState.paused : TransferState.failed,
        error: e.message,
      );
    } on PeerClosedException {
      return _finishOutgoing(out, TransferState.paused, error: 'connection lost');
    }
    if (reply.type == MsgType.fileReject) {
      return _finishOutgoing(
        out,
        TransferState.failed,
        error: reply.optStr('reason') ?? 'rejected',
      );
    }
    if (reply.type != MsgType.fileAccept) {
      return _finishOutgoing(out, TransferState.failed, error: 'unexpected ${reply.type}');
    }
    var offset = reply.optInt('offset') ?? 0;
    if (offset > r.size) offset = 0;
    if (offset > 0) {
      final theirTail = reply.optStr('tailHash') ?? '';
      final myTail = await ChunkedFileReader.tailHash(r.sourcePath!, offset);
      if (theirTail.isEmpty || theirTail != myTail) {
        _log.fine('resume tail mismatch for ${r.name}, restarting from 0');
        offset = 0;
      }
    }
    if (out.cancel.isCancelled) {
      return _finishOutgoing(out, out.pauseOnDrop ? TransferState.paused : TransferState.cancelled);
    }
    if (route != null && reply.flag('fast')) {
      return _runOutgoingFast(out, control, route, offset);
    }

    PeerConnection bulk;
    try {
      bulk = await channels.acquireBulk(r.deviceId);
    } catch (e) {
      return _finishOutgoing(out, TransferState.paused, error: 'no bulk channel: $e');
    }
    r.state = TransferState.active;
    r.bytesDone = offset;
    _emit(r);
    final reader = ChunkedFileReader(
      path: r.sourcePath!,
      transferId: r.id,
      startOffset: offset,
      chunkSize: chunkSize,
    );
    final progress = _ProgressMeter(this, r, offset);
    var broken = false;
    try {
      await bulk.addStream(
        reader.frames(cancel: out.cancel, onProgress: (sent) => progress.update(offset + sent)),
      );
    } catch (e) {
      broken = true;
      _log.fine('bulk stream failed for ${r.name}: $e');
    } finally {
      // A cancelled transfer may leave megabytes in the socket buffer; it is
      // cheaper to drop the channel than to drain it.
      final dropped = out.cancel.isCancelled && r.size - r.bytesDone > 8 * 1024 * 1024;
      channels.releaseBulk(r.deviceId, bulk, broken: broken || dropped);
    }
    if (out.cancel.isCancelled) {
      return _finishOutgoing(out, out.pauseOnDrop ? TransferState.paused : TransferState.cancelled);
    }
    if (broken || reader.bytesSent != r.size - offset) {
      return _finishOutgoing(out, TransferState.paused, error: 'connection lost');
    }
    return _ackOutgoing(out, control, reader.hashHex, offset);
  }

  /// Sends the file through the Rust engine (AES-GCM over TCP, hashed there)
  /// and confirms it over the control channel like the TLS path does.
  Future<void> _runOutgoingFast(
    _Outgoing out,
    PeerConnection control,
    NativeRoute route,
    int offset,
  ) async {
    final r = out.record;
    r.state = TransferState.active;
    r.bytesDone = offset;
    r.fast = true;
    _emit(r);
    final progress = _ProgressMeter(this, r, offset);
    final job = route.native.send(
      sid: route.sid,
      key: route.key,
      transferId: r.id,
      path: r.sourcePath!,
      offset: offset,
      host: route.weConnect ? route.host : null,
      port: route.port,
      onProgress: progress.update,
    );
    out.nativeJob = job;
    if (out.cancel.isCancelled) job.cancel();
    final NativeBulkResult result;
    try {
      result = await job.done;
    } on NativeBulkException catch (e) {
      out.nativeJob = null;
      if (out.cancel.isCancelled) {
        return _finishOutgoing(
          out,
          out.pauseOnDrop ? TransferState.paused : TransferState.cancelled,
        );
      }
      if (r.bytesDone <= offset && _isConnectFailure(e.message)) {
        // The fast lane cannot be reached (firewall, NAT): fall back to the
        // TLS channels for a while and retry this file right away.
        _log.warning('fast lane to ${r.deviceId} unreachable (${e.message}); using TLS');
        _fastLaneBlockedUntil[r.deviceId] = DateTime.now().add(const Duration(minutes: 10));
        await _finishOutgoing(out, TransferState.paused, error: 'fast lane: ${e.message}');
        unawaited(resume(r.id));
        return;
      }
      return _finishOutgoing(out, TransferState.paused, error: 'fast lane: ${e.message}');
    }
    out.nativeJob = null;
    if (out.cancel.isCancelled) {
      return _finishOutgoing(out, out.pauseOnDrop ? TransferState.paused : TransferState.cancelled);
    }
    if (result.bytes != r.size - offset) {
      return _finishOutgoing(out, TransferState.paused, error: 'connection lost');
    }
    return _ackOutgoing(out, control, result.hashHex, offset);
  }

  static bool _isConnectFailure(String message) =>
      message.startsWith('connect ') ||
      message.startsWith('resolve ') ||
      message.startsWith('waiting for peer') ||
      message.startsWith('peer did not connect');

  Future<void> _ackOutgoing(_Outgoing out, PeerConnection control, String hash, int offset) async {
    final r = out.record;
    ControlMessage ack;
    try {
      ack = await control.request(
        MsgType.fileDone,
        data: {'x': r.id, 'hash': hash, 'from': offset},
        timeout: const Duration(seconds: 120),
      );
    } on PeerError catch (e) {
      return _finishOutgoing(out, TransferState.failed, error: e.message);
    } on PeerClosedException {
      return _finishOutgoing(out, TransferState.paused, error: 'connection lost');
    }
    if (ack.flag('ok')) {
      r.hash = hash;
      r.finalPath = ack.optStr('storedName');
      r.bytesDone = r.size;
      return _finishOutgoing(out, TransferState.done);
    }
    return _finishOutgoing(out, TransferState.failed, error: ack.optStr('reason') ?? 'rejected');
  }

  Future<void> _finishOutgoing(_Outgoing out, TransferState state, {String? error}) async {
    final r = out.record;
    // A transfer the user cancelled (or that lost its link) may also trip an
    // error on the way out, e.g. the receiver already dropped it when the
    // final ack was requested. Report what the user did, not the symptom.
    if (out.cancel.isCancelled && state != TransferState.done) {
      state = out.pauseOnDrop ? TransferState.paused : TransferState.cancelled;
      if (state == TransferState.cancelled) error = null;
    }
    r.state = state;
    r.error = error;
    r.bytesPerSecond = 0;
    if (state.isTerminal) r.finishedAt = DateTime.now();
    if (state == TransferState.done || state == TransferState.cancelled) {
      await store.remove(r.id);
    } else {
      await store.save(r);
    }
    _emit(r);
    if (state.isTerminal) _outgoing.remove(r.id);
    out.done.complete();
  }

  // ---------------------------------------------------------------------------
  // Receiving

  /// Routes transfer-related control messages. Returns true when handled.
  Future<bool> handleControl(String deviceId, PeerConnection control, ControlMessage m) async {
    switch (m.type) {
      case MsgType.fileOffer:
        await _onOffer(deviceId, control, m);
        return true;
      case MsgType.fileDone:
        await _onDone(deviceId, control, m);
        return true;
      case MsgType.transferCancel:
        await _onRemoteCancel(deviceId, m);
        return true;
      default:
        return false;
    }
  }

  /// Listens for data chunks on a bulk channel (both ends of every bulk
  /// connection must call this).
  void attachBulk(String deviceId, PeerConnection bulk) {
    if (_bulkSubs.containsKey(bulk)) return;
    late StreamSubscription<DataChunk> sub;
    sub = bulk.data.listen(
      (chunk) => _onChunk(chunk, sub),
      onDone: () => _bulkSubs.remove(bulk),
      onError: (Object e) => _bulkSubs.remove(bulk),
    );
    _bulkSubs[bulk] = sub;
  }

  Future<void> _onOffer(String deviceId, PeerConnection control, ControlMessage m) async {
    final FileOffer offer;
    try {
      offer = FileOffer.fromJson(m.data);
    } catch (e) {
      control.respondError(m.reqId, ErrorCode.badRequest, 'bad offer');
      return;
    }
    if (offer.size < 0) {
      control.respondError(m.reqId, ErrorCode.badRequest, 'bad size');
      return;
    }
    if (!await policy(deviceId, offer)) {
      control.respond(
        m.reqId,
        MsgType.fileReject,
        data: {'x': offer.transferId, 'reason': 'rejected'},
      );
      return;
    }
    final String dir;
    try {
      dir = await destination(deviceId, offer);
      await Directory(dir).create(recursive: true);
    } catch (e) {
      control.respondError(m.reqId, ErrorCode.io, 'cannot create destination: $e');
      return;
    }
    final name = NameSanitizer.sanitize(offer.name);
    final record = TransferRecord(
      id: offer.transferId,
      deviceId: deviceId,
      direction: TransferDirection.receive,
      name: name,
      size: offer.size,
      mime: offer.mime,
      createdAt: DateTime.now(),
      modifiedAt: offer.modifiedAt,
      mediaKind: offer.mediaKind,
      sourceId: offer.sourceId,
    );

    // Resume?
    var offset = 0;
    var tailHash = '';
    String? tempPath;
    if (offer.resumable) {
      final previous = await store.findResumable(
        deviceId: deviceId,
        name: name,
        size: offer.size,
        modifiedAt: offer.modifiedAt,
      );
      if (previous?.tempPath != null) {
        final part = File(previous!.tempPath!);
        if (await part.exists()) {
          final len = await part.length();
          if (len > 0 && len <= offer.size) {
            offset = len;
            tailHash = await ChunkedFileReader.tailHash(part.path, offset);
            tempPath = part.path;
          }
        }
        await store.remove(previous.id);
        if (previous.id != record.id) _emit(previous, removed: true);
      }
    }
    tempPath ??= NameSanitizer.uniquePath(dir, '$name.pepopart');
    record.tempPath = tempPath;
    record.bytesDone = offset;
    record.state = TransferState.active;
    // A re-offer of the same transfer replaces whatever was still waiting.
    final stale = _incoming.remove(record.id);
    if (stale != null) await stale.close();
    final route = offer.fast ? _fastRoute(deviceId) : null;
    if (route != null) {
      await _acceptFast(control, m, record, route, dir, offset, tailHash, offer.size);
      return;
    }
    final RandomAccessFile raf;
    try {
      raf = await File(tempPath).open(mode: offset > 0 ? FileMode.append : FileMode.write);
      if (offset > 0) await raf.setPosition(offset);
    } catch (e) {
      control.respondError(m.reqId, ErrorCode.io, 'cannot open destination: $e');
      return;
    }
    final inc = _Incoming(record, raf, dir, startOffset: offset);
    _incoming[record.id] = inc;
    await store.save(record);
    _emit(record);
    control.respond(
      m.reqId,
      MsgType.fileAccept,
      data: {'x': record.id, 'offset': offset, if (offset > 0) 'tailHash': tailHash},
    );
    if (offer.size == 0) inc.markReceived();
  }

  /// Receives on the fast lane: the Rust engine writes the temp file and
  /// hashes it; the control channel still carries accept/done/ack.
  Future<void> _acceptFast(
    PeerConnection control,
    ControlMessage m,
    TransferRecord record,
    NativeRoute route,
    String dir,
    int offset,
    String tailHash,
    int size,
  ) async {
    record.fast = true;
    final inc = _Incoming(record, null, dir, startOffset: offset);
    _incoming[record.id] = inc;
    await store.save(record);
    _emit(record);
    final meter = _ProgressMeter(this, record, offset);
    final job = route.native.receive(
      sid: route.sid,
      key: route.key,
      transferId: record.id,
      path: record.tempPath!,
      offset: offset,
      size: size,
      host: route.weConnect ? route.host : null,
      port: route.port,
      onProgress: meter.update,
    );
    inc.nativeJob = job;
    unawaited(
      job.done.then(
        (res) {
          inc.nativeHash = res.hashHex;
          record.bytesDone = offset + res.bytes;
          inc.markReceived();
        },
        onError: (Object e) async {
          inc.nativeJob = null;
          if (inc.isClosed || record.state.isTerminal) return;
          final message = e is NativeBulkException ? e.message : '$e';
          if (e is NativeBulkException && e.isCancelled) return;
          if (message.contains('hash') ||
              message.contains('order') ||
              message.contains('announced')) {
            await _failIncoming(inc, message);
          } else {
            _log.fine('fast lane receive of ${record.name} stopped: $message');
            await _pauseIncoming(inc);
          }
        },
      ),
    );
    control.respond(
      m.reqId,
      MsgType.fileAccept,
      data: {'x': record.id, 'offset': offset, if (offset > 0) 'tailHash': tailHash, 'fast': true},
    );
  }

  void _onChunk(DataChunk chunk, StreamSubscription<DataChunk> sub) {
    final inc = _incoming[chunk.transferId];
    if (inc == null || inc.record.state != TransferState.active) return;
    sub.pause(inc.write(chunk, this));
  }

  Future<void> _onDone(String deviceId, PeerConnection control, ControlMessage m) async {
    final id = m.integer('x');
    final inc = _incoming[id];
    if (inc == null || inc.record.deviceId != deviceId) {
      control.respondError(m.reqId, ErrorCode.notFound, 'unknown transfer $id');
      return;
    }
    final r = inc.record;
    try {
      await inc.received.future.timeout(const Duration(seconds: 60));
    } on TimeoutException {
      await _pauseIncoming(inc);
      control.respond(
        m.reqId,
        MsgType.fileAck,
        data: {'x': id, 'ok': false, 'reason': 'incomplete: ${r.bytesDone}/${r.size}'},
      );
      return;
    }
    await inc.close();
    final theirHash = m.optStr('hash') ?? '';
    final myHash = inc.nativeHash ?? inc.hasher.hashHex;
    if (!sameHash(theirHash, myHash)) {
      _log.warning('hash mismatch for ${r.name}: $theirHash vs $myHash');
      await _failIncoming(inc, 'hash mismatch');
      control.respond(
        m.reqId,
        MsgType.fileAck,
        data: {'x': id, 'ok': false, 'reason': 'hash mismatch'},
      );
      return;
    }
    final finalPath = NameSanitizer.uniquePath(inc.directory, r.name);
    try {
      await File(r.tempPath!).rename(finalPath);
      if (r.modifiedAt != null) {
        try {
          await File(finalPath).setLastModified(r.modifiedAt!.toLocal());
        } catch (_) {
          // Not fatal.
        }
      }
    } catch (e) {
      await _failIncoming(inc, 'cannot finalize: $e');
      control.respond(m.reqId, MsgType.fileAck, data: {'x': id, 'ok': false, 'reason': 'io'});
      return;
    }
    r.finalPath = finalPath;
    r.hash = myHash;
    r.state = TransferState.done;
    r.bytesPerSecond = 0;
    r.finishedAt = DateTime.now();
    await store.remove(r.id);
    _incoming.remove(r.id);
    _emit(r);
    control.respond(
      m.reqId,
      MsgType.fileAck,
      data: {'x': id, 'ok': true, 'storedName': p.basename(finalPath)},
    );
  }

  Future<void> _onRemoteCancel(String deviceId, ControlMessage m) async {
    final id = m.integer('x');
    final reason = m.optStr('reason') == 'pause' ? CancelReason.pause : CancelReason.abort;
    final out = _outgoing[id];
    if (out != null && out.record.deviceId == deviceId) {
      out.pauseOnDrop = reason == CancelReason.pause;
      out.cancel.cancel();
      out.nativeJob?.cancel();
      if (out.record.state == TransferState.queued) {
        _queues[deviceId]?.remove(out);
        await _finishOutgoing(
          out,
          reason == CancelReason.pause ? TransferState.paused : TransferState.cancelled,
        );
      }
      return;
    }
    final inc = _incoming[id];
    if (inc != null && inc.record.deviceId == deviceId) {
      if (reason == CancelReason.pause) {
        await _pauseIncoming(inc);
      } else {
        await _cancelIncoming(inc);
      }
    }
  }

  /// Cancels or pauses a transfer started on either side.
  Future<void> cancel(int id, {CancelReason reason = CancelReason.abort}) async {
    final out = _outgoing[id];
    if (out != null) {
      final r = out.record;
      channels
          .controlFor(r.deviceId)
          ?.send(MsgType.transferCancel, data: {'x': id, 'reason': reason.name});
      out.pauseOnDrop = reason == CancelReason.pause;
      out.cancel.cancel();
      out.nativeJob?.cancel();
      if (r.state == TransferState.queued) {
        _queues[r.deviceId]?.remove(out);
        await _finishOutgoing(
          out,
          reason == CancelReason.pause ? TransferState.paused : TransferState.cancelled,
        );
      }
      return;
    }
    final inc = _incoming[id];
    if (inc != null) {
      channels
          .controlFor(inc.record.deviceId)
          ?.send(MsgType.transferCancel, data: {'x': id, 'reason': reason.name});
      if (reason == CancelReason.pause) {
        await _pauseIncoming(inc);
      } else {
        await _cancelIncoming(inc);
      }
    }
  }

  Future<void> _pauseIncoming(_Incoming inc) async {
    await inc.close();
    final r = inc.record;
    if (r.state.isTerminal) return;
    r.state = TransferState.paused;
    r.bytesPerSecond = 0;
    await store.save(r);
    _incoming.remove(r.id);
    _emit(r);
  }

  Future<void> _cancelIncoming(_Incoming inc) async {
    await inc.close();
    final r = inc.record;
    if (r.tempPath != null) {
      try {
        await File(r.tempPath!).delete();
      } catch (_) {}
    }
    r.state = TransferState.cancelled;
    r.bytesPerSecond = 0;
    r.finishedAt = DateTime.now();
    await store.remove(r.id);
    _incoming.remove(r.id);
    _emit(r);
  }

  Future<void> _failIncoming(_Incoming inc, String error) async {
    await inc.close();
    final r = inc.record;
    if (r.tempPath != null) {
      try {
        await File(r.tempPath!).delete();
      } catch (_) {}
    }
    r.state = TransferState.failed;
    r.error = error;
    r.bytesPerSecond = 0;
    r.finishedAt = DateTime.now();
    await store.remove(r.id);
    _incoming.remove(r.id);
    _emit(r);
  }

  // ---------------------------------------------------------------------------

  int _allocateId() {
    var id = _nextId++;
    if (_nextId > 0x7FFFFFFF) _nextId = 1;
    while (_outgoing.containsKey(id) || _incoming.containsKey(id)) {
      id = _nextId++;
    }
    return id;
  }

  void _emit(TransferRecord r, {bool progressOnly = false, bool removed = false}) {
    if (_events.isClosed) return;
    _events.add(TransferEvent(r.copy(), progressOnly: progressOnly, removed: removed));
  }

  static String _guessMime(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.heic':
      case '.heif':
        return 'image/heic';
      case '.mp4':
      case '.m4v':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.mkv':
        return 'video/x-matroska';
      case '.webm':
        return 'video/webm';
      case '.pdf':
        return 'application/pdf';
      case '.zip':
        return 'application/zip';
      case '.txt':
        return 'text/plain';
      case '.mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final s in _bulkSubs.values) {
      await s.cancel();
    }
    _bulkSubs.clear();
    for (final inc in _incoming.values.toList()) {
      await _pauseIncoming(inc);
    }
    await _events.close();
  }

  bool get isDisposed => _disposed;
}

/// xxh3 hex strings from Dart (unpadded) and Rust (16 digits) compare equal.
bool sameHash(String a, String b) {
  if (a == b) return true;
  final x = BigInt.tryParse(a, radix: 16);
  final y = BigInt.tryParse(b, radix: 16);
  return x != null && y != null && x == y;
}

class _Outgoing {
  _Outgoing(this.record);
  final TransferRecord record;
  final CancelToken cancel = CancelToken();
  final Completer<void> done = Completer<void>();
  bool pauseOnDrop = false;
  NativeJob? nativeJob;
}

class _Incoming {
  _Incoming(this.record, this._raf, this.directory, {required this.startOffset})
    : expected = startOffset,
      _meter = null;

  final TransferRecord record;
  final String directory;
  final int startOffset;
  RandomAccessFile? _raf;
  final StreamHasher hasher = StreamHasher();
  final Completer<void> received = Completer<void>();
  int expected;
  _ProgressMeter? _meter;
  bool _closed = false;

  /// Fast lane: the Rust job writing the file, and its hash once done.
  NativeJob? nativeJob;
  String? nativeHash;

  bool get isClosed => _closed;

  void markReceived() {
    if (!received.isCompleted) received.complete();
  }

  Future<void> write(DataChunk chunk, TransferEngine engine) async {
    final raf = _raf;
    if (raf == null || _closed) return;
    try {
      if (chunk.offset != expected) {
        if (chunk.offset == 0 && expected == startOffset) {
          // Sender could not resume: start over.
          await raf.truncate(0);
          await raf.setPosition(0);
          expected = 0;
          record.bytesDone = 0;
        } else {
          _log.warning('out-of-order chunk for ${record.name}: ${chunk.offset} != $expected');
          await engine._failIncoming(this, 'out of order data');
          return;
        }
      }
      await raf.writeFrom(chunk.bytes);
      hasher.update(chunk.bytes);
      expected += chunk.bytes.length;
      record.bytesDone = expected;
      (_meter ??= _ProgressMeter(engine, record, startOffset)).update(expected);
      if (record.bytesDone >= record.size) markReceived();
    } catch (e) {
      await engine._failIncoming(this, 'write failed: $e');
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    nativeJob?.cancel();
    nativeJob = null;
    final raf = _raf;
    _raf = null;
    if (raf != null) {
      try {
        await raf.flush();
        await raf.close();
      } catch (_) {}
    }
  }
}

/// Throttles progress events and estimates speed with a short moving average.
class _ProgressMeter {
  _ProgressMeter(this._engine, this._record, int start)
    : _lastBytes = start,
      _lastTime = DateTime.now(),
      _lastEmit = DateTime.now();

  final TransferEngine _engine;
  final TransferRecord _record;
  int _lastBytes;
  DateTime _lastTime;
  DateTime _lastEmit;

  void update(int bytesDone) {
    _record.bytesDone = bytesDone;
    final now = DateTime.now();
    final dt = now.difference(_lastTime).inMicroseconds;
    if (dt >= 200000) {
      final rate = (bytesDone - _lastBytes) * 1e6 / dt;
      _record.bytesPerSecond = _record.bytesPerSecond == 0
          ? rate
          : _record.bytesPerSecond * 0.6 + rate * 0.4;
      _lastBytes = bytesDone;
      _lastTime = now;
    }
    if (now.difference(_lastEmit) >= _engine.progressInterval || bytesDone == _record.size) {
      _lastEmit = now;
      _engine._emit(_record, progressOnly: true);
    }
  }
}
