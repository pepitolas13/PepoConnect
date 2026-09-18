import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../discovery/discovery.dart';
import '../identity/identity.dart';
import '../pairing/pairing_session.dart';
import '../pairing/qr_payload.dart';
import '../protocol/message_types.dart';
import '../protocol/models.dart';
import '../transfer/transfer_engine.dart';
import 'auth.dart';
import 'frame.dart';
import 'handshake.dart';
import 'peer_connection.dart';
import 'peer_listener.dart';

final _log = Logger('pepo.session');

/// Persistence of paired devices (implemented by the platform store).
abstract class DeviceStore {
  Future<List<PairedDevice>> all();
  Future<PairedDevice?> find(String deviceId);
  Future<void> save(PairedDevice device);
  Future<void> remove(String deviceId);
}

/// In-memory device store for tests.
class MemoryDeviceStore implements DeviceStore {
  final Map<String, PairedDevice> _devices = {};

  @override
  Future<List<PairedDevice>> all() async => _devices.values.toList();

  @override
  Future<PairedDevice?> find(String deviceId) async => _devices[deviceId];

  @override
  Future<void> save(PairedDevice device) async => _devices[device.deviceId] = device;

  @override
  Future<void> remove(String deviceId) async => _devices.remove(deviceId);
}

/// Handles application-level control messages (media, clipboard, ...).
/// Return true when the message was consumed.
abstract class MessageHandler {
  Future<bool> handleMessage(String deviceId, PeerConnection conn, ControlMessage message);
}

/// Connection state of a paired device.
enum SessionState { disconnected, connecting, connected }

/// Events published by the [SessionManager].
sealed class SessionEvent {
  const SessionEvent(this.deviceId);
  final String deviceId;
}

class DeviceConnectedEvent extends SessionEvent {
  const DeviceConnectedEvent(super.deviceId, this.device);
  final PairedDevice device;
}

class DeviceDisconnectedEvent extends SessionEvent {
  const DeviceDisconnectedEvent(super.deviceId, this.reason);
  final String reason;
}

class DevicePairedEvent extends SessionEvent {
  const DevicePairedEvent(super.deviceId, this.device);
  final PairedDevice device;
}

class DeviceForgottenEvent extends SessionEvent {
  const DeviceForgottenEvent(super.deviceId);
}

class DeviceStatusEvent extends SessionEvent {
  const DeviceStatusEvent(super.deviceId, this.status);
  final DeviceStatus status;
}

class DeviceUpdatedEvent extends SessionEvent {
  const DeviceUpdatedEvent(super.deviceId, this.device);
  final PairedDevice device;
}

/// Everything about one paired device: control channel, media channel,
/// bulk pool and (for initiators) the reconnection loop.
class PeerSession {
  PeerSession._(this._manager, this.device);

  final SessionManager _manager;
  PairedDevice device;
  PeerConnection? _control;
  PeerConnection? _media;
  final List<_BulkSlot> _bulk = [];
  final List<Completer<PeerConnection>> _waitingBulk = [];
  final List<Completer<PeerConnection>> _waitingMedia = [];
  String? _sessionToken;
  SessionState state = SessionState.disconnected;
  DeviceStatus status = const DeviceStatus();
  Timer? _reconnectTimer;
  int _attempt = 0;
  bool _closed = false;
  DateTime? connectedAt;

  static const maxBulk = 3;
  static const bulkIdleTimeout = Duration(seconds: 60);

  String get deviceId => device.deviceId;
  bool get isConnected => state == SessionState.connected && _control != null;
  PeerConnection? get control => _control;
  String? get sessionToken => _sessionToken;

  // ---------------------------------------------------------------------------
  // Control channel

  void _bindControl(PeerConnection conn, String token, PairedDevice updated) {
    _reconnectTimer?.cancel();
    final old = _control;
    _control = conn;
    _sessionToken = token;
    device = updated.copyWith(
      lastAddresses: conn.isInitiator ? device.lastAddresses : _addressesFor(conn),
      lastSeen: DateTime.now(),
    );
    state = SessionState.connected;
    connectedAt = DateTime.now();
    _attempt = 0;
    conn.setNoDelay(true);
    conn.startKeepAlive();
    conn.messages.listen(
      (m) => _onControlMessage(conn, m),
      onError: (Object e) => _log.fine('control stream error: $e'),
    );
    conn.onClose.then((_) => _onControlClosed(conn));
    old?.close();
    unawaited(_manager._deviceStore.save(device));
    _manager._emit(DeviceConnectedEvent(deviceId, device));
    _manager.transfers?.onDeviceConnected(deviceId);
    unawaited(_manager.transfers?.resumePending(deviceId));
    _sendDeviceInfo();
  }

