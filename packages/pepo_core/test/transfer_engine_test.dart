import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:pepo_core/src/identity/certificate_factory.dart';
import 'package:pepo_core/src/identity/identity.dart';
import 'package:pepo_core/src/net/handshake.dart';
import 'package:pepo_core/src/net/peer_connection.dart';
import 'package:pepo_core/src/net/peer_listener.dart';
import 'package:pepo_core/src/pairing/pairing_session.dart';
import 'package:pepo_core/src/protocol/message_types.dart';
import 'package:pepo_core/src/protocol/models.dart';
import 'package:pepo_core/src/transfer/transfer_engine.dart';
import 'package:pepo_core/src/transfer/transfer_record.dart';
import 'package:test/test.dart';

/// Two real devices over TLS on loopback: [phone] dials, [hub] listens.
class Pair {
  Pair._();

  late Identity hubId;
  late Identity phoneId;
  late PeerListener listener;
  late PeerConnection hubControl;
  late PeerConnection phoneControl;
  late PairedDevice phoneKnowsHub;
  late String sessionToken;
  final hubRegistry = _Registry();
  late PhoneChannels phoneChannels;
  late HubChannels hubChannels;
  late TransferEngine phoneEngine;
  late TransferEngine hubEngine;
  late Directory hubDir;
  late Directory phoneDir;
  final hubStore = MemoryTransferStore();
  final phoneStore = MemoryTransferStore();

  static Future<Pair> create({int chunkSize = 256 * 1024}) async {
    final pr = Pair._();
    pr.hubId = const CertificateFactory().generate(commonName: 'hub');
    pr.phoneId = const CertificateFactory().generate(commonName: 'phone');
    final sessions = PairingSessions();
    pr.listener = PeerListener(
      identity: pr.hubId,
      info: const LocalDeviceInfo(
          name: 'PC', platform: DevicePlatform.windows, role: DeviceRole.hub, appVersion: 't'),
      registry: pr.hubRegistry,
      pairingSessions: sessions,
      tokens: SessionTokens(),
    );
    await pr.listener.start(preferredPort: 0);
    final session = sessions.startQr();
    final accepted = pr.listener.connections.first;
    final phoneResult = await PeerDialer.connectAny(
      ['127.0.0.1'],
      pr.listener.port,
      me: pr.phoneId,
      info: const LocalDeviceInfo(
          name: 'Phone', platform: DevicePlatform.android, role: DeviceRole.phone, appVersion: 't'),
      expectedFingerprint: pr.hubId.fingerprint,
      channel: ChannelKind.control,
      pairingSecret: session.secret,
    );
    final hubResult = await accepted;
    pr.phoneControl = phoneResult.connection;
    pr.hubControl = hubResult.connection;
    pr.phoneKnowsHub = phoneResult.device;
    pr.sessionToken = phoneResult.sessionToken;
    pr.hubDir = await Directory.systemTemp.createTemp('pepo_hub_');
    pr.phoneDir = await Directory.systemTemp.createTemp('pepo_phone_');

    pr.hubChannels = HubChannels(pr);
    pr.phoneChannels = PhoneChannels(pr);
    pr.hubEngine = TransferEngine(
      channels: pr.hubChannels,
      store: pr.hubStore,
      destination: (_, _) async => pr.hubDir.path,
      chunkSize: chunkSize,
    );
    pr.phoneEngine = TransferEngine(
      channels: pr.phoneChannels,
      store: pr.phoneStore,
      destination: (_, _) async => pr.phoneDir.path,
      chunkSize: chunkSize,
    );
    // Route control messages to the engines.
    pr.hubControl.messages.listen((m) => pr.hubEngine.handleControl(pr.phoneId.deviceId, pr.hubControl, m));
    pr.phoneControl.messages.listen((m) => pr.phoneEngine.handleControl(pr.hubId.deviceId, pr.phoneControl, m));
    // Bulk channels accepted by the hub are attached to its engine.
    pr.listener.connections.listen((r) {
      if (r.channel == ChannelKind.bulk) {
        pr.hubChannels.incomingBulk.add(r.connection);
        pr.hubEngine.attachBulk(r.device.deviceId, r.connection);
      }
    });
    return pr;
  }

