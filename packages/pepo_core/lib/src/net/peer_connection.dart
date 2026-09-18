import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:logging/logging.dart';

import '../identity/identity.dart';
import '../protocol/message_types.dart';
import 'frame.dart';

final _log = Logger('pepo.net.connection');

/// Error returned by the remote side for a request.
class PeerError implements Exception {
  PeerError(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'PeerError($code: $message)';
}

/// The connection closed before a request completed.
class PeerClosedException implements Exception {
  PeerClosedException([this.reason = 'connection closed']);
  final String reason;

  @override
  String toString() => 'PeerClosedException: $reason';
}

/// One TLS socket speaking the PepoConnect frame protocol.
///
/// Offers request/response correlation, an event stream for unsolicited
/// control messages, a stream of data chunks and optional keep-alive.
class PeerConnection {
  PeerConnection._(this._socket, {required this.isInitiator, this.label = ''}) {
    remoteFingerprint = _socket.peerCertificate == null
        ? null
        : Identity.fingerprintOfDer(_socket.peerCertificate!.der);
    _subscription = _socket.listen(
      _onBytes,
      onError: (Object e, StackTrace st) => _finish(PeerClosedException('$e')),
      onDone: () => _finish(PeerClosedException('remote closed')),
      cancelOnError: true,
    );
  }

  /// Wraps an accepted or connected secure socket.
  factory PeerConnection.wrap(
    SecureSocket socket, {
    required bool isInitiator,
    String label = '',
  }) =>
      PeerConnection._(socket, isInitiator: isInitiator, label: label);

  static const keepAliveIdle = Duration(seconds: 15);
  static const keepAliveTimeout = Duration(seconds: 5);
  static const defaultRequestTimeout = Duration(seconds: 15);

  final SecureSocket _socket;
  final bool isInitiator;
  final String label;

  /// Fingerprint of the certificate presented by the remote (client side
  /// only; servers do not request client certificates).
  late final String? remoteFingerprint;

  final FrameDecoder _decoder = FrameDecoder();
  late final StreamSubscription<Uint8List> _subscription;
  final _messages = StreamController<ControlMessage>();
  late final StreamQueue<ControlMessage> _queue = StreamQueue(_messages.stream);
  Stream<ControlMessage>? _rest;
  final _data = StreamController<DataChunk>();
  final _closed = Completer<void>();
  final Map<int, Completer<ControlMessage>> _pending = {};
  final Map<int, Timer> _pendingTimers = {};
  int _nextReqId = 1;
  Timer? _keepAlive;
  DateTime _lastActivity = DateTime.now();
  DateTime? _pingSentAt;
  bool _closing = false;
  bool _streaming = false;
  Object? _closeReason;

  /// Unsolicited control messages (events and incoming requests) that were
  /// not consumed by [nextMessage]. Single subscription.
  Stream<ControlMessage> get messages => _rest ??= _queue.rest;

  /// Pulls the next unsolicited message (used by handshakes). Messages
  /// arriving in between calls are buffered, never dropped.
  Future<ControlMessage> nextMessage({Duration? timeout}) {
    if (_rest != null) {
      throw StateError('messages stream already handed out');
    }
    final next = _queue.next;
    if (timeout == null) return next;
    return next.timeout(timeout);
  }

  /// Incoming data chunks (bulk channels).
  Stream<DataChunk> get data => _data.stream;

  /// Completes when the connection is closed for any reason.
  Future<void> get onClose => _closed.future;

  bool get isClosed => _closed.isCompleted;

  String get remoteAddress => '${_socket.remoteAddress.address}:${_socket.remotePort}';

  Object? get closeReason => _closeReason;

  /// Enables ping/pong keep-alive (control channels only).
  void startKeepAlive() {
    _keepAlive?.cancel();
    _keepAlive = Timer.periodic(const Duration(seconds: 2), (_) => _checkKeepAlive());
  }

  /// Disables Nagle's algorithm (small control messages).
  void setNoDelay(bool value) {
    try {
      _socket.setOption(SocketOption.tcpNoDelay, value);
    } on SocketException {
      // Not supported on some platforms; harmless.
    }
  }

  void _checkKeepAlive() {
    if (_closing || _streaming) return;
    final now = DateTime.now();
    final pingAt = _pingSentAt;
    if (pingAt != null) {
      if (now.difference(pingAt) > keepAliveTimeout) {
        _log.fine('$label keep-alive timeout');
        _finish(PeerClosedException('keep-alive timeout'));
      }
      return;
    }
    if (now.difference(_lastActivity) > keepAliveIdle) {
      _pingSentAt = now;
      sendFrame(Frame.ping());
    }
  }

