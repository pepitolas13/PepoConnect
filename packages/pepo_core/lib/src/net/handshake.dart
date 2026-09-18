import 'dart:async';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../identity/identity.dart';
import '../pairing/pairing_session.dart';
import '../protocol/message_types.dart';
import '../protocol/models.dart';
import '../util/bytes.dart';
import '../version.dart';
import 'auth.dart';
import 'frame.dart';
import 'peer_connection.dart';

final _log = Logger('pepo.net.handshake');

/// Where paired devices live. Implemented by the hub store.
abstract class PeerRegistry {
  Future<PairedDevice?> findDevice(String deviceId);
  Future<void> saveDevice(PairedDevice device);
}

/// Session tokens issued by a listener to authenticated control channels so
/// that secondary channels (media/bulk) can skip the HMAC round trip.
class SessionTokens {
  final Map<String, _TokenEntry> _tokens = {};

  String issue(String deviceId) {
    final token = base64Url(randomBytes(32));
    _tokens[token] = _TokenEntry(deviceId, DateTime.now());
    return token;
  }

  /// Returns the device id bound to [token] or null.
  String? validate(String token) {
    final e = _tokens[token];
    if (e == null) return null;
    if (DateTime.now().difference(e.issuedAt) > const Duration(hours: 24)) {
      _tokens.remove(token);
      return null;
    }
    return e.deviceId;
  }

  void revoke(String token) => _tokens.remove(token);

  void revokeDevice(String deviceId) =>
      _tokens.removeWhere((_, e) => e.deviceId == deviceId);
}

class _TokenEntry {
  _TokenEntry(this.deviceId, this.issuedAt);
  final String deviceId;
  final DateTime issuedAt;
}

/// Outcome of a successful handshake.
class HandshakeResult {
  HandshakeResult({
    required this.connection,
    required this.channel,
    required this.device,
    required this.sessionToken,
    required this.newlyPaired,
    required this.remoteInfo,
  });

  final PeerConnection connection;
  final String channel;
  final PairedDevice device;
  final String sessionToken;
  final bool newlyPaired;
  final RemoteHello remoteInfo;
}

/// Decoded `hello` of the other side.
class RemoteHello {
  RemoteHello({
    required this.version,
    required this.channel,
    required this.deviceId,
    required this.fingerprint,
    required this.name,
    required this.platform,
    required this.role,
    required this.appVersion,
    required this.nonce,
    this.model,
    this.sessionToken,
    this.listenPort,
  });

  final int version;
  final String channel;
  final String deviceId;
  final String fingerprint;
  final String name;
  final DevicePlatform platform;
  final DeviceRole role;
  final String appVersion;
  final Uint8List nonce;
  final String? model;
  final String? sessionToken;
  final int? listenPort;

  static RemoteHello parse(ControlMessage m) {
    if (m.type != MsgType.hello) throw HandshakeException('expected hello, got ${m.type}');
    final nonce = base64UrlDecode(m.str('nonce'));
    if (nonce.length != 32) throw HandshakeException('bad nonce length');
    final id = m.str('id');
    if (id.length != 26) throw HandshakeException('bad device id');
    final chan = m.str('chan');
    if (!ChannelKind.isValid(chan)) throw HandshakeException('bad channel $chan');
    return RemoteHello(
      version: m.integer('v'),
      channel: chan,
      deviceId: id,
      fingerprint: m.str('fp'),
      name: m.optStr('name') ?? '',
      platform: DevicePlatform.fromCode(m.optStr('platform')),
      role: DeviceRole.fromCode(m.optStr('role')),
      appVersion: m.optStr('app') ?? '',
      nonce: nonce,
      model: m.optStr('model'),
      sessionToken: m.optStr('session'),
      listenPort: m.optInt('port'),
    );
  }
}

class HandshakeException implements Exception {
  HandshakeException(this.message, {this.code = ErrorCode.unauthorized});
  final String message;
  final String code;

  @override
  String toString() => 'HandshakeException($code): $message';
}

/// Thrown when the listener does not know us and we have no pairing secret.
class NotPairedException extends HandshakeException {
  NotPairedException() : super('device not paired', code: ErrorCode.unauthorized);
}

