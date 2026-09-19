import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pepo_core/src/identity/certificate_factory.dart';
import 'package:pepo_core/src/media/auto_send_queue.dart';
import 'package:pepo_core/src/media/gallery_client.dart';
import 'package:pepo_core/src/media/image_ops.dart';
import 'package:pepo_core/src/media/media_server.dart';
import 'package:pepo_core/src/media/media_source_fs.dart';
import 'package:pepo_core/src/net/session.dart';
import 'package:pepo_core/src/protocol/models.dart';
import 'package:pepo_core/src/transfer/transfer_engine.dart';
import 'package:pepo_core/src/transfer/transfer_record.dart';
import 'package:test/test.dart';

Future<File> writeJpeg(Directory dir, String name, {int w = 640, int h = 480, int r = 200}) async {
  final f = File(p.join(dir.path, name));
  await f.writeAsBytes(ImageOps.solidJpeg(w, h, r: r), flush: true);
  return f;
}

/// Polls [ready] until it holds or the time is up. The media source reports
/// a change on its own schedule and the server handles it asynchronously, so
/// there is nothing single to await.
Future<void> pumpUntil(
  bool Function() ready, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

void main() {
  group('auto send', () {
    const hubId = 'HUB00000000000000000000000';
    late Directory root;
    late Directory cache;
    late MediaSourceFs source;
    late SessionManager sessions;
    late TransferEngine transfers;
    late MemoryAutoSendStore store;
    late MediaServer server;

    Future<MediaServer> buildServer() async {
      source = MediaSourceFs(
        roots: [root.path],
        cacheDir: cache.path,
        settleTime: const Duration(milliseconds: 150),
      );
      sessions = SessionManager(
        identity: const CertificateFactory().generate(commonName: 'phone'),
        info: const LocalDeviceInfo(
          name: 'Phone',
          platform: DevicePlatform.android,
          role: DeviceRole.phone,
          appVersion: 't',
        ),
        deviceStore: MemoryDeviceStore(),
        preferredPort: 0,
      );
      transfers = TransferEngine(
        channels: sessions,
        store: MemoryTransferStore(),
        destination: (_, _) async => root.path,
      );
      sessions.transfers = transfers;
      final built = MediaServer(
        source: source,
        sessions: sessions,
        transfers: transfers,
        autoSendStore: store,
      );
      await built.start();
      return built;
    }

    setUp(() async {
      root = await Directory.systemTemp.createTemp('pepo_auto_');
      cache = await Directory.systemTemp.createTemp('pepo_autoc_');
      store = MemoryAutoSendStore();
    });

    tearDown(() async {
      await server.stop();
      await transfers.dispose();
      await sessions.dispose();
      for (final d in [root, cache]) {
        try {
          await d.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('a photo taken with the PC away waits in the queue', () async {
      server = await buildServer();
      await server.setAutoSend(hubId, true);
      expect(server.autoSendTo, {hubId});

      await writeJpeg(root, 'IMG_0100.jpg');
      await pumpUntil(() => server.autoSend.pendingCount == 1);
      expect(
        server.autoSend.pendingCount,
        1,
        reason: 'nothing is connected, so it has to be kept for later',
      );
    });

    test('the switch off means nothing is queued at all', () async {
      server = await buildServer();
      await writeJpeg(root, 'IMG_0100.jpg');
      final change = source.changes.first;
      await change.timeout(const Duration(seconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(server.autoSend.pendingCount, 0);
    });

    test('catch-up picks up what appeared while the process was down', () async {
      // The queue remembers the switch was already on and how far it got.
      final past = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      await store.save(AutoSendData(enabledSince: past, catchUpAt: past));
      await writeJpeg(root, 'IMG_0001.jpg');
      await writeJpeg(root, 'IMG_0002.jpg');

      server = await buildServer();
      await server.setAutoSend(hubId, true);
      expect(server.autoSend.enabledSince, past, reason: 'the mark must not move');
      expect(server.autoSend.pendingCount, 2);
    });

    test('turning it on now does not push the whole camera roll', () async {
      await writeJpeg(root, 'IMG_0001.jpg');
      await writeJpeg(root, 'IMG_0002.jpg');
      server = await buildServer();
      await server.setAutoSend(hubId, true);
      expect(server.autoSend.pendingCount, 0);
    });
  });

  group('MediaSourceFs', () {
    late Directory root;
    late Directory cache;
    late MediaSourceFs source;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('pepo_media_');
      cache = await Directory.systemTemp.createTemp('pepo_cache_');
      source = MediaSourceFs(
        roots: [root.path],
        cacheDir: cache.path,
        settleTime: const Duration(milliseconds: 150),
        rescanInterval: const Duration(seconds: 2),
      );
    });

    tearDown(() async {
      source.dispose();
      await root.delete(recursive: true);
      await cache.delete(recursive: true);
    });

    test('indexes images newest first with dimensions and serves thumbnails', () async {
      await writeJpeg(root, 'a.jpg', w: 800, h: 600);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await Directory(p.join(root.path, 'Camera')).create();
      await writeJpeg(root, 'Camera/b.jpg', w: 300, h: 900);
      await File(p.join(root.path, 'notes.txt')).writeAsString('x');
      await source.start();
      final page = await source.index();
      expect(page.total, 2);
      expect(page.items.map((i) => i.name), ['b.jpg', 'a.jpg']);
      expect(page.items.first.width, 300);
      expect(page.items.first.height, 900);
      expect(page.items.first.album, 'Camera');
      final thumb = await source.thumbnail(page.items.first.id, maxPx: 100);
      expect(thumb, isNotNull);
      final dims = ImageOps.dimensions(thumb!)!;
      expect(dims.height, 100);
      expect(dims.width, lessThanOrEqualTo(34));
      expect(await source.thumbnail('nope'), isNull);
      final preview = await source.preview(page.items.last.id, maxPx: 400);
      expect(ImageOps.dimensions(preview!)!.width, 400);
      expect(await source.originalPath(page.items.last.id), p.join(root.path, 'a.jpg'));
    });

    test('detects a new photo once it stops growing and deletions', () async {
      await source.start();
      expect((await source.index()).total, 0);
      final change = source.changes.first;
      final f = await writeJpeg(root, 'IMG_new.jpg');
      final c = await change.timeout(const Duration(seconds: 5));
      expect(c.added.single.name, 'IMG_new.jpg');
      expect((await source.index()).total, 1);
      final removal = source.changes.first;
      await f.delete();
      final r = await removal.timeout(const Duration(seconds: 5));
      expect(r.removed.single, c.added.single.id);
      expect((await source.index()).total, 0);
    });
  });

  group('end to end gallery', () {
    late Directory phoneRoot;
    late Directory phoneCache;
    late Directory hubDir;
    late Directory hubCache;
    late SessionManager hub;
    late SessionManager phone;
    late TransferEngine hubTransfers;
    late TransferEngine phoneTransfers;
    late MediaSourceFs source;
    late MediaServer server;
    late GalleryClient client;

    setUp(() async {
      phoneRoot = await Directory.systemTemp.createTemp('pepo_proot_');
      phoneCache = await Directory.systemTemp.createTemp('pepo_pcache_');
      hubDir = await Directory.systemTemp.createTemp('pepo_hdir_');
      hubCache = await Directory.systemTemp.createTemp('pepo_hcache_');
      await writeJpeg(phoneRoot, 'IMG_0001.jpg', r: 10);
      await writeJpeg(phoneRoot, 'IMG_0002.jpg', r: 20);

      hub = SessionManager(
        identity: const CertificateFactory().generate(commonName: 'hub'),
        info: const LocalDeviceInfo(
          name: 'PC',
          platform: DevicePlatform.windows,
          role: DeviceRole.hub,
          appVersion: 't',
        ),
        deviceStore: MemoryDeviceStore(),
        preferredPort: 0,
      );
      phone = SessionManager(
        identity: const CertificateFactory().generate(commonName: 'phone'),
        info: const LocalDeviceInfo(
          name: 'Phone',
          platform: DevicePlatform.android,
          role: DeviceRole.phone,
          appVersion: 't',
        ),
        deviceStore: MemoryDeviceStore(),
        preferredPort: 0,
      );
      hubTransfers = TransferEngine(
        channels: hub,
        store: MemoryTransferStore(),
        destination: (_, _) async => hubDir.path,
      );
      phoneTransfers = TransferEngine(
        channels: phone,
        store: MemoryTransferStore(),
        destination: (_, _) async => phoneRoot.path,
      );
      hub.transfers = hubTransfers;
      phone.transfers = phoneTransfers;
      source = MediaSourceFs(
        roots: [phoneRoot.path],
        cacheDir: phoneCache.path,
        settleTime: const Duration(milliseconds: 150),
      );
      server = MediaServer(source: source, sessions: phone, transfers: phoneTransfers);
      phone.handlers.add(server);
      client = GalleryClient(
        sessions: hub,
        transfers: hubTransfers,
        stateStore: MemoryMediaStateStore(),
        cacheDir: hubCache.path,
      );
      hub.handlers.add(client);
      await server.start();
      await hub.start();
      await phone.start();
    });

    tearDown(() async {
      await client.dispose();
      await server.stop();
      await phoneTransfers.dispose();
      await hubTransfers.dispose();
      await phone.dispose();
      await hub.dispose();
      for (final d in [phoneRoot, phoneCache, hubDir, hubCache]) {
        try {
          await d.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('markSeen clears the new marks and sets the watermark', () async {
      final session = hub.pairing.startQr();
      final payload = hub.pairing.payloadFor(
        session,
        deviceId: hub.identity.deviceId,
        fingerprint: hub.identity.fingerprint,
        name: 'PC',
        addresses: ['127.0.0.1'],
        port: hub.listenPort,
      );
      final reset = client.events.where((e) => e.change == GalleryChange.reset).first;
      await phone.pairWithQr(payload);
      await reset.timeout(const Duration(seconds: 10));
      final phoneId = phone.identity.deviceId;
      final g = client.gallery(phoneId);
      expect(g.items, hasLength(2));
      // What the index brings before the user ever looked is not new.
      expect(g.newCount, 0);
      expect(g.seenUntil, isNull);

      // A photo pushed live is new until the gallery is left.
      final newEvent = client.events.where((e) => e.change == GalleryChange.newItem).first;
      await writeJpeg(phoneRoot, 'IMG_0003.jpg', r: 30);
      final id3 = (await newEvent.timeout(const Duration(seconds: 10))).ids.single;
      expect(g.stateOf(id3), MediaState.fresh);
      expect(g.newCount, 1);

      final updated = client.events.where((e) => e.change == GalleryChange.updated).first;
      await client.markSeen(phoneId, g.items.map((i) => i.id));
      expect((await updated.timeout(const Duration(seconds: 5))).ids, [id3]);
      expect(g.stateOf(id3), MediaState.dismissed);
      expect(g.newCount, 0);
      final until = g.byId[id3]!.takenAt;
      expect(g.seenUntil, until);
      expect(await client.stateStore.loadSeenUntil(phoneId), until);

      // Items that show up without a stored state (an index reload after a
      // reconnect) are new only when captured after the watermark.
      g.states.remove(id3);
      expect(g.stateOf(id3), MediaState.dismissed);
      final later = MediaItem(
        id: 'later',
        kind: MediaKind.image,
        name: 'IMG_LATER.jpg',
        width: 8,
        height: 8,
        takenAt: until.add(const Duration(minutes: 1)),
        size: 1,
        mime: 'image/jpeg',
      );
      g.byId[later.id] = later;
      expect(g.stateOf(later.id), MediaState.fresh);
      await client.markSeen(phoneId, [later.id]);
      expect(g.stateOf(later.id), MediaState.dismissed);
      expect(g.seenUntil, later.takenAt);
    });

    test('index, thumbnails, preview, live new photo, download', () async {
      final session = hub.pairing.startQr();
      final payload = hub.pairing.payloadFor(
        session,
        deviceId: hub.identity.deviceId,
        fingerprint: hub.identity.fingerprint,
        name: 'PC',
        addresses: ['127.0.0.1'],
        port: hub.listenPort,
      );
      final reset = client.events.where((e) => e.change == GalleryChange.reset).first;
      await phone.pairWithQr(payload);
      await reset.timeout(const Duration(seconds: 10));
      final phoneId = phone.identity.deviceId;
      final g = client.gallery(phoneId);
      expect(g.items, hasLength(2));
      expect(g.total, 2);

      // Thumbnails are batched into one request and cached on disk.
      final thumbs = await Future.wait(g.items.map((i) => client.thumbnail(phoneId, i.id)));
      expect(thumbs.every((t) => t != null && t.isNotEmpty), isTrue);
      expect(client.cachedThumbnail(phoneId, g.items.first.id), isNotNull);
      var diskThumbs = 0;
      for (var i = 0; i < 40 && diskThumbs < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        diskThumbs = await Directory(hubCache.path)
            .list(recursive: true)
            .where((e) => e.path.endsWith('.jpg'))
            .length;
      }
      expect(diskThumbs, 2, reason: 'thumbnails are cached on disk');

      // Preview goes over the media channel and marks the item previewed.
      final preview = await client.preview(phoneId, g.items.first.id);
      expect(preview, isNotNull);
      expect(ImageOps.dimensions(preview!)!.width, 640);
      expect(g.stateOf(g.items.first.id), MediaState.previewed);

      // A new photo on the phone shows up on the hub with its thumbnail inline.
      final newEvent = client.events.where((e) => e.change == GalleryChange.newItem).first;
      final sw = Stopwatch()..start();
      await writeJpeg(phoneRoot, 'IMG_0003.jpg', r: 30);
      final ev = await newEvent.timeout(const Duration(seconds: 10));
      sw.stop();
      expect(g.items.first.name, 'IMG_0003.jpg');
      expect(g.items, hasLength(3));
      expect(client.cachedThumbnail(phoneId, ev.ids.single), isNotNull);
      expect(g.stateOf(ev.ids.single), MediaState.fresh);
      // ignore: avoid_print
      print('new photo visible on hub after ${sw.elapsedMilliseconds} ms');

      // Download the original: the transfer completes and the state flips.
      final downloaded = client.events
          .where(
            (e) =>
                e.change == GalleryChange.updated &&
                g.stateOf(ev.ids.single) == MediaState.downloaded,
          )
          .first;
      await client.download(phoneId, ev.ids.single);
      await downloaded.timeout(const Duration(seconds: 20));
      final local = g.localPath(ev.ids.single)!;
      expect(p.basename(local), 'IMG_0003.jpg');
      expect(
        await File(local).length(),
        await File(p.join(phoneRoot.path, 'IMG_0003.jpg')).length(),
      );

      // Delete on the device propagates.
      final removed = client.events.where((e) => e.change == GalleryChange.removed).first;
      final deleted = await client.deleteOnDevice(phoneId, [g.items.last.id]);
      expect(deleted, hasLength(1));
      await removed.timeout(const Duration(seconds: 5));
      expect(g.items, hasLength(2));
    });
  });
}