  List<String> _addressesFor(PeerConnection conn) {
    final host = conn.remoteAddress.split(':').first;
    return [host, ...device.lastAddresses.where((a) => a != host)].take(3).toList();
  }

  void _sendDeviceInfo() {
    final c = _control;
    if (c == null) return;
    final status = _manager.localStatus();
    c.send(
      MsgType.deviceInfo,
      data: {
        ...status.toJson(),
        'name': _manager.info.name,
        'role': _manager.info.role.code,
        'version': _manager.info.appVersion,
      },
    );
  }

  /// Pushes a fresh status (battery, storage) to the peer.
  void sendStatus() => _sendDeviceInfo();

  Future<void> _onControlMessage(PeerConnection conn, ControlMessage m) async {
    try {
      switch (m.type) {
        case MsgType.chanOpen:
          final purpose = m.optStr('purpose') ?? ChannelKind.bulk;
          if (device.weInitiate) {
            unawaited(_dialSecondary(purpose));
          } else {
            conn.respondError(m.reqId, ErrorCode.unsupported, 'listener cannot dial');
          }
          if (m.reqId != 0) conn.respond(m.reqId, MsgType.chanOk);
          return;
        case MsgType.deviceInfo:
          status = DeviceStatus.fromJson(m.data);
          final name = m.optStr('name');
          if (name != null && name.isNotEmpty && name != device.name) {
            device = device.copyWith(name: name);
            await _manager._deviceStore.save(device);
            _manager._emit(DeviceUpdatedEvent(deviceId, device));
          }
          _manager._emit(DeviceStatusEvent(deviceId, status));
          return;
        case MsgType.deviceUnpair:
          await _manager.forget(deviceId, notifyPeer: false);
          return;
      }
      final transfers = _manager.transfers;
      if (transfers != null && await transfers.handleControl(deviceId, conn, m)) return;
      for (final h in _manager.handlers) {
        if (await h.handleMessage(deviceId, conn, m)) return;
      }
      if (m.reqId != 0) conn.respondError(m.reqId, ErrorCode.unsupported, 'unknown ${m.type}');
    } catch (e, st) {
      _log.warning('error handling ${m.type} from $deviceId: $e', e, st);
      if (m.reqId != 0) conn.respondError(m.reqId, ErrorCode.internal, '$e');
    }
  }

  void _onControlClosed(PeerConnection conn) {
    if (!identical(conn, _control)) return;
    _control = null;
    _sessionToken = null;
    final reason = conn.closeReason?.toString() ?? 'closed';
    state = SessionState.disconnected;
    _media?.close();
    _media = null;
    for (final b in List.of(_bulk)) {
      b.idleTimer?.cancel();
      b.conn.close();
    }
    _bulk.clear();
    _failWaiters(PeerClosedException(reason));
    _manager.tokens.revokeDevice(deviceId);
    unawaited(_manager.transfers?.onDeviceDisconnected(deviceId));
    _manager._emit(DeviceDisconnectedEvent(deviceId, reason));
    if (!_closed && device.weInitiate) _scheduleReconnect();
  }

  void _failWaiters(Object error) {
    for (final c in [..._waitingBulk, ..._waitingMedia]) {
      if (!c.isCompleted) c.completeError(error);
    }
    _waitingBulk.clear();
    _waitingMedia.clear();
  }

  // ---------------------------------------------------------------------------
  // Secondary channels

