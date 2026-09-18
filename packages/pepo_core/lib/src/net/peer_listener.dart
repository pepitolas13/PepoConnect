import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../identity/identity.dart';
import '../pairing/pairing_session.dart';
import '../protocol/models.dart';
import 'handshake.dart';
import 'peer_connection.dart';

final _log = Logger('pepo.net.listener');

/// Default TCP port; the next free one is used when it is busy.
const int defaultListenPort = 47473;

/// Accepts TLS connections and runs the server side of the handshake.
class PeerListener {
  PeerListener({
    required this.identity,
    required this.info,
    required this.registry,
    required this.pairingSessions,
    required this.tokens,
  });

  final Identity identity;
  LocalDeviceInfo info;
  final PeerRegistry registry;
  final PairingSessions pairingSessions;
  final SessionTokens tokens;

  SecureServerSocket? _server;
  StreamSubscription<SecureSocket>? _sub;
  final _accepted = StreamController<HandshakeResult>.broadcast();
  final Map<String, _FailureRecord> _failures = {};

  /// Authenticated (or newly paired) connections.
  Stream<HandshakeResult> get connections => _accepted.stream;

  int get port => _server?.port ?? 0;
  bool get isListening => _server != null;

  /// Binds to [preferredPort] or the next free one (up to 20 attempts).
  Future<int> start({int preferredPort = defaultListenPort}) async {
    if (_server != null) return port;
    final ctx = identity.serverContext();
    SecureServerSocket? server;
    Object? lastError;
    for (var p = preferredPort; p < preferredPort + 20; p++) {
      try {
        server = await SecureServerSocket.bind(InternetAddress.anyIPv6, p, ctx,
            v6Only: false, shared: false);
        break;
      } on SocketException catch (e) {
        lastError = e;
        // Some systems have no IPv6: fall back to IPv4.
        try {
          server = await SecureServerSocket.bind(InternetAddress.anyIPv4, p, ctx);
          break;
        } on SocketException catch (e2) {
          lastError = e2;
        }
      }
    }
    if (server == null) {
      throw SocketException('cannot bind listener: $lastError');
    }
    _server = server;
    _sub = server.listen(_onSocket, onError: (Object e) {
      _log.warning('accept error: $e');
    });
    _log.info('listening on port ${server.port}');
    return server.port;
  }

  void _onSocket(SecureSocket socket) {
    final address = socket.remoteAddress.address;
    if (_isThrottled(address)) {
      _log.warning('throttled $address');
      socket.destroy();
      return;
    }
    final conn = PeerConnection.wrap(socket, isInitiator: false, label: 'in:$address');
    unawaited(_handshake(conn, address));
  }

  Future<void> _handshake(PeerConnection conn, String address) async {
    try {
      final result = await ServerHandshake.run(
        conn,
        me: identity,
        info: info,
        registry: registry,
        pairingSessions: pairingSessions,
        tokens: tokens,
        listenPort: port,
      );
      _failures.remove(address);
      if (!_accepted.isClosed) _accepted.add(result);
    } on HandshakeException catch (e) {
      _log.fine('handshake from $address failed: $e');
      _recordFailure(address);
      await conn.close();
    } on PeerClosedException catch (e) {
      _log.fine('handshake from $address aborted: $e');
    } catch (e, st) {
      _log.warning('handshake from $address error: $e', e, st);
      await conn.close();
    }
  }

  bool _isThrottled(String address) {
    final r = _failures[address];
    if (r == null) return false;
    if (DateTime.now().isAfter(r.until)) {
      _failures.remove(address);
      return false;
    }
    return r.count >= 3;
  }

  void _recordFailure(String address) {
    final r = _failures[address];
    if (r == null || DateTime.now().isAfter(r.until)) {
      _failures[address] = _FailureRecord(1, DateTime.now().add(const Duration(seconds: 60)));
    } else {
      r.count++;
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _server?.close();
    _server = null;
  }

  Future<void> dispose() async {
    await stop();
    await _accepted.close();
  }
}

class _FailureRecord {
  _FailureRecord(this.count, this.until);
  int count;
  DateTime until;
}

/// Connects to a listener and runs the client side of the handshake.
class PeerDialer {
  const PeerDialer._();

  static const connectTimeout = Duration(seconds: 4);

  /// Opens a TLS connection to [host]:[port] pinning [expectedFingerprint].
  static Future<PeerConnection> connect(
    String host,
    int port, {
    required String expectedFingerprint,
    Duration timeout = connectTimeout,
  }) async {
    final socket = await SecureSocket.connect(
      host,
      port,
      context: SecurityContext(withTrustedRoots: false),
      onBadCertificate: (cert) =>
          Identity.fingerprintOfDer(cert.der) == expectedFingerprint,
      timeout: timeout,
    );
    return PeerConnection.wrap(socket, isInitiator: true, label: 'out:$host');
  }

  /// Tries every candidate address in parallel (staggered) and returns the
  /// first connection whose handshake succeeds; the others are closed.
  static Future<HandshakeResult> connectAny(
    List<String> hosts,
    int port, {
    required Identity me,
    required LocalDeviceInfo info,
    required String expectedFingerprint,
    required String channel,
    PairedDevice? known,
    Uint8List? pairingSecret,
    String? sessionToken,
    int? listenPort,
    Duration stagger = const Duration(milliseconds: 250),
  }) async {
    if (hosts.isEmpty) throw const SocketException('no addresses');
    final completer = Completer<HandshakeResult>();
    final errors = <Object>[];
    var remaining = hosts.length;
    for (var i = 0; i < hosts.length; i++) {
      final host = hosts[i];
      unawaited(Future<void>.delayed(stagger * i).then((_) async {
        if (completer.isCompleted) return;
        PeerConnection? conn;
        try {
          conn = await connect(host, port, expectedFingerprint: expectedFingerprint);
          if (completer.isCompleted) {
            await conn.close();
            return;
          }
          final result = await ClientHandshake.run(
            conn,
            me: me,
            info: info,
            channel: channel,
            known: known,
            pairingSecret: pairingSecret,
            sessionToken: sessionToken,
            listenPort: listenPort,
          );
          if (completer.isCompleted) {
            await conn.close();
          } else {
            completer.complete(result);
          }
        } catch (e) {
          errors.add(e);
          await conn?.close();
          // Authentication problems are definitive: stop trying other hosts.
          if (e is HandshakeException && !completer.isCompleted) {
            completer.completeError(e);
          }
        } finally {
          remaining--;
          if (remaining == 0 && !completer.isCompleted) {
            completer.completeError(errors.isEmpty
                ? const SocketException('unreachable')
                : errors.last);
          }
        }
      }));
    }
    return completer.future;
  }
}