  Future<void> dispose() async {
    await phoneEngine.dispose();
    await hubEngine.dispose();
    await phoneControl.close();
    await hubControl.close();
    await listener.dispose();
    try {
      await hubDir.delete(recursive: true);
      await phoneDir.delete(recursive: true);
    } catch (_) {}
  }
}

class _Registry implements PeerRegistry {
  final Map<String, PairedDevice> devices = {};
  @override
  Future<PairedDevice?> findDevice(String deviceId) async => devices[deviceId];
  @override
  Future<void> saveDevice(PairedDevice device) async => devices[device.deviceId] = device;
}

/// Phone side: dials new bulk channels with the session token.
class PhoneChannels implements ChannelProvider {
  PhoneChannels(this.pair);
  final Pair pair;
  final List<PeerConnection> idle = [];
  int opened = 0;

  @override
  PeerConnection? controlFor(String deviceId) => pair.phoneControl.isClosed ? null : pair.phoneControl;

  @override
  Future<PeerConnection> acquireBulk(String deviceId) async {
    if (idle.isNotEmpty) return idle.removeLast();
    opened++;
    final r = await PeerDialer.connectAny(
      ['127.0.0.1'],
      pair.listener.port,
      me: pair.phoneId,
      info: const LocalDeviceInfo(
          name: 'Phone', platform: DevicePlatform.android, role: DeviceRole.phone, appVersion: 't'),
      expectedFingerprint: pair.hubId.fingerprint,
      channel: ChannelKind.bulk,
      known: pair.phoneKnowsHub,
      sessionToken: pair.sessionToken,
    );
    pair.phoneEngine.attachBulk(deviceId, r.connection);
    return r.connection;
  }

  @override
  void releaseBulk(String deviceId, PeerConnection conn, {bool broken = false}) {
    if (broken) {
      conn.close();
    } else {
      idle.add(conn);
    }
  }
}

/// Hub side: asks the phone to open a bulk channel (chan.open) and waits.
class HubChannels implements ChannelProvider {
  HubChannels(this.pair);
  final Pair pair;
  final incomingBulk = StreamController<PeerConnection>.broadcast();
  final List<PeerConnection> idle = [];

  @override
  PeerConnection? controlFor(String deviceId) => pair.hubControl.isClosed ? null : pair.hubControl;

  @override
  Future<PeerConnection> acquireBulk(String deviceId) async {
    if (idle.isNotEmpty) return idle.removeLast();
    // In the real session layer chan.open is a request the phone answers by
    // dialing; here the test opens it directly.
    final future = incomingBulk.stream.first;
    unawaited(pair.phoneChannels.acquireBulk(pair.hubId.deviceId).then((c) => pair.phoneChannels.idle.add(c)));
    return future.timeout(const Duration(seconds: 5));
  }

  @override
  void releaseBulk(String deviceId, PeerConnection conn, {bool broken = false}) {
    if (broken) {
      conn.close();
    } else {
      idle.add(conn);
    }
  }
}

Future<File> writeRandom(Directory dir, String name, int size, {int seed = 1}) async {
  final f = File(p.join(dir.path, name));
  final sink = f.openWrite();
  final r = Random(seed);
  var left = size;
  final block = Uint8List(1 << 20);
  while (left > 0) {
    for (var i = 0; i < block.length; i++) {
      block[i] = r.nextInt(256);
    }
    final n = min(left, block.length);
    sink.add(Uint8List.sublistView(block, 0, n));
    left -= n;
  }
  await sink.close();
  return f;
}

Future<bool> sameContent(File a, File b) async {
  final la = await a.length();
  if (la != await b.length()) return false;
  final ra = await a.open();
  final rb = await b.open();
  try {
    var left = la;
    while (left > 0) {
      final ca = await ra.read(min(left, 1 << 20));
      final cb = await rb.read(ca.length);
      for (var i = 0; i < ca.length; i++) {
        if (ca[i] != cb[i]) return false;
      }
      left -= ca.length;
    }
    return true;
  } finally {
    await ra.close();
    await rb.close();
  }
}

