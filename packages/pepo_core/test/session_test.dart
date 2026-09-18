import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:pepo_core/src/identity/certificate_factory.dart';
import 'package:pepo_core/src/net/session.dart';
import 'package:pepo_core/src/protocol/models.dart';
import 'package:pepo_core/src/transfer/transfer_engine.dart';
import 'package:pepo_core/src/transfer/transfer_record.dart';
import 'package:test/test.dart';

class Node {
  Node._();

  late SessionManager manager;
  late TransferEngine engine;
  late Directory dir;
  final store = MemoryDeviceStore();

  String get id => manager.identity.deviceId;

  static Future<Node> start(String name, DeviceRole role) async {
    final n = Node._();
    n.dir = await Directory.systemTemp.createTemp('pepo_${name}_');
    n.manager = SessionManager(
      identity: const CertificateFactory().generate(commonName: name),
      info: LocalDeviceInfo(
        name: name,
        platform: role == DeviceRole.hub ? DevicePlatform.windows : DevicePlatform.android,
        role: role,
        appVersion: 'test',
      ),
      deviceStore: n.store,
      preferredPort: 0,
    );
    n.engine = TransferEngine(
      channels: n.manager,
      store: MemoryTransferStore(),
      destination: (_, _) async => n.dir.path,
    );
    n.manager.transfers = n.engine;
    await n.manager.start();
    return n;
  }

  Future<void> dispose() async {
    await engine.dispose();
    await manager.dispose();
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  }
}

Future<T> nextEvent<T extends SessionEvent>(SessionManager m, {Duration timeout = const Duration(seconds: 10)}) =>
    m.events.where((e) => e is T).cast<T>().first.timeout(timeout);

Future<File> makeFile(Directory dir, String name, int bytes) async {
  final f = File(p.join(dir.path, name));
  final sink = f.openWrite();
  var left = bytes;
  final block = List<int>.generate(65536, (i) => (i * 31) & 0xFF);
  while (left > 0) {
    final n = left < block.length ? left : block.length;
    sink.add(block.sublist(0, n));
    left -= n;
  }
  await sink.close();
  return f;
}