Map<String, dynamic> _helloData({
  required Identity me,
  required LocalDeviceInfo info,
  required String channel,
  required Uint8List nonce,
  String? sessionToken,
  int? listenPort,
}) =>
    {
      'v': protocolVersion,
      'chan': channel,
      'id': me.deviceId,
      'fp': me.fingerprint,
      ...info.toJson(),
      'nonce': base64Url(nonce),
      'session': ?sessionToken,
      'port': ?listenPort,
    };

/// Client side of the handshake (the device that dialed).
class ClientHandshake {
  const ClientHandshake._();

  static const timeout = Duration(seconds: 8);

  /// Runs hello → auth/pair. Exactly one of [known] (already paired) or
  /// [pairingSecret] (from a QR/manual code) should be given, unless a
  /// [sessionToken] is used for a secondary channel of an authenticated
  /// session (then [known] is required too).
  static Future<HandshakeResult> run(
    PeerConnection conn, {
    required Identity me,
    required LocalDeviceInfo info,
    required String channel,
    PairedDevice? known,
    Uint8List? pairingSecret,
    String? sessionToken,
    int? listenPort,
  }) async {
    final myNonce = randomBytes(32);
    final helloReply = await conn
        .request(
          MsgType.hello,
          data: _helloData(
            me: me,
            info: info,
            channel: channel,
            nonce: myNonce,
            sessionToken: sessionToken,
            listenPort: listenPort,
          ),
          timeout: timeout,
        )
        .catchError((Object e) => throw HandshakeException('hello failed: $e'));
    final remote = RemoteHello.parse(helloReply);
    if (remote.version != protocolVersion) {
      throw HandshakeException('protocol version ${remote.version} unsupported',
          code: ErrorCode.unsupported);
    }
    final pinned = conn.remoteFingerprint;
    if (pinned != null && pinned != remote.fingerprint) {
      throw HandshakeException('certificate fingerprint does not match hello');
    }
    if (known != null && remote.deviceId != known.deviceId) {
      throw HandshakeException('unexpected device ${remote.deviceId}');
    }

    // Secondary channel: the token proves the session.
    if (sessionToken != null) {
      final ok = await conn.request(MsgType.chanOk, data: const {}, timeout: timeout);
      if (ok.type != MsgType.chanOk) throw HandshakeException('channel refused: ${ok.type}');
      return HandshakeResult(
        connection: conn,
        channel: channel,
        device: known!,
        sessionToken: sessionToken,
        newlyPaired: false,
        remoteInfo: remote,
      );
    }

    if (known != null) {
      final proof = PepoCrypto.authProof(
        psk: known.psk,
        nonceClient: myNonce,
        nonceServer: remote.nonce,
        fpClient: me.fingerprint,
        fpServer: remote.fingerprint,
        role: 'client',
      );
      final ControlMessage reply;
      try {
        reply = await conn.request(
          MsgType.authProof,
          data: {'proof': base64Url(proof)},
          timeout: timeout,
        );
      } on PeerError catch (e) {
        if (e.code == ErrorCode.unauthorized) throw NotPairedException();
        rethrow;
      }
      if (reply.type == MsgType.authUnknown) throw NotPairedException();
      if (reply.type != MsgType.authOk) {
        throw HandshakeException('auth failed: ${reply.type} ${reply.optStr('reason') ?? ''}');
      }
      final serverProof = base64UrlDecode(reply.str('proof'));
      final expected = PepoCrypto.authProof(
        psk: known.psk,
        nonceClient: myNonce,
        nonceServer: remote.nonce,
        fpClient: me.fingerprint,
        fpServer: remote.fingerprint,
        role: 'server',
      );
      if (!PepoCrypto.verify(serverProof, expected)) {
        throw HandshakeException('server proof invalid');
      }
      final updated = known.copyWith(
        name: remote.name,
        platform: remote.platform,
        role: remote.role,
        model: remote.model,
        lastSeen: DateTime.now(),
      );
      return HandshakeResult(
        connection: conn,
        channel: channel,
        device: updated,
        sessionToken: reply.str('session'),
        newlyPaired: false,
        remoteInfo: remote,
      );
    }

    if (pairingSecret == null) throw NotPairedException();
    final proof = PepoCrypto.pairingProof(
      secret: pairingSecret,
      label: PepoCrypto.labelPairRequest,
      nonceClient: myNonce,
      nonceServer: remote.nonce,
      fpClient: me.fingerprint,
      fpServer: remote.fingerprint,
    );
    final ControlMessage reply;
    try {
      reply = await conn.request(
        MsgType.pairRequest,
        data: {'proof': base64Url(proof)},
        timeout: const Duration(seconds: 30),
      );
    } on PeerError catch (e) {
      throw HandshakeException('pairing rejected: ${e.message}', code: e.code);
    }
    if (reply.type != MsgType.pairAccept) {
      throw HandshakeException('pairing rejected: ${reply.optStr('reason') ?? reply.type}',
          code: ErrorCode.rejected);
    }
    final acceptProof = base64UrlDecode(reply.str('proof'));
    final expected = PepoCrypto.pairingProof(
      secret: pairingSecret,
      label: PepoCrypto.labelPairAccept,
      nonceClient: myNonce,
      nonceServer: remote.nonce,
      fpClient: me.fingerprint,
      fpServer: remote.fingerprint,
    );
    if (!PepoCrypto.verify(acceptProof, expected)) {
      throw HandshakeException('pair accept proof invalid');
    }
    final psk = PepoCrypto.derivePsk(
      secret: pairingSecret,
      nonceClient: myNonce,
      nonceServer: remote.nonce,
      deviceIdA: me.deviceId,
      deviceIdB: remote.deviceId,
    );
    final device = PairedDevice(
      deviceId: remote.deviceId,
      name: remote.name,
      platform: remote.platform,
      role: remote.role,
      fingerprint: remote.fingerprint,
      psk: psk,
      weInitiate: true,
      pairedAt: DateTime.now(),
      model: remote.model,
      lastSeen: DateTime.now(),
    );
    return HandshakeResult(
      connection: conn,
      channel: channel,
      device: device,
      sessionToken: reply.str('session'),
      newlyPaired: true,
      remoteInfo: remote,
    );
  }
}