  /// Registers an accepted or dialed secondary channel.
  void _adoptSecondary(PeerConnection conn, String channel) {
    if (_control == null) {
      conn.close();
      return;
    }
    if (channel == ChannelKind.media) {
      _media?.close();
      _media = conn;
      conn.setNoDelay(true);
      conn.onClose.then((_) {
        if (identical(_media, conn)) _media = null;
      });
      conn.messages.listen((m) => _onControlMessage(conn, m));
      for (final c in _waitingMedia) {
        if (!c.isCompleted) c.complete(conn);
      }
      _waitingMedia.clear();
      return;
    }
    if (channel == ChannelKind.bulk) {
      _manager.transfers?.attachBulk(deviceId, conn);
      final slot = _BulkSlot(conn);
      _bulk.add(slot);
      conn.onClose.then((_) => _bulk.remove(slot));
      if (_waitingBulk.isNotEmpty) {
        final c = _waitingBulk.removeAt(0);
        slot.busy = true;
        if (!c.isCompleted) c.complete(conn);
      } else {
        _armIdleTimer(slot);
      }
    }
  }

  void _armIdleTimer(_BulkSlot slot) {
    slot.idleTimer?.cancel();
    slot.idleTimer = Timer(bulkIdleTimeout, () {
      if (!slot.busy) {
        _bulk.remove(slot);
        slot.conn.close();
      }
    });
  }

  Future<void> _dialSecondary(String purpose) async {
    final token = _sessionToken;
    if (token == null) return;
    try {
      final result = await PeerDialer.connectAny(
        device.lastAddresses,
        device.lastPort ?? defaultListenPort,
        me: _manager.identity,
        info: _manager.info,
        expectedFingerprint: device.fingerprint,
        channel: purpose,
        known: device,
        sessionToken: token,
        listenPort: _manager.listenPort,
      );
      _adoptSecondary(result.connection, purpose);
    } catch (e) {
      _log.fine('cannot open $purpose channel to ${device.name}: $e');
      final err = e is Exception ? e : Exception('$e');
      if (purpose == ChannelKind.bulk) {
        for (final c in _waitingBulk) {
          if (!c.isCompleted) c.completeError(err);
        }
        _waitingBulk.clear();
      } else {
        for (final c in _waitingMedia) {
          if (!c.isCompleted) c.completeError(err);
        }
        _waitingMedia.clear();
      }
    }
  }

