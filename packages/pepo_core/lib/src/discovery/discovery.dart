import 'dart:async';

import 'package:meta/meta.dart';

import '../protocol/models.dart';

/// How a candidate was found.
enum DiscoverySource { udp, mdns, known, manual }

/// A device seen on the network (not necessarily paired).
@immutable
class PeerCandidate {
  const PeerCandidate({
    required this.deviceId,
    required this.shortFingerprint,
    required this.name,
    required this.addresses,
    required this.port,
    required this.platform,
    required this.role,
    required this.source,
    required this.seenAt,
  });

  final String deviceId;

  /// First 16 hex chars of the certificate fingerprint.
  final String shortFingerprint;
  final String name;
  final List<String> addresses;
  final int port;
  final DevicePlatform platform;
  final DeviceRole role;
  final DiscoverySource source;
  final DateTime seenAt;

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'fp16': shortFingerprint,
    'name': name,
    'addresses': addresses,
    'port': port,
    'platform': platform.code,
    'role': role.code,
    'source': source.name,
    'seenAt': seenAt.toUtc().toIso8601String(),
  };

  factory PeerCandidate.fromJson(Map<String, dynamic> j) => PeerCandidate(
    deviceId: j['deviceId'] as String,
    shortFingerprint: j['fp16'] as String? ?? '',
    name: j['name'] as String? ?? '',
    addresses: (j['addresses'] as List<dynamic>? ?? const []).cast<String>(),
    port: j['port'] as int,
    platform: DevicePlatform.fromCode(j['platform'] as String?),
    role: DeviceRole.fromCode(j['role'] as String?),
    source: DiscoverySource.values.byName(j['source'] as String? ?? 'udp'),
    seenAt: DateTime.parse(j['seenAt'] as String),
  );
}

/// What this device announces.
@immutable
class DiscoveryAdvert {
  const DiscoveryAdvert({
    required this.deviceId,
    required this.fingerprint,
    required this.name,
    required this.port,
    required this.platform,
    required this.role,
  });

  final String deviceId;
  final String fingerprint;
  final String name;
  final int port;
  final DevicePlatform platform;
  final DeviceRole role;

  String get shortFingerprint => fingerprint.substring(0, 16);

  DiscoveryAdvert copyWith({String? name, int? port, DeviceRole? role}) => DiscoveryAdvert(
    deviceId: deviceId,
    fingerprint: fingerprint,
    name: name ?? this.name,
    port: port ?? this.port,
    platform: platform,
    role: role ?? this.role,
  );
}

/// Finds peers on the local network. Implementations: [UdpBeacon] (pure
/// Dart) and a Bonjour/mDNS one in the platform layer. Several can run at
/// once; the session layer merges their candidates.
abstract class Discovery {
  /// Candidates as they are seen (may repeat).
  Stream<PeerCandidate> get found;

  Future<void> start(DiscoveryAdvert advert);
  Future<void> updateAdvert(DiscoveryAdvert advert);
  Future<void> stop();

  /// Actively asks the network for peers (a burst of probes).
  Future<void> probe();
}