/// Server side of the handshake (the device that listens).
class ServerHandshake {
  const ServerHandshake._();

  static const timeout = Duration(seconds: 8);

  /// Waits for the client's hello and completes auth or pairing.
  ///
  /// [pairingSessions] provides the secret for new devices; [tokens] validates
  /// secondary channels. Returns null when the client was told it is unknown
  /// and gave up (connection closed by us).
  static Future<HandshakeResult> run(
    PeerConnection conn, {
    required Identity me,
    required LocalDeviceInfo info,
    required PeerRegistry registry,
    required PairingSessions pairingSessions,
    required SessionTokens tokens,
    int? listenPort,
  }) async {
    final ControlMessage first;
    try {
      first = await conn.nextMessage(timeout: timeout);
    } on TimeoutException {
      throw HandshakeException('no hello');
    } on StateError {
      throw HandshakeException('connection closed before hello');
    }
    final remote = RemoteHello.parse(first);
    if (remote.version != protocolVersion) {
      conn.respondError(first.reqId, ErrorCode.unsupported, 'protocol version');
      throw HandshakeException('protocol version ${remote.version} unsupported',
          code: ErrorCode.unsupported);
    }
    final myNonce = randomBytes(32);
    conn.respond(
      first.reqId,
      MsgType.hello,
      data: _helloData(
        me: me,
        info: info,
        channel: remote.channel,
        nonce: myNonce,
        listenPort: listenPort,
      ),
    );

    final ControlMessage next;
    try {
      next = await conn.nextMessage(timeout: timeout);
    } on TimeoutException {
      throw HandshakeException('no auth');
    } on StateError {
      throw HandshakeException('connection closed before auth');
    }

    // Secondary channel with a session token.
    if (remote.sessionToken != null) {
      final deviceId = tokens.validate(remote.sessionToken!);
      if (deviceId == null || deviceId != remote.deviceId || next.type != MsgType.chanOk) {
        conn.respondError(next.reqId, ErrorCode.unauthorized, 'bad session');
        throw HandshakeException('invalid session token');
      }
      final device = await registry.findDevice(deviceId);
      if (device == null) {
        conn.respondError(next.reqId, ErrorCode.unauthorized, 'unknown device');
        throw HandshakeException('unknown device for token');
      }
      conn.respond(next.reqId, MsgType.chanOk);
      return HandshakeResult(
        connection: conn,
        channel: remote.channel,
        device: device,
        sessionToken: remote.sessionToken!,
        newlyPaired: false,
        remoteInfo: remote,
      );
    }

    if (next.type == MsgType.authProof) {
      final device = await registry.findDevice(remote.deviceId);
      if (device == null) {
        conn.respond(next.reqId, MsgType.authUnknown);
        throw NotPairedException();
      }
      if (device.fingerprint != remote.fingerprint) {
        conn.respondError(next.reqId, ErrorCode.unauthorized, 'fingerprint mismatch');
        throw HandshakeException('fingerprint mismatch for ${remote.deviceId}');
      }
      final expected = PepoCrypto.authProof(
        psk: device.psk,
        nonceClient: remote.nonce,
        nonceServer: myNonce,
        fpClient: remote.fingerprint,
        fpServer: me.fingerprint,
        role: 'client',
      );
      final given = base64UrlDecode(next.str('proof'));
      if (!PepoCrypto.verify(given, expected)) {
        conn.respondError(next.reqId, ErrorCode.unauthorized, 'bad proof');
        throw HandshakeException('bad auth proof from ${remote.deviceId}');
      }
      final serverProof = PepoCrypto.authProof(
        psk: device.psk,
        nonceClient: remote.nonce,
        nonceServer: myNonce,
        fpClient: remote.fingerprint,
        fpServer: me.fingerprint,
        role: 'server',
      );
      final token = tokens.issue(device.deviceId);
      conn.respond(next.reqId, MsgType.authOk, data: {
        'proof': base64Url(serverProof),
        'session': token,
        'serverTime': DateTime.now().toUtc().millisecondsSinceEpoch,
      });
      final updated = device.copyWith(
        name: remote.name,
        platform: remote.platform,
        role: remote.role,
        model: remote.model,
        lastSeen: DateTime.now(),
      );
      return HandshakeResult(
        connection: conn,
        channel: remote.channel,
        device: updated,
        sessionToken: token,
        newlyPaired: false,
        remoteInfo: remote,
      );
    }

    if (next.type == MsgType.pairRequest) {
      final session = pairingSessions.active;
      if (session == null || session.isExpired) {
        conn.respondError(next.reqId, ErrorCode.rejected, 'no pairing in progress');
        throw HandshakeException('pair request without session', code: ErrorCode.rejected);
      }
      final expected = PepoCrypto.pairingProof(
        secret: session.secret,
        label: PepoCrypto.labelPairRequest,
        nonceClient: remote.nonce,
        nonceServer: myNonce,
        fpClient: remote.fingerprint,
        fpServer: me.fingerprint,
      );
      final given = base64UrlDecode(next.str('proof'));
      if (!PepoCrypto.verify(given, expected)) {
        pairingSessions.recordFailure(session, conn.remoteAddress);
        conn.respondError(next.reqId, ErrorCode.rejected, 'bad pairing proof');
        throw HandshakeException('bad pairing proof from ${conn.remoteAddress}',
            code: ErrorCode.rejected);
      }
      pairingSessions.consume(session);
      final acceptProof = PepoCrypto.pairingProof(
        secret: session.secret,
        label: PepoCrypto.labelPairAccept,
        nonceClient: remote.nonce,
        nonceServer: myNonce,
        fpClient: remote.fingerprint,
        fpServer: me.fingerprint,
      );
      final psk = PepoCrypto.derivePsk(
        secret: session.secret,
        nonceClient: remote.nonce,
        nonceServer: myNonce,
        deviceIdA: me.deviceId,
        deviceIdB: remote.deviceId,
      );
      final device = PairedDevice(
        deviceId: remote.deviceId,
        name: remote.name,
        platform: remote.platform,
        role: remote.role,
        fingerprint: remote.fingerprint,
        psk: psk,
        weInitiate: false,
        pairedAt: DateTime.now(),
        model: remote.model,
        lastSeen: DateTime.now(),
      );
      await registry.saveDevice(device);
      final token = tokens.issue(device.deviceId);
      conn.respond(next.reqId, MsgType.pairAccept, data: {
        'proof': base64Url(acceptProof),
        'session': token,
      });
      _log.info('paired with ${device.name} (${device.shortId})');
      return HandshakeResult(
        connection: conn,
        channel: remote.channel,
        device: device,
        sessionToken: token,
        newlyPaired: true,
        remoteInfo: remote,
      );
    }

    conn.respondError(next.reqId, ErrorCode.badRequest, 'unexpected ${next.type}');
    throw HandshakeException('unexpected message ${next.type}', code: ErrorCode.badRequest);
  }
}