  Future<PeerConnection> acquireBulk() async {
    if (_control == null) throw PeerClosedException('device offline');
    for (final slot in _bulk) {
      if (!slot.busy && !slot.conn.isClosed) {
        slot.busy = true;
        slot.idleTimer?.cancel();
        return slot.conn;
      }
    }
    final completer = Completer<PeerConnection>();
    _waitingBulk.add(completer);
    if (_bulk.length + _pendingOpens < maxBulk) {
      await _requestSecondary(ChannelKind.bulk);
    }
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        _waitingBulk.remove(completer);
        throw TimeoutException('no bulk channel');
      },
    );
  }

  int _pendingOpens = 0;

  Future<void> _requestSecondary(String purpose) async {
    _pendingOpens++;
    try {
      if (device.weInitiate) {
        await _dialSecondary(purpose);
      } else {
        final c = _control;
        if (c == null) throw PeerClosedException('device offline');
        await c.request(MsgType.chanOpen, data: {'purpose': purpose});
      }
    } finally {
      _pendingOpens--;
    }
  }

  void releaseBulk(PeerConnection conn, {bool broken = false}) {
    final slot = _bulk.where((s) => identical(s.conn, conn)).firstOrNull;
    if (slot == null) {
      if (broken) conn.close();
      return;
    }
    if (broken || conn.isClosed) {
      _bulk.remove(slot);
      conn.close();
      if (_waitingBulk.isNotEmpty) unawaited(_requestSecondary(ChannelKind.bulk));
      return;
    }
    if (_waitingBulk.isNotEmpty) {
      final c = _waitingBulk.removeAt(0);
      if (!c.isCompleted) {
        c.complete(conn);
        return;
      }
    }
    slot.busy = false;
    _armIdleTimer(slot);
  }

  /// The media channel (opened lazily).
  Future<PeerConnection> mediaChannel() async {
    final m = _media;
    if (m != null && !m.isClosed) return m;
    if (_control == null) throw PeerClosedException('device offline');
    final completer = Completer<PeerConnection>();
    _waitingMedia.add(completer);
    if (_waitingMedia.length == 1) await _requestSecondary(ChannelKind.media);
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        _waitingMedia.remove(completer);
        throw TimeoutException('no media channel');
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Reconnection (initiator side)

  void _scheduleReconnect({bool immediate = false}) {
    if (_closed || !device.weInitiate || _control != null) return;
    _reconnectTimer?.cancel();
    final base = immediate ? 0 : [1, 2, 4, 8, 15, 30][min(_attempt, 5)];
    final jitter = base == 0 ? 0 : (base * 200 * (Random().nextDouble() - 0.5)).round();
    final delay = Duration(milliseconds: base * 1000 + jitter);
    _reconnectTimer = Timer(delay, () => unawaited(_reconnect()));
  }

  /// Retries right away (network change, discovery hit, app foreground).
  void kick() {
    if (state == SessionState.connecting) return;
    _scheduleReconnect(immediate: true);
  }

  Future<void> _reconnect() async {
    if (_closed || _control != null || state == SessionState.connecting) return;
    state = SessionState.connecting;
    _attempt++;
    final addresses = _manager._candidateAddresses(device);
    if (addresses.isEmpty) {
      state = SessionState.disconnected;
      await _manager.probe();
      _scheduleReconnect();
      return;
    }
    try {
      final result = await PeerDialer.connectAny(
        addresses,
        device.lastPort ?? defaultListenPort,
        me: _manager.identity,
        info: _manager.info,
        expectedFingerprint: device.fingerprint,
        channel: ChannelKind.control,
        known: device,
        listenPort: _manager.listenPort,
      );
      final hostUsed = result.connection.remoteAddress.split(':').first;
      final updated = result.device.copyWith(
        lastAddresses: [
          hostUsed,
          ...device.lastAddresses.where((a) => a != hostUsed),
        ].take(3).toList(),
        lastPort: device.lastPort ?? defaultListenPort,
      );
      _bindControl(result.connection, result.sessionToken, updated);
    } on NotPairedException {
      _log.warning('${device.name} no longer knows us');
      state = SessionState.disconnected;
      _manager._emit(DeviceDisconnectedEvent(deviceId, 'not paired'));
      // Do not hammer: retry slowly in case it was transient.
      _attempt = 5;
      _scheduleReconnect();
    } catch (e) {
      state = SessionState.disconnected;
      if (_attempt <= 2) await _manager.probe();
      _scheduleReconnect();
    }
  }

  Future<void> close() async {
    _closed = true;
    _reconnectTimer?.cancel();
    _failWaiters(PeerClosedException('session closed'));
    for (final b in List.of(_bulk)) {
      b.idleTimer?.cancel();
      await b.conn.close();
    }
    _bulk.clear();
    await _media?.close();
    _media = null;
    final c = _control;
    _control = null;
    await c?.close();
    state = SessionState.disconnected;
  }
}

class _BulkSlot {
  _BulkSlot(this.conn);
  final PeerConnection conn;
  bool busy = false;
  Timer? idleTimer;
}

/// Owns the listener, all sessions and the pairing flows.
class SessionManager implements ChannelProvider, PeerRegistry {
  SessionManager({
    required this.identity,
    required LocalDeviceInfo info,
    required DeviceStore deviceStore,
    List<Discovery> discovery = const [],
    DeviceStatus Function()? localStatus,
    this.preferredPort = defaultListenPort,
  }) : _info = info,
       // ignore: prefer_initializing_formals
       _deviceStore = deviceStore,
       _discovery = List.of(discovery),
       _localStatus = localStatus ?? (() => const DeviceStatus()) {
    pairing = PairingSessions();
    tokens = SessionTokens();
    _listener = PeerListener(
      identity: identity,
      info: info,
      registry: this,
      pairingSessions: pairing,
      tokens: tokens,
    );
  }

  final Identity identity;
  LocalDeviceInfo _info;
  final DeviceStore _deviceStore;
  final List<Discovery> _discovery;
  final DeviceStatus Function() _localStatus;
  final int preferredPort;
  late final PairingSessions pairing;
  late final SessionTokens tokens;
  late final PeerListener _listener;
  final Map<String, PeerSession> _sessions = {};
  final Map<String, PeerCandidate> _candidates = {};
  final List<MessageHandler> handlers = [];
  final _events = StreamController<SessionEvent>.broadcast();
  final List<StreamSubscription<dynamic>> _subs = [];
  TransferEngine? transfers;
  bool _started = false;

