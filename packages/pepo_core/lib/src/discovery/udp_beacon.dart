import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import '../protocol/models.dart';
import 'discovery.dart';

final _log = Logger('pepo.discovery.udp');

/// Default UDP port for probes.
const int defaultBeaconPort = 47474;

/// Pure Dart discovery: broadcast `probe` datagrams, answer with `here`.
///
/// Works wherever broadcast UDP does (Windows, Linux, Android with a
/// multicast lock). Not used on iOS (needs an entitlement); there the
/// platform layer provides Bonjour.
class UdpBeacon implements Discovery {
  UdpBeacon({this.port = defaultBeaconPort, int? targetPort}) : targetPort = targetPort ?? port;

  /// Port we listen on for probes.
  final int port;

  /// Port probes are sent to (differs from [port] only in tests).
  final int targetPort;
  final _found = StreamController<PeerCandidate>.broadcast();
  RawDatagramSocket? _listen;
  final List<RawDatagramSocket> _senders = [];
  DiscoveryAdvert? _advert;
  bool _running = false;

  @override
  Stream<PeerCandidate> get found => _found.stream;

  bool get isRunning => _running;

  @override
  Future<void> start(DiscoveryAdvert advert) async {
    _advert = advert;
    if (_running) return;
    _running = true;
    try {
      _listen = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port, reuseAddress: true);
    } on SocketException {
      // Another instance owns the port: we can still probe and hear replies
      // on an ephemeral port, we just cannot answer probes.
      _listen = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _log.info('beacon port $port busy, answering disabled');
    }
    _listen!.broadcastEnabled = true;
    _listen!.listen((event) {
      if (event == RawSocketEvent.read) _onDatagram(_listen!);
    });
  }

  @override
  Future<void> updateAdvert(DiscoveryAdvert advert) async => _advert = advert;

  @override
  Future<void> stop() async {
    _running = false;
    _listen?.close();
    _listen = null;
    for (final s in _senders) {
      s.close();
    }
    _senders.clear();
  }

  void dispose() {
    stop();
    _found.close();
  }

  /// Sends probes from every IPv4 interface (limited broadcast) in a short
  /// burst: now, +1 s, +3 s.
  @override
  Future<void> probe() async {
    if (!_running) return;
    for (final delay in const [0, 1000, 3000]) {
      unawaited(Future<void>.delayed(Duration(milliseconds: delay), _sendProbe));
    }
  }

  Future<void> _sendProbe() async {
    final advert = _advert;
    if (!_running || advert == null) return;
    final payload = utf8.encode(jsonEncode(_message('probe', advert)));
    final targets = <InternetAddress>[InternetAddress('255.255.255.255')];
    for (final iface in await _interfaces()) {
      for (final addr in iface.addresses) {
        if (addr.type != InternetAddressType.IPv4) continue;
        RawDatagramSocket? s;
        try {
          s = await RawDatagramSocket.bind(addr, 0);
          s.broadcastEnabled = true;
          s.listen((event) {
            if (event == RawSocketEvent.read) _onDatagram(s!);
          });
          _senders.add(s);
          for (final t in targets) {
            s.send(payload, t, targetPort);
          }
          // Keep it briefly open to receive unicast replies.
          Timer(const Duration(seconds: 5), () {
            _senders.remove(s);
            s?.close();
          });
        } on SocketException catch (e) {
          _log.fine('probe from ${addr.address} failed: $e');
          s?.close();
        }
      }
    }
    // Also from the listening socket (default route).
    for (final t in targets) {
      try {
        _listen?.send(payload, t, targetPort);
      } on SocketException {
        // ignore
      }
    }
  }

  Future<List<NetworkInterface>> _interfaces() async {
    try {
      return await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
    } catch (_) {
      return const [];
    }
  }

  void _onDatagram(RawDatagramSocket socket) {
    final dg = socket.receive();
    if (dg == null) return;
    final advert = _advert;
    if (advert == null) return;
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(utf8.decode(dg.data));
      if (decoded is! Map<String, dynamic>) return;
      json = decoded;
    } catch (_) {
      return;
    }
    if (json['v'] != 1) return;
    final id = json['id'];
    if (id is! String || id.length != 26 || id == advert.deviceId) return;
    final type = json['t'];
    final candidate = PeerCandidate(
      deviceId: id,
      shortFingerprint: json['fp16'] as String? ?? '',
      name: json['name'] as String? ?? '',
      addresses: [dg.address.address],
      port: json['port'] as int? ?? 0,
      platform: DevicePlatform.fromCode(json['platform'] as String?),
      role: DeviceRole.fromCode(json['role'] as String?),
      source: DiscoverySource.udp,
      seenAt: DateTime.now(),
    );
    if (candidate.port > 0 && !_found.isClosed) _found.add(candidate);
    if (type == 'probe' && identical(socket, _listen)) {
      final reply = utf8.encode(jsonEncode(_message('here', advert)));
      try {
        socket.send(reply, dg.address, dg.port);
      } on SocketException {
        // ignore
      }
    }
  }

  static Map<String, dynamic> _message(String type, DiscoveryAdvert a) => {
    'v': 1,
    't': type,
    'id': a.deviceId,
    'fp16': a.shortFingerprint,
    'name': a.name,
    'port': a.port,
    'platform': a.platform.code,
    'role': a.role.code,
  };
}

/// Local IPv4 addresses worth advertising (QR code, hello).
Future<List<String>> localIPv4Addresses() async {
  try {
    final ifaces = await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: false,
      type: InternetAddressType.IPv4,
    );
    final out = <String>[];
    for (final i in ifaces) {
      for (final a in i.addresses) {
        // Prefer private ranges first, skip APIPA and Docker-ish defaults.
        if (a.address.startsWith('169.254.')) continue;
        out.add(a.address);
      }
    }
    out.sort((x, y) => _rank(x).compareTo(_rank(y)));
    return out;
  } catch (_) {
    return const [];
  }
}

int _rank(String ip) {
  if (ip.startsWith('192.168.')) return 0;
  if (ip.startsWith('10.')) return 1;
  if (ip.startsWith('172.')) return 2;
  return 3;
}