Future<TransferRecord> waitTerminal(TransferEngine engine, int id, {Duration timeout = const Duration(seconds: 60)}) {
  return engine.events
      .where((e) => e.record.id == id && e.record.state.isTerminal)
      .map((e) => e.record)
      .first
      .timeout(timeout);
}

void main() {
  late Pair pair;

  setUp(() async => pair = await Pair.create());
  tearDown(() => pair.dispose());

  test('phone sends a 24 MB file to the hub over TLS', () async {
    final src = await writeRandom(pair.phoneDir, 'IMG_0001.jpg', 24 * 1024 * 1024);
    final terminal = waitTerminal(pair.hubEngine, -1); // placeholder, replaced below
    terminal.ignore();
    final sw = Stopwatch()..start();
    final queued = await pair.phoneEngine.send(deviceId: pair.hubId.deviceId, path: src.path, mediaKind: MediaKind.image);
    final result = await waitTerminal(pair.phoneEngine, queued.id);
    sw.stop();
    expect(result.state, TransferState.done, reason: result.error);
    final received = File(p.join(pair.hubDir.path, 'IMG_0001.jpg'));
    expect(await received.exists(), isTrue);
    expect(await sameContent(src, received), isTrue);
    expect(await Directory(pair.hubDir.path).list().where((e) => e.path.endsWith('.pepopart')).isEmpty, isTrue);
    final mbps = 24 * 1024 * 1024 / 1048576 / (sw.elapsedMilliseconds / 1000);
    // ignore: avoid_print
    print('24 MB in ${sw.elapsedMilliseconds} ms = ${mbps.toStringAsFixed(0)} MB/s (loopback TLS)');
    expect(result.hash, isNotEmpty);
  });

  test('hub sends to the phone (reverse direction) and names collide safely', () async {
    final src = await writeRandom(pair.hubDir, 'doc.pdf', 300 * 1024, seed: 5);
    final existing = File(p.join(pair.phoneDir.path, 'doc.pdf'))..writeAsStringSync('old');
    final t = await pair.hubEngine.send(deviceId: pair.phoneId.deviceId, path: src.path);
    final r = await waitTerminal(pair.hubEngine, t.id);
    expect(r.state, TransferState.done, reason: r.error);
    expect(r.finalPath, 'doc (2).pdf');
    expect(await sameContent(src, File(p.join(pair.phoneDir.path, 'doc (2).pdf'))), isTrue);
    expect(existing.readAsStringSync(), 'old');
  });

  test('three files in parallel reuse bulk channels', () async {
    final files = <File>[];
    for (var i = 0; i < 3; i++) {
      files.add(await writeRandom(pair.phoneDir, 'clip$i.mp4', (2 + i) * 1024 * 1024, seed: 10 + i));
    }
    final ids = <int>[];
    for (final f in files) {
      ids.add((await pair.phoneEngine.send(deviceId: pair.hubId.deviceId, path: f.path)).id);
    }
    final results = await Future.wait(ids.map((id) => waitTerminal(pair.phoneEngine, id)));
    for (var i = 0; i < 3; i++) {
      expect(results[i].state, TransferState.done, reason: results[i].error);
      expect(await sameContent(files[i], File(p.join(pair.hubDir.path, 'clip$i.mp4'))), isTrue);
    }
    expect(pair.phoneChannels.opened, lessThanOrEqualTo(3));
    // A fourth file reuses an idle channel.
    final f4 = await writeRandom(pair.phoneDir, 'clip4.mp4', 1024 * 1024, seed: 99);
    final t4 = await pair.phoneEngine.send(deviceId: pair.hubId.deviceId, path: f4.path);
    expect((await waitTerminal(pair.phoneEngine, t4.id)).state, TransferState.done);
    expect(pair.phoneChannels.opened, lessThanOrEqualTo(3));
  });

  test('pause mid-way and resume from the kept offset', () async {
    final src = await writeRandom(pair.phoneDir, 'big.bin', 16 * 1024 * 1024, seed: 7);
    final t = await pair.phoneEngine.send(deviceId: pair.hubId.deviceId, path: src.path);
    // Pause once the hub has written a few MB.
    await pair.hubEngine.events
        .firstWhere((e) => e.record.id == t.id && e.record.bytesDone > 4 * 1024 * 1024)
        .timeout(const Duration(seconds: 20));
    final pausedFuture = pair.phoneEngine.events
        .where((e) => e.record.id == t.id && (e.record.state == TransferState.paused || e.record.state.isTerminal))
        .map((e) => e.record)
        .first
        .timeout(const Duration(seconds: 20));
    await pair.hubEngine.cancel(t.id, reason: CancelReason.pause);
    final paused = await pausedFuture;
    final part = await Directory(pair.hubDir.path)
        .list()
        .where((e) => e.path.endsWith('.pepopart'))
        .toList();
    final hubPaused = (await pair.hubStore.all()).where((r) => r.state == TransferState.paused).toList();
    expect(hubPaused, hasLength(1), reason: 'hub keeps a resumable record');
    expect(part, hasLength(1));
    final keptBytes = await File(part.single.path).length();
    expect(keptBytes, greaterThan(4 * 1024 * 1024));
    expect(paused.state, isIn([TransferState.paused, TransferState.cancelled, TransferState.done]));

    // Resume: the phone re-offers and the hub accepts from the kept offset.
    final t2 = await pair.phoneEngine.send(deviceId: pair.hubId.deviceId, path: src.path);
    final progressEvents = <int>[];
    final sub = pair.hubEngine.events.where((e) => e.record.id == t2.id).listen((e) => progressEvents.add(e.record.bytesDone));
    final r2 = await waitTerminal(pair.phoneEngine, t2.id);
    await sub.cancel();
    expect(r2.state, TransferState.done, reason: r2.error);
    expect(progressEvents.first, greaterThanOrEqualTo(keptBytes), reason: 'started from the kept offset');
    expect(await sameContent(src, File(p.join(pair.hubDir.path, 'big.bin'))), isTrue);
  });

  test('abort deletes the partial file on the receiver', () async {
    final src = await writeRandom(pair.phoneDir, 'cancel.bin', 8 * 1024 * 1024, seed: 3);
    final t = await pair.phoneEngine.send(deviceId: pair.hubId.deviceId, path: src.path);
    await pair.hubEngine.events
        .firstWhere((e) => e.record.id == t.id && e.record.bytesDone > 1024 * 1024)
        .timeout(const Duration(seconds: 20));
    final terminal = waitTerminal(pair.phoneEngine, t.id);
    await pair.phoneEngine.cancel(t.id);
    final r = await terminal;
    expect(r.state, TransferState.cancelled);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final leftovers = await Directory(pair.hubDir.path).list().toList();
    expect(leftovers.where((e) => e.path.contains('cancel.bin')), isEmpty);
  });

  test('throughput: 512 MB over loopback TLS', () async {
    final src = await writeRandom(pair.phoneDir, 'huge.bin', 512 * 1024 * 1024, seed: 42);
    final sw = Stopwatch()..start();
    final t = await pair.phoneEngine.send(deviceId: pair.hubId.deviceId, path: src.path);
    final r = await waitTerminal(pair.phoneEngine, t.id, timeout: const Duration(minutes: 5));
    sw.stop();
    expect(r.state, TransferState.done, reason: r.error);
    final mbps = 512 / (sw.elapsedMilliseconds / 1000);
    // ignore: avoid_print
    print('512 MB in ${sw.elapsedMilliseconds} ms = ${mbps.toStringAsFixed(0)} MB/s');
    expect(mbps, greaterThan(50));
  }, tags: ['perf'], timeout: const Timeout(Duration(minutes: 6)));
}