  LocalDeviceInfo get info => _info;
  Stream<SessionEvent> get events => _events.stream;
  int get listenPort => _listener.port;
  Iterable<PeerSession> get sessions => _sessions.values;
  PeerSession? session(String deviceId) => _sessions[deviceId];
  Iterable<PeerCandidate> get candidates => _candidates.values;
  DeviceStatus localStatus() => _localStatus();

  void _emit(SessionEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  /// Starts listening, discovery and the reconnection loops of known devices.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _listener.start(preferredPort: preferredPort);
    _subs.add(_listener.connections.listen(_onAccepted));
    final advert = _advert();
    for (final d in _discovery) {
      try {
        await d.start(advert);
        _subs.add(d.found.listen(_onCandidate));
      } catch (e) {
        _log.warning('discovery ${d.runtimeType} failed to start: $e');
      }
    }
    for (final device in await _deviceStore.all()) {
      final s = PeerSession._(this, device);
      _sessions[device.deviceId] = s;
      if (device.weInitiate) s._scheduleReconnect(immediate: true);
    }
    await probe();
  }

  DiscoveryAdvert _advert() => DiscoveryAdvert(
    deviceId: identity.deviceId,
    fingerprint: identity.fingerprint,
    name: _info.name,
    port: _listener.port,
    platform: _info.platform,
    role: _info.role,
  );

  /// Renames this device (propagated to peers on next connect).
  Future<void> updateInfo(LocalDeviceInfo info) async {
    _info = info;
    _listener.info = info;
    for (final d in _discovery) {
      await d.updateAdvert(_advert());
    }
    for (final s in _sessions.values) {
      s.sendStatus();
    }
  }

  /// Broadcasts fresh local status to connected peers.
  void broadcastStatus() {
    for (final s in _sessions.values) {
      if (s.isConnected) s.sendStatus();
    }
  }

  /// Asks all discovery backends to look for peers.
  Future<void> probe() async {
    for (final d in _discovery) {
      try {
        await d.probe();
      } catch (_) {}
    }
  }

  /// Retries every disconnected initiator session now (network change).
  void kickAll() {
    for (final s in _sessions.values) {
      s.kick();
    }
  }

  void _onCandidate(PeerCandidate c) {
    _candidates[c.deviceId] = c;
    final s = _sessions[c.deviceId];
    if (s != null && !s.isConnected && s.device.weInitiate) {
      if (!s.device.lastAddresses.contains(c.addresses.first) || s.device.lastPort != c.port) {
        s.device = s.device.copyWith(
          lastAddresses: {...c.addresses, ...s.device.lastAddresses}.take(4).toList(),
          lastPort: c.port,
        );
      }
      s.kick();
    }
  }

  List<String> _candidateAddresses(PairedDevice device) {
    final c = _candidates[device.deviceId];
    final fresh = c != null && DateTime.now().difference(c.seenAt) < const Duration(minutes: 10)
        ? c.addresses
        : const <String>[];
    return {...fresh, ...device.lastAddresses}.toList();
  }

  void _onAccepted(HandshakeResult r) {
    final id = r.device.deviceId;
    var s = _sessions[id];
    if (s == null) {
      s = PeerSession._(this, r.device);
      _sessions[id] = s;
    }
    if (r.newlyPaired) {
      s.device = r.device;
      _emit(DevicePairedEvent(id, r.device));
    }
    if (r.channel == ChannelKind.control) {
      final port = r.remoteInfo.listenPort;
      s._bindControl(
        r.connection,
        r.sessionToken,
        port == null ? r.device : r.device.copyWith(lastPort: port),
      );
    } else {
      s._adoptSecondary(r.connection, r.channel);
    }
  }

  // ---------------------------------------------------------------------------
  // Pairing (dialing side)

  /// Pairs with the device that showed [payload] (QR or pasted link).
  Future<PairedDevice> pairWithQr(QrPayload payload) async {
    if (payload.isExpired) throw HandshakeException('code expired', code: ErrorCode.timeout);
    return _pairDial(
      addresses: payload.addresses,
      port: payload.port,
      fingerprint: payload.fingerprint,
      secret: payload.secret,
    );
  }

  /// Pairs by typing the 6-digit code shown by [candidate] (or an address).
  Future<PairedDevice> pairWithCode({
    required String code,
    required List<String> addresses,
    required int port,
    required String hostDeviceId,
    required String hostFingerprint,
  }) {
    final secret = PepoCrypto.manualCodeSecret(code, hostDeviceId);
    return _pairDial(
      addresses: addresses,
      port: port,
      fingerprint: hostFingerprint,
      secret: secret,
    );
  }

