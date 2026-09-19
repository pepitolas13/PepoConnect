import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:logging/logging.dart';
import 'package:pepo_core/pepo_core.dart';

final _log = Logger('pepo.discovery.bonjour');

/// The service PepoConnect advertises. Declared in `ios/Runner/Info.plist`
/// under `NSBonjourServices`, without which iOS refuses to browse for it.
const String pepoServiceType = '_pepoconnect._tcp';

/// Finds peers over Bonjour/mDNS, on every platform.
///
/// The UDP beacon cannot run on iPhone: since iOS 14 broadcast and multicast
/// need an entitlement Apple grants case by case, and never to a free
/// account. Without this an iPhone can only ever dial the last address it saw,
/// so a PC that reboots onto a new DHCP lease disappears for good. mDNS asks
/// for nothing beyond the local-network permission the app already has.
///
/// It runs on the desktops and on Android too, because the discovery only
/// works if the other end is announcing itself.
class BonjourDiscovery implements Discovery {
  BonjourDiscovery({
    this.serviceType = pepoServiceType,
    this.rediscoverAfter = const Duration(seconds: 20),
  });

  final String serviceType;

  /// A probe restarts the browse at most this often. mDNS keeps listening on
  /// its own, so restarting more than that is churn for nothing.
  final Duration rediscoverAfter;

  final _found = StreamController<PeerCandidate>.broadcast();

  /// Last candidate seen per device, so a probe can answer from memory
  /// instead of waiting for the network to say it again.
  final Map<String, PeerCandidate> _seen = {};

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _browser;
  StreamSubscription<BonsoirDiscoveryEvent>? _events;
  StreamSubscription<BonsoirBroadcastEvent>? _broadcastEvents;
  DiscoveryAdvert? _advert;
  DateTime? _browsingSince;
  bool _running = false;
  int _nameAttempt = 0;

  @override
  Stream<PeerCandidate> get found => _found.stream;

  bool get isRunning => _running;

  @override
  Future<void> start(DiscoveryAdvert advert) async {
    _advert = advert;
    if (_running) return;
    _running = true;
    await _startBroadcast();
    await _startBrowse();
  }

  @override
  Future<void> updateAdvert(DiscoveryAdvert advert) async {
    final previous = _advert;
    _advert = advert;
    if (!_running) return;
    if (previous != null && previous.name == advert.name && previous.port == advert.port) {
      return;
    }
    _nameAttempt = 0;
    await _stopBroadcast();
    await _startBroadcast();
  }

  @override
  Future<void> stop() async {
    _running = false;
    await _stopBroadcast();
    await _stopBrowse();
    _seen.clear();
  }

  void dispose() {
    unawaited(stop());
    _found.close();
  }

  /// mDNS has no probe of its own: what it can do is hand back what it
  /// already knows right away, and start the browse over when it has been
  /// running long enough that a restart might turn something up.
  @override
  Future<void> probe() async {
    if (!_running) return;
    final advert = _advert;
    for (final candidate in _seen.values) {
      if (advert != null && candidate.deviceId == advert.deviceId) continue;
      if (!_found.isClosed) _found.add(candidate);
    }
    final since = _browsingSince;
    if (_browser == null || since == null || DateTime.now().difference(since) > rediscoverAfter) {
      await _stopBrowse();
      await _startBrowse();
    }
  }

  // ---------------------------------------------------------------------------

  Future<void> _startBroadcast() async {
    final advert = _advert;
    if (advert == null || advert.port <= 0) return;
    try {
      final broadcast = BonsoirBroadcast(
        printLogs: false,
        service: BonsoirService(
          name: _serviceName(advert),
          type: serviceType,
          port: advert.port,
          attributes: {
            'id': advert.deviceId,
            'fp16': advert.shortFingerprint,
            'name': advert.name,
            'platform': advert.platform.code,
            'role': advert.role.code,
          },
        ),
      );
      await broadcast.initialize();
      _broadcastEvents = broadcast.eventStream?.listen(_onBroadcastEvent);
      await broadcast.start();
      _broadcast = broadcast;
    } catch (e) {
      // No Avahi, no permission, no mDNS stack: the other backends carry on.
      _log.info('cannot announce over mDNS: $e');
      await _stopBroadcast();
    }
  }

  /// Another device on the network already answers to this name. Most
  /// platforms rename silently; the ones that do not say so here.
  void _onBroadcastEvent(BonsoirBroadcastEvent event) {
    if (event is! BonsoirBroadcastNameAlreadyExistsEvent) return;
    if (_nameAttempt >= 3) return;
    _nameAttempt++;
    unawaited(() async {
      await _stopBroadcast();
      await _startBroadcast();
    }());
  }

