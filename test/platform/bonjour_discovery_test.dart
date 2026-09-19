import 'package:bonsoir/bonsoir.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepo_core/pepo_core.dart';
import 'package:pepoconnect/platform/bonjour_discovery.dart';

const self = 'SELF0000000000000000000000';
const peer = 'PEER0000000000000000000000';

BonsoirService service({
  String name = 'Torre',
  int port = 47473,
  List<String> addresses = const ['192.168.1.20'],
  Map<String, String>? attributes,
}) => BonsoirService.ignoreNorms(
  name: name,
  type: pepoServiceType,
  port: port,
  hostAddresses: addresses,
  attributes:
      attributes ??
      const {
        'id': peer,
        'fp16': '0123456789abcdef',
        'name': 'Torre',
        'platform': 'win',
        'role': 'hub',
      },
);

void main() {
  group('candidateFromService', () {
    test('a resolved PepoConnect service becomes a candidate', () {
      final candidate = candidateFromService(service(), selfId: self)!;
      expect(candidate.deviceId, peer);
      expect(candidate.shortFingerprint, '0123456789abcdef');
      expect(candidate.name, 'Torre');
      expect(candidate.addresses, ['192.168.1.20']);
      expect(candidate.port, 47473);
      expect(candidate.platform, DevicePlatform.windows);
      expect(candidate.role, DeviceRole.hub);
      expect(candidate.source, DiscoverySource.mdns);
    });

    test('this very device is ignored', () {
      final own = service(attributes: const {'id': self});
      expect(candidateFromService(own, selfId: self), isNull);
    });

    test('something else on the network is ignored', () {
      expect(candidateFromService(service(attributes: const {}), selfId: self), isNull);
      expect(
        candidateFromService(service(attributes: const {'id': 'short'}), selfId: self),
        isNull,
      );
    });

    test('a service that has not resolved yet is not a candidate', () {
      expect(candidateFromService(service(addresses: const []), selfId: self), isNull);
      expect(candidateFromService(service(port: 0), selfId: self), isNull);
    });

    test('the mDNS name is the fallback when the TXT record has none', () {
      final noName = service(
        name: 'MacBook de Ana',
        attributes: const {'id': peer, 'platform': 'mac'},
      );
      final candidate = candidateFromService(noName, selfId: self)!;
      expect(candidate.name, 'MacBook de Ana');
      expect(candidate.shortFingerprint, '');
    });
  });

  group('usableAddresses', () {
    test('drops what cannot be dialled and puts IPv4 first', () {
      final out = usableAddresses([
        'fe80::1c2d:3e4f:5a6b:7c8d',
        '169.254.10.5',
        '127.0.0.1',
        '::1',
        '2001:db8::5',
        '192.168.1.20',
      ]);
      expect(out, ['192.168.1.20', '2001:db8::5']);
    });

    test('keeps every distinct address once', () {
      expect(usableAddresses(['10.0.0.2', '10.0.0.2', ' ', '10.0.0.3']), ['10.0.0.2', '10.0.0.3']);
    });
  });

  group('BonjourDiscovery', () {
    test('probe and stop do nothing before it has been started', () async {
      final discovery = BonjourDiscovery();
      await expectLater(discovery.probe(), completes);
      await expectLater(discovery.stop(), completes);
      expect(discovery.isRunning, isFalse);
    });

    test('it announces the service iOS declares in Info.plist', () {
      expect(pepoServiceType, '_pepoconnect._tcp');
      expect(BonjourDiscovery().serviceType, pepoServiceType);
    });
  });
}
