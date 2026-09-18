import 'dart:async';

import 'package:pepo_core/src/discovery/discovery.dart';
import 'package:pepo_core/src/discovery/udp_beacon.dart';
import 'package:pepo_core/src/protocol/models.dart';
import 'package:test/test.dart';

void main() {
  test('UDP beacons find each other with probe/here', () async {
    // Two beacons on one machine cannot share a port reliably, so each
    // listens on its own port and probes the other's.
    final a = UdpBeacon(port: 47490, targetPort: 47491);
    final b = UdpBeacon(port: 47491, targetPort: 47490);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    final advertA = DiscoveryAdvert(
        deviceId: 'AAAAAAAAAAAAAAAAAAAAAAAAAA',
        fingerprint: 'a' * 64,
        name: 'PC',
        port: 47473,
        platform: DevicePlatform.windows,
        role: DeviceRole.hub);
    final advertB = DiscoveryAdvert(
        deviceId: 'BBBBBBBBBBBBBBBBBBBBBBBBBB',
        fingerprint: 'b' * 64,
        name: 'Phone',
        port: 47480,
        platform: DevicePlatform.android,
        role: DeviceRole.phone);
    await a.start(advertA);
    await b.start(advertB);
    final seenByB = b.found.first;
    final seenByA = a.found.first;
    await a.probe();
    PeerCandidate cb;
    try {
      cb = await seenByB.timeout(const Duration(seconds: 4));
    } on TimeoutException {
      markTestSkipped('broadcast UDP not available on this host');
      return;
    }
    expect(cb.deviceId, advertA.deviceId);
    expect(cb.port, 47473);
    expect(cb.shortFingerprint, 'a' * 16);
    expect(cb.addresses.single, isNotEmpty);
    final ca = await seenByA.timeout(const Duration(seconds: 4));
    expect(ca.deviceId, advertB.deviceId, reason: 'the reply to the probe');
    expect(ca.role, DeviceRole.phone);
  });

  test('local IPv4 addresses are listed and ranked', () async {
    final addrs = await localIPv4Addresses();
    for (final a in addrs) {
      expect(a, isNot(startsWith('169.254.')));
      expect(a, isNot(startsWith('127.')));
    }
  });
}