  Future<void> _stopBroadcast() async {
    final broadcast = _broadcast;
    _broadcast = null;
    await _broadcastEvents?.cancel();
    _broadcastEvents = null;
    if (broadcast == null || broadcast.isStopped) return;
    try {
      await broadcast.stop();
    } catch (_) {}
  }

  Future<void> _startBrowse() async {
    try {
      final browser = BonsoirDiscovery(printLogs: false, type: serviceType);
      await browser.initialize();
      _events = browser.eventStream?.listen((event) => _onEvent(browser, event));
      await browser.start();
      _browser = browser;
      _browsingSince = DateTime.now();
    } catch (e) {
      _log.info('cannot browse over mDNS: $e');
      await _stopBrowse();
    }
  }

  Future<void> _stopBrowse() async {
    final browser = _browser;
    _browser = null;
    _browsingSince = null;
    await _events?.cancel();
    _events = null;
    if (browser == null || browser.isStopped) return;
    try {
      await browser.stop();
    } catch (_) {}
  }

  void _onEvent(BonsoirDiscovery browser, BonsoirDiscoveryEvent event) {
    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent():
        // Found only carries the name; the address and the TXT record need
        // a second round trip.
        unawaited(_resolve(browser, event.service));
      case BonsoirDiscoveryServiceResolvedEvent():
        _publish(event.service);
      case BonsoirDiscoveryServiceUpdatedEvent():
        _publish(event.service);
      case BonsoirDiscoveryServiceLostEvent():
        _seen.removeWhere((_, c) => c.name == event.service.name);
      default:
        break;
    }
  }

  Future<void> _resolve(BonsoirDiscovery browser, BonsoirService service) async {
    try {
      await service.resolve(browser.serviceResolver);
    } catch (e) {
      _log.fine('cannot resolve ${service.name}: $e');
    }
  }

  void _publish(BonsoirService service) {
    final advert = _advert;
    final candidate = candidateFromService(service, selfId: advert?.deviceId);
    if (candidate == null) return;
    _seen[candidate.deviceId] = candidate;
    if (!_found.isClosed) _found.add(candidate);
  }

  /// `Mi iPhone` for the phone next to you, and something that still works
  /// when two of them are called the same: the id in the TXT record is what
  /// identifies the device, the name is only what other Bonjour browsers
  /// show.
  String _serviceName(DiscoveryAdvert advert) {
    final base = advert.name.trim().isEmpty ? 'PepoConnect' : advert.name.trim();
    final name = _nameAttempt == 0
        ? base
        : '$base (${advert.deviceId.substring(advert.deviceId.length - 4)})';
    // RFC 6763 allows 63 bytes; accented characters take two.
    return name.length > 40 ? name.substring(0, 40) : name;
  }
}

/// Turns a resolved mDNS service into a candidate, or null when it is not
/// one of ours, is this very device, or has not been resolved yet.
///
/// Kept apart from the plugin so the mapping can be tested without a
/// platform channel.
PeerCandidate? candidateFromService(BonsoirService service, {String? selfId, DateTime? at}) {
  final attributes = service.attributes;
  final id = attributes['id'];
  if (id == null || id.length != 26 || id == selfId) return null;
  if (service.port <= 0) return null;
  final addresses = usableAddresses(service.hostAddresses);
  if (addresses.isEmpty) return null;
  return PeerCandidate(
    deviceId: id,
    shortFingerprint: attributes['fp16'] ?? '',
    name: attributes['name'] ?? service.name,
    addresses: addresses,
    port: service.port,
    platform: DevicePlatform.fromCode(attributes['platform']),
    role: DeviceRole.fromCode(attributes['role']),
    source: DiscoverySource.mdns,
    seenAt: at ?? DateTime.now(),
  );
}

/// Drops what cannot be dialled: APIPA, IPv6 link-local (the scope id the
/// peer reports means nothing on this side) and loopback.
List<String> usableAddresses(List<String> addresses) {
  final out = <String>[];
  for (final address in addresses) {
    final value = address.trim();
    if (value.isEmpty) continue;
    if (value.startsWith('169.254.') || value == '127.0.0.1') continue;
    final lower = value.toLowerCase();
    if (lower.startsWith('fe80:') || lower == '::1') continue;
    if (!out.contains(value)) out.add(value);
  }
  // IPv4 first: it is what the rest of the app pairs and reconnects with.
  out.sort((a, b) => (a.contains(':') ? 1 : 0).compareTo(b.contains(':') ? 1 : 0));
  return out;
}
