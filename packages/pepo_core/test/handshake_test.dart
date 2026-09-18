import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:pepo_core/src/identity/certificate_factory.dart';
import 'package:pepo_core/src/identity/identity.dart';
import 'package:pepo_core/src/net/auth.dart';
import 'package:pepo_core/src/net/handshake.dart';
import 'package:pepo_core/src/net/peer_connection.dart';
import 'package:pepo_core/src/net/peer_listener.dart';
import 'package:pepo_core/src/pairing/pairing_session.dart';
import 'package:pepo_core/src/protocol/message_types.dart';
import 'package:pepo_core/src/protocol/models.dart';
import 'package:test/test.dart';

class MemoryRegistry implements PeerRegistry {
  final Map<String, PairedDevice> devices = {};

  @override
  Future<PairedDevice?> findDevice(String deviceId) async => devices[deviceId];

  @override
  Future<void> saveDevice(PairedDevice device) async => devices[device.deviceId] = device;
}

void main() {
  late Identity hubId;
  late Identity phoneId;
  const hubInfo = LocalDeviceInfo(
    name: 'PC de Daniel',
    platform: DevicePlatform.windows,
    role: DeviceRole.hub,
    appVersion: '0.1.0',
  );
  const phoneInfo = LocalDeviceInfo(
    name: 'Pixel 8',
    platform: DevicePlatform.android,
    role: DeviceRole.phone,
    appVersion: '0.1.0',
    model: 'Pixel 8',
  );

  setUpAll(() {
    hubId = const CertificateFactory().generate(commonName: 'hub');
    phoneId = const CertificateFactory().generate(commonName: 'phone');
  });

  Future<(PeerListener, MemoryRegistry, PairingSessions)> startHub() async {
    final registry = MemoryRegistry();
    final sessions = PairingSessions();
    final listener = PeerListener(
      identity: hubId,
      info: hubInfo,
      registry: registry,
      pairingSessions: sessions,
      tokens: SessionTokens(),
    );
    await listener.start(preferredPort: 0);
    addTearDown(listener.dispose);
    return (listener, registry, sessions);
  }

  test('pair via QR secret, then re-authenticate with PSK and open a bulk channel', () async {
    final (listener, registry, sessions) = await startHub();
    final session = sessions.startQr();
    final accepted = listener.connections.first;

    // Phone pairs.
    final phoneResult = await PeerDialer.connectAny(
      ['127.0.0.1'],
      listener.port,
      me: phoneId,
      info: phoneInfo,
      expectedFingerprint: hubId.fingerprint,
      channel: ChannelKind.control,
      pairingSecret: session.secret,
    );
    final hubResult = await accepted;
    expect(phoneResult.newlyPaired, isTrue);
    expect(hubResult.newlyPaired, isTrue);
    expect(phoneResult.device.deviceId, hubId.deviceId);
    expect(hubResult.device.deviceId, phoneId.deviceId);
    expect(hubResult.device.name, 'Pixel 8');
    expect(hubResult.device.model, 'Pixel 8');
    expect(phoneResult.device.psk, hubResult.device.psk);
    expect(
      PepoCrypto.verificationCode(phoneResult.device.psk),
      PepoCrypto.verificationCode(hubResult.device.psk),
    );
    expect(sessions.active, isNull, reason: 'single use');
    expect(registry.devices, contains(phoneId.deviceId));

    // Request/response and events across the authenticated control channel.
    final hubConn = hubResult.connection;
    final phoneConn = phoneResult.connection;
    hubConn.messages.listen((m) {
      if (m.type == 'echo') hubConn.respond(m.reqId, 'echo.ok', data: {'v': m.data['v']});
      if (m.type == 'boom') hubConn.respondError(m.reqId, ErrorCode.notFound, 'nope');
    });
    final reply = await phoneConn.request('echo', data: {'v': 42});
    expect(reply.type, 'echo.ok');
    expect(reply.integer('v'), 42);
    await expectLater(phoneConn.request('boom'), throwsA(isA<PeerError>()));

    // Second connection: PSK auth (phone remembers the hub, hub remembers the phone).
    final phoneKnownHub = phoneResult.device;
    final accepted2 = listener.connections.first;
    final phoneResult2 = await PeerDialer.connectAny(
      ['127.0.0.1'],
      listener.port,
      me: phoneId,
      info: phoneInfo,
      expectedFingerprint: hubId.fingerprint,
      channel: ChannelKind.control,
      known: phoneKnownHub,
    );
    final hubResult2 = await accepted2;
    expect(phoneResult2.newlyPaired, isFalse);
    expect(hubResult2.newlyPaired, isFalse);
    expect(phoneResult2.sessionToken, hubResult2.sessionToken);

    // Secondary bulk channel using the session token, no HMAC round trip.
    final accepted3 = listener.connections.first;
    final bulk = await PeerDialer.connectAny(
      ['127.0.0.1'],
      listener.port,
      me: phoneId,
      info: phoneInfo,
      expectedFingerprint: hubId.fingerprint,
      channel: ChannelKind.bulk,
      known: phoneKnownHub,
      sessionToken: phoneResult2.sessionToken,
    );
    final hubBulk = await accepted3;
    expect(bulk.channel, ChannelKind.bulk);
    expect(hubBulk.channel, ChannelKind.bulk);
    expect(hubBulk.device.deviceId, phoneId.deviceId);

    // Ping/pong keeps the control channel alive.
    phoneConn.startKeepAlive();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(phoneConn.isClosed, isFalse);

    await phoneConn.close();
    await hubConn.onClose.timeout(const Duration(seconds: 2));
    await bulk.connection.close();
    await phoneResult2.connection.close();
  });

  test('unknown device without a secret is told to pair', () async {
    final (listener, _, _) = await startHub();
    await expectLater(
      PeerDialer.connectAny(
        ['127.0.0.1'],
        listener.port,
        me: phoneId,
        info: phoneInfo,
        expectedFingerprint: hubId.fingerprint,
        channel: ChannelKind.control,
        known: PairedDevice(
          deviceId: hubId.deviceId,
          name: 'PC',
          platform: DevicePlatform.windows,
          role: DeviceRole.hub,
          fingerprint: hubId.fingerprint,
          psk: Uint8List(32),
          weInitiate: true,
          pairedAt: DateTime.now(),
        ),
      ),
      throwsA(isA<NotPairedException>()),
    );
  });

  test('wrong pairing proof is rejected and manual codes are single attempt', () async {
    final (listener, registry, sessions) = await startHub();
    final session = sessions.startManualCode(hubId.deviceId);
    expect(session.code, matches(RegExp(r'^\d{6}$')));
    final wrongSecret = PepoCrypto.manualCodeSecret('000000', hubId.deviceId);
    await expectLater(
      PeerDialer.connectAny(
        ['127.0.0.1'],
        listener.port,
        me: phoneId,
        info: phoneInfo,
        expectedFingerprint: hubId.fingerprint,
        channel: ChannelKind.control,
        pairingSecret: wrongSecret,
      ),
      throwsA(isA<HandshakeException>()),
    );
    expect(sessions.active, isNull, reason: 'one failed attempt invalidates the code');
    expect(registry.devices, isEmpty);

    // A fresh code with the right secret works.
    final session2 = sessions.startManualCode(hubId.deviceId);
    final accepted = listener.connections.first;
    final ok = await PeerDialer.connectAny(
      ['127.0.0.1'],
      listener.port,
      me: phoneId,
      info: phoneInfo,
      expectedFingerprint: hubId.fingerprint,
      channel: ChannelKind.control,
      pairingSecret: PepoCrypto.manualCodeSecret(session2.code!, hubId.deviceId),
    );
    await accepted;
    expect(ok.newlyPaired, isTrue);
    await ok.connection.close();
  });

  test('wrong fingerprint never completes TLS', () async {
    final (listener, _, _) = await startHub();
    await expectLater(
      PeerDialer.connect('127.0.0.1', listener.port, expectedFingerprint: phoneId.fingerprint),
      throwsA(anyOf(isA<HandshakeException>(), isA<SocketException>(), isA<TlsException>())),
    );
  });
}
