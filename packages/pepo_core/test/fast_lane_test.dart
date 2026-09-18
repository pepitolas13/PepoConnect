// Two full engines (PC and phone) moving files on the fast lane: the Rust
// bulk engine on both ends, negotiated over the TLS control channel. Skipped
// when the library is not built (see native_support.dart).
@Tags(['native'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:pepo_core/pepo_core.dart';
import 'package:test/test.dart';

import 'native_support.dart';

void main() {
  final lib = nativeLibraryPath();
  if (lib == null) {
    test('fast lane library not built: skipped', () {}, skip: 'build packages/pepo_native/rust');
    return;
  }

  late Directory tmp;
  late PepoEngine hub;
  late PepoEngine phone;

  Future<void> boot({bool hubFast = true, bool phoneFast = true}) async {
    tmp = await Directory.systemTemp.createTemp('pepo_fast_');
    hub = PepoEngine(
      EngineConfig(
        dataDir: p.join(tmp.path, 'hub', 'data'),
        downloadRoot: p.join(tmp.path, 'hub', 'Pictures'),
        deviceName: 'PC',
        platform: DevicePlatform.windows,
        role: DeviceRole.hub,
        appVersion: 'test',
        listenPort: 0,
        udpDiscovery: false,
        fastLane: hubFast,
        nativeLibraryPath: lib,
      ),
    );
    phone = PepoEngine(
      EngineConfig(
        dataDir: p.join(tmp.path, 'phone', 'data'),
        downloadRoot: p.join(tmp.path, 'phone', 'Download'),
        deviceName: 'Pixel',
        platform: DevicePlatform.android,
        role: DeviceRole.phone,
        appVersion: 'test',
        listenPort: 0,
        udpDiscovery: false,
        fastLane: phoneFast,
        nativeLibraryPath: lib,
      ),
    );
    await hub.start();
    await phone.start();
    final invite = await hub.startQrPairing();
    final qr = QrPayload.tryParse(invite.qrText!)!;
    final loopback = QrPayload(
      deviceId: qr.deviceId,
      fingerprint: qr.fingerprint,
      name: qr.name,
      addresses: ['127.0.0.1'],
      port: qr.port,
      secret: qr.secret,
      expiresAt: qr.expiresAt,
    ).toString();
    final hubStatus = hub.events
        .where((e) => e is DeviceStatusChangedEvent)
        .first
        .timeout(const Duration(seconds: 15));
    final phoneStatus = phone.events
        .where((e) => e is DeviceStatusChangedEvent)
        .first
        .timeout(const Duration(seconds: 15));
    await phone.pairWithQrText(loopback);
    // device.info (which carries the fast lane port) has arrived on both ends.
    await hubStatus;
    await phoneStatus;
  }

  tearDown(() async {
    await phone.stop();
    await hub.stop();
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  Future<File> bigFile(String dir, String name, int size, {int seed = 1}) async {
    final f = File(p.join(dir, name));
    await f.parent.create(recursive: true);
    final rnd = Random(seed);
    final raf = await f.open(mode: FileMode.write);
    final block = Uint8List(1 << 20);
    var left = size;
    while (left > 0) {
      for (var i = 0; i < block.length; i++) {
        block[i] = rnd.nextInt(256);
      }
      final n = min(left, block.length);
      await raf.writeFrom(block, 0, n);
      left -= n;
    }
    await raf.close();
    return f;
  }

  Future<TransferRecord> terminal(
    PepoEngine e,
    int id, {
    Duration timeout = const Duration(seconds: 60),
  }) => e.events
      .where((x) => x is TransferChangedEvent && x.record.id == id && x.record.state.isTerminal)
      .cast<TransferChangedEvent>()
      .map((x) => x.record)
      .first
      .timeout(timeout);

  Future<bool> same(File a, File b) async {
    if (await a.length() != await b.length()) return false;
    final ra = a.openRead();
    final rb = await b.readAsBytes();
    var offset = 0;
    await for (final chunk in ra) {
      for (var i = 0; i < chunk.length; i++) {
        if (chunk[i] != rb[offset + i]) return false;
      }
      offset += chunk.length;
    }
    return true;
  }

  test('phone → PC on the fast lane (phone dials the PC listener)', () async {
    await boot();
    expect(hub.fastLaneAvailable, isTrue);
    expect(hub.fastLanePort, greaterThan(0));
    final src = await bigFile(p.join(tmp.path, 'phone', 'src'), 'VID_0001.mp4', 40 * 1024 * 1024);
    final t = (await phone.sendFiles(hub.deviceId, [src.path])).single;
    final hubSeen = hub.events
        .where((x) => x is TransferChangedEvent && x.record.id == t.id)
        .cast<TransferChangedEvent>()
        .firstWhere((x) => x.record.state == TransferState.done)
        .timeout(const Duration(seconds: 60));
    final r = await terminal(phone, t.id);
    expect(r.state, TransferState.done, reason: r.error);
    expect(r.fast, isTrue, reason: 'sender used the fast lane');
    final hr = (await hubSeen).record;
    expect(hr.fast, isTrue, reason: 'receiver used the fast lane');
    expect(hr.finalPath, isNotNull);
    expect(await same(src, File(hr.finalPath!)), isTrue);
    expect(hr.hash, r.hash);
  });

  test('PC → phone on the fast lane (phone dials as the receiver)', () async {
    await boot();
    final src = await bigFile(
      p.join(tmp.path, 'hub', 'src'),
      'setup.bin',
      24 * 1024 * 1024,
      seed: 2,
    );
    final t = (await hub.sendFiles(phone.deviceId, [src.path])).single;
    final phoneSeen = phone.events
        .where((x) => x is TransferChangedEvent && x.record.id == t.id)
        .cast<TransferChangedEvent>()
        .firstWhere((x) => x.record.state == TransferState.done)
        .timeout(const Duration(seconds: 60));
    final r = await terminal(hub, t.id);
    expect(r.state, TransferState.done, reason: r.error);
    expect(r.fast, isTrue);
    final pr = (await phoneSeen).record;
    expect(pr.fast, isTrue);
    expect(await same(src, File(pr.finalPath!)), isTrue);
  });

  test('pause on the fast lane keeps the partial file and resumes from it', () async {
    await boot();
    final src = await bigFile(
      p.join(tmp.path, 'phone', 'src'),
      'big.bin',
      256 * 1024 * 1024,
      seed: 3,
    );
    final t = (await phone.sendFiles(hub.deviceId, [src.path])).single;
    await hub.events
        .where(
          (x) =>
              x is TransferChangedEvent &&
              x.record.id == t.id &&
              x.record.bytesDone > 8 * 1024 * 1024,
        )
        .first
        .timeout(const Duration(seconds: 60));
    final phonePaused = phone.events
        .where(
          (x) =>
              x is TransferChangedEvent &&
              x.record.id == t.id &&
              x.record.state == TransferState.paused,
        )
        .first
        .timeout(const Duration(seconds: 30));
    await hub.cancelTransfer(t.id, pause: true);
    await phonePaused;
    final parts = await Directory(hub.config.downloadRoot)
        .list(recursive: true)
        .where((e) => e.path.endsWith('.pepopart'))
        .toList();
    expect(parts, hasLength(1));
    final kept = await File(parts.single.path).length();
    expect(kept, greaterThan(0));

    final hubDone = hub.events
        .where((x) => x is TransferChangedEvent && x.record.id == t.id)
        .cast<TransferChangedEvent>()
        .firstWhere((x) => x.record.state == TransferState.done)
        .timeout(const Duration(seconds: 120));
    final resumedEvents = <int>[];
    final sub = hub.events
        .where((x) => x is TransferChangedEvent && x.record.id == t.id)
        .cast<TransferChangedEvent>()
        .listen((x) => resumedEvents.add(x.record.bytesDone));
    expect(await phone.resumeTransfer(t.id), isTrue);
    final r = await terminal(phone, t.id, timeout: const Duration(seconds: 120));
    await sub.cancel();
    expect(r.state, TransferState.done, reason: r.error);
    expect(r.fast, isTrue);
    final hr = (await hubDone).record;
    expect(await same(src, File(hr.finalPath!)), isTrue);
    expect(
      resumedEvents.first,
      greaterThanOrEqualTo(kept),
      reason: 'continued from the kept bytes',
    );
  });

  test('a peer without the fast lane falls back to the TLS channels', () async {
    await boot(phoneFast: false);
    expect(phone.fastLaneAvailable, isFalse);
    final src = await bigFile(
      p.join(tmp.path, 'phone', 'src'),
      'IMG_1.jpg',
      4 * 1024 * 1024,
      seed: 4,
    );
    final t = (await phone.sendFiles(hub.deviceId, [src.path])).single;
    final hubSeen = hub.events
        .where((x) => x is TransferChangedEvent && x.record.id == t.id)
        .cast<TransferChangedEvent>()
        .firstWhere((x) => x.record.state == TransferState.done)
        .timeout(const Duration(seconds: 60));
    final r = await terminal(phone, t.id);
    expect(r.state, TransferState.done, reason: r.error);
    expect(r.fast, isFalse);
    final hr = (await hubSeen).record;
    expect(hr.fast, isFalse);
    expect(await same(src, File(hr.finalPath!)), isTrue);
  });

  test(
    'throughput: 512 MB phone → PC on the fast lane',
    () async {
      await boot();
      final src = await bigFile(
        p.join(tmp.path, 'phone', 'src'),
        'huge.bin',
        512 * 1024 * 1024,
        seed: 5,
      );
      final sw = Stopwatch()..start();
      final t = (await phone.sendFiles(hub.deviceId, [src.path])).single;
      final r = await terminal(phone, t.id, timeout: const Duration(minutes: 3));
      sw.stop();
      expect(r.state, TransferState.done, reason: r.error);
      expect(r.fast, isTrue);
      final mbps = 512 / (sw.elapsedMilliseconds / 1000);
      // ignore: avoid_print
      print('fast lane: 512 MB in ${sw.elapsedMilliseconds} ms = ${mbps.toStringAsFixed(0)} MB/s');
      expect(mbps, greaterThan(300));
    },
    tags: ['perf'],
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