void main() {
  late Node hub;
  late Node phone;

  setUpAll(() {
    if (Platform.environment['PEPO_LOG'] == '1') {
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen((r) => print('[${r.loggerName}] ${r.message}'));
    }
  });

  setUp(() async {
    hub = await Node.start('PC', DeviceRole.hub);
    phone = await Node.start('Phone', DeviceRole.phone);
  });

  tearDown(() async {
    await phone.dispose();
    await hub.dispose();
  });

  test('pair by QR, transfer both ways, survive a drop, forget', () async {
    // --- Pair ------------------------------------------------------------
    final session = hub.manager.pairing.startQr();
    final payload = hub.manager.pairing.payloadFor(
      session,
      deviceId: hub.id,
      fingerprint: hub.manager.identity.fingerprint,
      name: 'PC',
      addresses: ['127.0.0.1'],
      port: hub.manager.listenPort,
    );
    final hubPaired = nextEvent<DevicePairedEvent>(hub.manager);
    final hubConnected = nextEvent<DeviceConnectedEvent>(hub.manager);
    final device = await phone.manager.pairWithQr(payload);
    expect(device.deviceId, hub.id);
    expect(device.weInitiate, isTrue);
    expect((await hubPaired).device.deviceId, phone.id);
    await hubConnected;
    expect(phone.manager.session(hub.id)!.isConnected, isTrue);
    expect(hub.manager.session(phone.id)!.isConnected, isTrue);
    expect((await hub.store.all()).single.weInitiate, isFalse);

    // Status exchange happens right after connecting.
    final status = await nextEvent<DeviceStatusEvent>(hub.manager);
    expect(status.deviceId, phone.id);

    // --- Hub -> phone: the listener asks the phone to dial a bulk channel --
    final fromHub = await makeFile(hub.dir, 'from-pc.bin', 3 * 1024 * 1024);
    final t1 = await hub.engine.send(deviceId: phone.id, path: fromHub.path);
    final r1 = await hub.engine.events
        .where((e) => e.record.id == t1.id && e.record.state.isTerminal)
        .first
        .timeout(const Duration(seconds: 30));
    expect(r1.record.state, TransferState.done, reason: r1.record.error);
    expect(await File(p.join(phone.dir.path, 'from-pc.bin')).length(), 3 * 1024 * 1024);

    // --- Phone -> hub ------------------------------------------------------
    final fromPhone = await makeFile(phone.dir, 'IMG_1.jpg', 2 * 1024 * 1024);
    final t2 = await phone.engine.send(deviceId: hub.id, path: fromPhone.path, mediaKind: MediaKind.image);
    final r2 = await phone.engine.events
        .where((e) => e.record.id == t2.id && e.record.state.isTerminal)
        .first
        .timeout(const Duration(seconds: 30));
    expect(r2.record.state, TransferState.done, reason: r2.record.error);
    expect(await File(p.join(hub.dir.path, 'IMG_1.jpg')).length(), 2 * 1024 * 1024);

    // --- Drop the control channel: the initiator reconnects by itself ------
    final hubDisconnected = nextEvent<DeviceDisconnectedEvent>(hub.manager);
    final hubReconnected = nextEvent<DeviceConnectedEvent>(hub.manager, timeout: const Duration(seconds: 15));
    final phoneReconnected = nextEvent<DeviceConnectedEvent>(phone.manager, timeout: const Duration(seconds: 15));
    await phone.manager.session(hub.id)!.control!.close();
    await hubDisconnected;
    await hubReconnected;
    await phoneReconnected;
    expect(phone.manager.session(hub.id)!.isConnected, isTrue);

    // A transfer after the reconnect still works (new session token).
    final t3 = await phone.engine.send(deviceId: hub.id, path: fromPhone.path, name: 'IMG_2.jpg');
    final r3 = await phone.engine.events
        .where((e) => e.record.id == t3.id && e.record.state.isTerminal)
        .first
        .timeout(const Duration(seconds: 30));
    expect(r3.record.state, TransferState.done, reason: r3.record.error);

    // --- Forget from the hub: the phone is told and forgets too -----------
    final phoneForgot = nextEvent<DeviceForgottenEvent>(phone.manager);
    await hub.manager.forget(phone.id);
    await phoneForgot;
    expect(await hub.store.all(), isEmpty);
    expect(await phone.store.all(), isEmpty);
    expect(phone.manager.session(hub.id), isNull);
  });

  test('a restarted initiator reconnects from its stored device list', () async {
    final session = hub.manager.pairing.startQr();
    final payload = hub.manager.pairing.payloadFor(session,
        deviceId: hub.id,
        fingerprint: hub.manager.identity.fingerprint,
        name: 'PC',
        addresses: ['127.0.0.1'],
        port: hub.manager.listenPort);
    final hubConnected = nextEvent<DeviceConnectedEvent>(hub.manager);
    await phone.manager.pairWithQr(payload);
    await hubConnected;

    // Simulate an app restart on the phone: same identity, same store.
    final identity = phone.manager.identity;
    final store = phone.store;
    final hubDisconnected = nextEvent<DeviceDisconnectedEvent>(hub.manager);
    await phone.manager.dispose();
    await hubDisconnected;
    final hubReconnected = nextEvent<DeviceConnectedEvent>(hub.manager, timeout: const Duration(seconds: 15));
    phone.manager = SessionManager(
      identity: identity,
      info: const LocalDeviceInfo(
          name: 'Phone', platform: DevicePlatform.android, role: DeviceRole.phone, appVersion: 'test'),
      deviceStore: store,
      preferredPort: 0,
    );
    phone.engine = TransferEngine(
      channels: phone.manager,
      store: MemoryTransferStore(),
      destination: (_, _) async => phone.dir.path,
    );
    phone.manager.transfers = phone.engine;
    final phoneConnected = nextEvent<DeviceConnectedEvent>(phone.manager, timeout: const Duration(seconds: 15));
    await phone.manager.start();
    await hubReconnected;
    await phoneConnected;
    expect(phone.manager.session(hub.id)!.isConnected, isTrue);
  });
}