  /// Learns the identity of a listener at [host] (for manual code pairing
  /// when the host was not discovered).
  Future<({String deviceId, String fingerprint})> identify(String host, int port) async {
    String? fp;
    final socket = await SecureSocket.connect(
      host,
      port,
      context: SecurityContext(withTrustedRoots: false),
      onBadCertificate: (cert) {
        fp = Identity.fingerprintOfDer(cert.der);
        return true;
      },
      timeout: PeerDialer.connectTimeout,
    );
    final der = socket.peerCertificate?.der;
    socket.destroy();
    if (der == null || fp == null) throw HandshakeException('no certificate');
    return (deviceId: Identity.deviceIdFromDer(der), fingerprint: fp!);
  }

  Future<PairedDevice> _pairDial({
    required List<String> addresses,
    required int port,
    required String fingerprint,
    required Uint8List secret,
  }) async {
    final result = await PeerDialer.connectAny(
      addresses,
      port,
      me: identity,
      info: _info,
      expectedFingerprint: fingerprint,
      channel: ChannelKind.control,
      pairingSecret: secret,
      listenPort: listenPort,
    );
    final hostUsed = result.connection.remoteAddress.split(':').first;
    final device = result.device.copyWith(
      lastAddresses: [hostUsed, ...addresses.where((a) => a != hostUsed)].take(3).toList(),
      lastPort: port,
      weInitiate: true,
    );
    await _deviceStore.save(device);
    var s = _sessions[device.deviceId];
    if (s == null) {
      s = PeerSession._(this, device);
      _sessions[device.deviceId] = s;
    }
    _emit(DevicePairedEvent(device.deviceId, device));
    s._bindControl(result.connection, result.sessionToken, device);
    return device;
  }

  // ---------------------------------------------------------------------------
  // Device management

  Future<void> forget(String deviceId, {bool notifyPeer = true}) async {
    final s = _sessions.remove(deviceId);
    if (s != null) {
      if (notifyPeer && s.isConnected) {
        try {
          s.control?.send(MsgType.deviceUnpair);
          await s.control?.flush();
        } catch (_) {}
      }
      await s.close();
    }
    tokens.revokeDevice(deviceId);
    await _deviceStore.remove(deviceId);
    _emit(DeviceForgottenEvent(deviceId));
  }

  /// Updates persisted settings of a device (name, auto download...).
  Future<void> updateDevice(PairedDevice device) async {
    await _deviceStore.save(device);
    _sessions[device.deviceId]?.device = device;
    _emit(DeviceUpdatedEvent(device.deviceId, device));
  }

  Future<void> disconnect(String deviceId) async {
    final s = _sessions[deviceId];
    if (s == null) return;
    await s.control?.close();
  }

  // ChannelProvider --------------------------------------------------------

  @override
  PeerConnection? controlFor(String deviceId) {
    final s = _sessions[deviceId];
    if (s == null || !s.isConnected) return null;
    return s.control;
  }

  @override
  Future<PeerConnection> acquireBulk(String deviceId) {
    final s = _sessions[deviceId];
    if (s == null) return Future.error(PeerClosedException('unknown device'));
    return s.acquireBulk();
  }

  @override
  void releaseBulk(String deviceId, PeerConnection conn, {bool broken = false}) =>
      _sessions[deviceId]?.releaseBulk(conn, broken: broken);

  /// Media channel of [deviceId] (opened lazily).
  Future<PeerConnection> mediaChannel(String deviceId) {
    final s = _sessions[deviceId];
    if (s == null) return Future.error(PeerClosedException('unknown device'));
    return s.mediaChannel();
  }

  // PeerRegistry -------------------------------------------------------------

  @override
  Future<PairedDevice?> findDevice(String deviceId) => _deviceStore.find(deviceId);

  @override
  Future<void> saveDevice(PairedDevice device) => _deviceStore.save(device);

  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    for (final s in _sessions.values.toList()) {
      await s.close();
    }
    _sessions.clear();
    for (final d in _discovery) {
      await d.stop();
    }
    await _listener.dispose();
    pairing.dispose();
    await _events.close();
  }
}
