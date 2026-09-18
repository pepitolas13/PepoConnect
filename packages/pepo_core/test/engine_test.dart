import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pepo_core/pepo_core.dart';
import 'package:test/test.dart';

/// Two complete engines in one process: a hub (PC) and a "phone" that
/// publishes a folder as its gallery. This is the simulator used by the
/// desktop app during development as well.
void main() {
  late Directory tmp;
  late PepoEngine hub;
  late PepoEngine phone;

  Future<File> photo(String dir, String name) async {
    final f = File(p.join(dir, name));
    await f.writeAsBytes(ImageOps.solidJpeg(640, 480, r: name.length * 7 % 255), flush: true);
    return f;
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('pepo_engine_');
    final phoneRoot = Directory(p.join(tmp.path, 'phone', 'DCIM'))..createSync(recursive: true);
    await photo(phoneRoot.path, 'IMG_0001.jpg');
    hub = PepoEngine(
      EngineConfig(
        dataDir: p.join(tmp.path, 'hub', 'data'),
        downloadRoot: p.join(tmp.path, 'hub', 'Pictures', 'PepoConnect'),
        deviceName: 'PC de Daniel',
        platform: DevicePlatform.windows,
        role: DeviceRole.hub,
        appVersion: 'test',
        listenPort: 0,
        udpDiscovery: false,
      ),
    );
    phone = PepoEngine(
      EngineConfig(
        dataDir: p.join(tmp.path, 'phone', 'data'),
        downloadRoot: p.join(tmp.path, 'phone', 'Download'),
        deviceName: 'Pixel 8',
        platform: DevicePlatform.android,
        role: DeviceRole.phone,
        appVersion: 'test',
        listenPort: 0,
        mediaRoots: [phoneRoot.path],
        udpDiscovery: false,
      ),
    );
    await hub.start();
    await phone.start();
  });

  tearDown(() async {
    await phone.stop();
    await hub.stop();
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  Future<T> next<T extends EngineEvent>(
    PepoEngine e,
    bool Function(T) where, {
    Duration timeout = const Duration(seconds: 15),
  }) => e.events.where((x) => x is T && where(x)).cast<T>().first.timeout(timeout);

  Future<void> waitUntil(
    Future<bool> Function() condition, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!await condition()) {
      if (DateTime.now().isAfter(deadline)) fail('condition not met in $timeout');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<bool> sharesClipboard(PepoEngine e) async =>
      (await e.devices()).single.device.shareClipboard;

  test('full flow: QR pairing, gallery, new photo, download into per-device folder', () async {
    expect(hub.shortId, startsWith('PEPO-'));
    final invite = await hub.startQrPairing();
    expect(invite.qrText, startsWith('pepoconnect://pair/1?'));
    expect(invite.code, isNull);

    // The QR carries LAN addresses; the test only has loopback, so rewrite.
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

    final galleryReady = next<GalleryChangedEvent>(hub, (e) => e.change == GalleryChange.reset);
    final device = await phone.pairWithQrText(loopback);
    expect(device.name, 'PC de Daniel');
    expect(device.platform, DevicePlatform.windows);
    await galleryReady;
    expect(hub.currentInvite, isNull, reason: 'single use');

    final phoneId = phone.deviceId;
    final devices = await hub.devices();
    expect(devices.single.device.name, 'Pixel 8');
    expect(devices.single.connected, isTrue);
    expect(devices.single.device.folderName, 'Pixel 8');
    final g = hub.gallery.gallery(phoneId);
    expect(g.items.map((i) => i.name), ['IMG_0001.jpg']);
    expect(await hub.thumbnail(phoneId, g.items.single.id), isNotNull);

    // New photo → event on the hub with thumbnail already cached.
    final fresh = next<GalleryChangedEvent>(hub, (e) => e.change == GalleryChange.newItem);
    await photo(p.join(tmp.path, 'phone', 'DCIM'), 'IMG_0002.jpg');
    final ev = await fresh;
    expect(hub.gallery.cachedThumbnail(phoneId, ev.ids.single), isNotNull);
    expect(g.items.first.name, 'IMG_0002.jpg');

    // Download lands in <root>/Pixel 8/Fotos.
    final done = next<TransferChangedEvent>(
      hub,
      (e) => e.record.state == TransferState.done && e.record.sourceId == ev.ids.single,
    );
    await hub.downloadItems(phoneId, [ev.ids.single]);
    final t = await done;
    expect(t.record.finalPath, p.join(hub.config.downloadRoot, 'Pixel 8', 'Fotos', 'IMG_0002.jpg'));
    expect(await File(t.record.finalPath!).exists(), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(g.isDownloaded(ev.ids.single), isTrue);

    // Auto download: enabling it on the device makes the next photo arrive by itself.
    await hub.updateDevice(phoneId, autoDownload: true);
    final auto = next<TransferChangedEvent>(
      hub,
      (e) => e.record.state == TransferState.done && e.record.name == 'IMG_0003.jpg',
    );
    await photo(p.join(tmp.path, 'phone', 'DCIM'), 'IMG_0003.jpg');
    await auto;

    // Unified folders: switch the setting and send a plain file from the phone.
    hub.setSeparateByDevice(false);
    final plain = File(p.join(tmp.path, 'phone', 'notas.txt'))..writeAsStringSync('hola');
    final received = next<TransferChangedEvent>(
      hub,
      (e) => e.record.state == TransferState.done && e.record.name == 'notas.txt',
    );
    await phone.sendFiles(hub.deviceId, [plain.path]);
    final r = await received;
    expect(r.record.finalPath, p.join(hub.config.downloadRoot, 'Archivos', 'notas.txt'));

    // Clipboard text reaches the phone when sharing is enabled for it.
    await hub.updateDevice(phoneId, shareClipboard: true);
    final clip = next<ClipboardReceivedEvent>(phone, (e) => e.text == 'hola mundo');
    expect(hub.sendClipboard('hola mundo'), ['Pixel 8']);
    expect((await clip).deviceId, hub.deviceId);

    // One switch for the pair: the phone adopts the hub's flag and can push
    // its own clipboard back without touching its own settings.
    await waitUntil(() => sharesClipboard(phone));
    final back = next<ClipboardReceivedEvent>(hub, (e) => e.text == 'desde el móvil');
    expect(phone.sendClipboard('desde el móvil'), ['PC de Daniel']);
    expect((await back).deviceId, phone.deviceId);

    // Switching it off on the phone reaches the hub.
    await phone.updateDevice(hub.deviceId, shareClipboard: false);
    await waitUntil(() async => !await sharesClipboard(hub));
    expect(hub.sendClipboard('nada'), isEmpty);

    // Forget: both sides drop the device.
    final gone = next<DevicesChangedEvent>(phone, (_) => true);
    await hub.forget(phoneId);
    await gone;
    expect(await hub.devices(), isEmpty);
    expect(await phone.devices(), isEmpty);
  });

  test('manual code pairing between two desktops', () async {
    final invite = await hub.startCodePairing();
    expect(invite.code, matches(RegExp(r'^\d{6}$')));
    final connected = next<DeviceConnectionEvent>(hub, (e) => e.connected);
    final device = await phone.pairWithCode(
      code: invite.code!,
      host: '127.0.0.1',
      port: hub.listenPort,
    );
    expect(device.deviceId, hub.deviceId);
    await connected;
    expect((await hub.devices()).single.connected, isTrue);
  });

  test('clipboard switch: legacy true wins the tie, a later change wins afterwards', () async {
    final invite = await hub.startCodePairing();
    final connected = next<DeviceConnectionEvent>(hub, (e) => e.connected);
    await phone.pairWithCode(code: invite.code!, host: '127.0.0.1', port: hub.listenPort);
    await connected;
    final phoneId = phone.deviceId;

    // Record written before the flag was mirrored: on, no timestamp.
    final session = hub.sessions.session(phoneId)!;
    await hub.sessions.updateDevice(session.device.copyWith(shareClipboard: true));
    expect(session.device.shareClipboardAt, isNull);
    session.sendStatus();
    await waitUntil(() => sharesClipboard(phone));

    // A stamped change on the phone beats it...
    await phone.updateDevice(hub.deviceId, shareClipboard: false);
    await waitUntil(() async => !await sharesClipboard(hub));

    // ...and the hub's next status push does not switch it back on.
    session.sendStatus();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(await sharesClipboard(phone), isFalse);
    expect(await sharesClipboard(hub), isFalse);
  });
}