  void _onBytes(Uint8List chunk) {
    _lastActivity = DateTime.now();
    try {
      _decoder.addChunk(chunk, _onFrame);
    } on FrameFormatException catch (e) {
      _log.warning('$label protocol violation: $e');
      _finish(PeerClosedException('protocol violation: ${e.message}'));
    }
  }

  void _onFrame(Frame frame) {
    switch (frame.kind) {
      case FrameKind.ping:
        sendFrame(Frame.pong());
      case FrameKind.pong:
        _pingSentAt = null;
      case FrameKind.data:
        if (!_data.isClosed) _data.add(DataChunk.fromFrame(frame));
      case FrameKind.control:
        final msg = ControlMessage.fromFrame(frame);
        final pending = msg.reqId == 0 ? null : _pending.remove(msg.reqId);
        if (pending != null) {
          _pendingTimers.remove(msg.reqId)?.cancel();
          if (msg.type == MsgType.error) {
            pending.completeError(PeerError(
              msg.optStr('code') ?? ErrorCode.internal,
              msg.optStr('msg') ?? 'error',
            ));
          } else {
            pending.complete(msg);
          }
        } else if (!_messages.isClosed) {
          _messages.add(msg);
        }
    }
  }

  /// Sends a raw frame. Cheap for control-sized frames.
  void sendFrame(Frame frame) {
    if (_closing) return;
    if (_streaming) {
      throw StateError('cannot send frames while a data stream is bound');
    }
    try {
      _socket.add(frame.encode());
    } catch (e) {
      _finish(PeerClosedException('write failed: $e'));
    }
  }

  /// Sends an event / request-less control message.
  void send(String type, {Map<String, dynamic>? data, Uint8List? body}) =>
      sendFrame(Frame.control(type, data: data, body: body));

  /// Responds to a request identified by [reqId].
  void respond(int reqId, String type, {Map<String, dynamic>? data, Uint8List? body}) =>
      sendFrame(Frame.control(type, data: data, body: body, reqId: reqId));

  /// Responds with an error to a request.
  void respondError(int reqId, String code, String message) =>
      respond(reqId, MsgType.error, data: {'code': code, 'msg': message});

  /// Sends a request and waits for the correlated response.
  Future<ControlMessage> request(
    String type, {
    Map<String, dynamic>? data,
    Uint8List? body,
    Duration timeout = defaultRequestTimeout,
  }) {
    if (isClosed) return Future.error(PeerClosedException(_closeReason?.toString() ?? 'closed'));
    final reqId = _nextReqId++;
    if (_nextReqId > 0x7FFFFFFF) _nextReqId = 1;
    final completer = Completer<ControlMessage>();
    _pending[reqId] = completer;
    _pendingTimers[reqId] = Timer(timeout, () {
      final c = _pending.remove(reqId);
      _pendingTimers.remove(reqId);
      c?.completeError(PeerError(ErrorCode.timeout, 'no response to $type in ${timeout.inSeconds}s'));
    });
    sendFrame(Frame.control(type, data: data, body: body, reqId: reqId));
    return completer.future;
  }

  /// Binds a stream of already-encoded frames (head+body) to the socket with
  /// backpressure. No other frame may be sent until it completes.
  Future<void> addStream(Stream<List<int>> frames) async {
    if (_streaming) throw StateError('a stream is already bound');
    _streaming = true;
    try {
      await _socket.addStream(frames);
      await _socket.flush();
    } finally {
      _streaming = false;
      _lastActivity = DateTime.now();
    }
  }

  /// Waits until all buffered bytes were handed to the OS.
  Future<void> flush() => _socket.flush();

  /// Closes the connection gracefully: pending writes are delivered and a TLS
  /// close_notify is sent before the socket is torn down.
  Future<void> close() async {
    if (_closing) return onClose;
    _closing = true;
    _keepAlive?.cancel();
    try {
      await _socket.flush().timeout(const Duration(seconds: 2));
      await _socket.close().timeout(const Duration(seconds: 2));
    } catch (_) {
      // Best effort; _finish destroys the socket anyway.
    }
    _finish(null);
    return onClose;
  }

  void _finish(Object? reason) {
    if (_closed.isCompleted) return;
    _closing = true;
    _closeReason = reason;
    _keepAlive?.cancel();
    for (final t in _pendingTimers.values) {
      t.cancel();
    }
    _pendingTimers.clear();
    final err = reason is PeerClosedException ? reason : PeerClosedException();
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(err);
    }
    _pending.clear();
    _subscription.cancel();
    _socket.destroy();
    if (!_messages.isClosed) _messages.close();
    if (!_data.isClosed) _data.close();
    _closed.complete();
  }
}
