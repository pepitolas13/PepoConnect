// Real end-to-end run on a desktop: the full app (the PC) and a headless
// "phone" engine in the same process, talking over real TLS sockets on
// loopback. Run with:
//   flutter test integration_test/e2e_test.dart -d windows
// Everything lives in a temp folder; the user's settings are mocked.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pepo_core/pepo_core.dart';
import 'package:pepoconnect/app/app.dart';
import 'package:pepoconnect/app/app_services.dart';
import 'package:pepoconnect/app/bootstrap.dart';
import 'package:pepoconnect/app/shell/nav_rail.dart';
import 'package:pepoconnect/features/gallery/gallery_tile.dart';
import 'package:pepoconnect/shared/motion/toast.dart';
import 'package:pepoconnect/shared/widgets/fluent_button.dart';
import 'package:pepoconnect/state/app_settings.dart';
import 'package:pepoconnect/state/engine_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const hubPort = 47610;
const phonePort = 47611;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pair by QR, new photo, download, transfers both ways', (tester) async {
    final root = await Directory.systemTemp.createTemp('pepo_e2e_');
    final hubData = p.join(root.path, 'hub');
    final hubDownloads = p.join(root.path, 'hub_downloads');
    final phoneData = p.join(root.path, 'phone');
    final phoneMedia = p.join(root.path, 'phone_media');
    final phoneDownloads = p.join(root.path, 'phone_downloads');
    for (final d in [hubData, hubDownloads, phoneData, phoneMedia, phoneDownloads]) {
      await Directory(d).create(recursive: true);
    }

    // The PC: the real bootstrap with temp paths and mocked preferences.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsNotifier.load(prefs);
    final hub = await startEngine(
      settings: settings,
      paths: AppPaths(
        dataDir: hubData,
        defaultDownloadRoot: hubDownloads,
        cacheDir: p.join(hubData, 'cache'),
      ),
      options: const LaunchOptions(profile: 'e2e', port: hubPort),
    );

    // The phone: headless engine whose gallery is a watched folder.
    final phone = PepoEngine(
      EngineConfig(
        dataDir: phoneData,
        downloadRoot: phoneDownloads,
        deviceName: 'Pixel E2E',
        platform: DevicePlatform.android,
        role: DeviceRole.phone,
        appVersion: '0.0.0',
        listenPort: phonePort,
        udpDiscovery: false,
        profile: 'e2e-phone',
      ),
      mediaSource: MediaSourceFs(
        roots: [phoneMedia],
        cacheDir: p.join(phoneData, 'cache'),
        settleTime: const Duration(milliseconds: 300),
      ),
    );
    await phone.start();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        engineProvider.overrideWithValue(hub),
        dataDirProvider.overrideWithValue(hubData),
        toastServiceProvider.overrideWithValue(ToastService()),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await hub.stop();
      await phone.stop();
      try {
        await root.delete(recursive: true);
      } catch (_) {}
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const PepoApp()),
    );
    await settle(tester);

    // 1. First run: onboarding → "Añadir móvil" → pairing page with a QR.
    expect(find.text('¿Cómo quieres usar PepoConnect?'), findsOneWidget);
    await tester.tap(find.text('Añadir móvil'));
    await settle(tester);
    final invite = await waitFor(tester, () {
      final i = hub.currentInvite;
      return i?.qrText == null ? null : i;
    }, what: 'QR invite');
    expect(invite.port, hubPort);

    // 2. The phone "scans" the QR (pointed at loopback so the LAN is not needed).
    final uri = Uri.parse(invite.qrText!);
    final qr = uri.replace(queryParameters: {...uri.queryParameters, 'a': '127.0.0.1'}).toString();
    final pc = await phone.pairWithQrText(qr);
    expect(pc.name, contains('e2e'));
    final phoneId = phone.identity.deviceId;

    // 3. The PC shows "Emparejado"; "Empezar" lands on the gallery.
    await pumpUntilFound(tester, find.text('Emparejado'), timeout: const Duration(seconds: 15));
    await tester.tap(find.text('Empezar'));
    await settle(tester);
    await pumpUntilFound(tester, find.textContaining('Pixel E2E'));
    await waitFor(tester, () async {
      final d = await hub.devices();
      return d.length == 1 && d.single.connected && d.single.deviceId == phoneId ? true : null;
    }, what: 'phone connected on the PC');

    // 4. A photo taken on the phone appears on the PC as "Nuevo".
    final photo = File(p.join(phoneMedia, 'IMG_E2E_0001.jpg'));
    await photo.writeAsBytes(ImageOps.solidJpeg(1600, 1200, r: 200, g: 120, b: 40));
    final t0 = DateTime.now();
    await pumpUntilFound(tester, find.text('Nuevo'), timeout: const Duration(seconds: 20));
    final latency = DateTime.now().difference(t0);
    // ignore: avoid_print
    print('e2e: new photo visible on the PC after ${latency.inMilliseconds} ms');
    expect(find.byType(GalleryTile), findsOneWidget);

    // 5. Select it and download from the selection bar.
    await tester.tap(find.byType(GalleryTile));
    await tester.pump(const Duration(milliseconds: 400));
    await pumpUntilFound(tester, find.textContaining('1 seleccionado'));
    await tester.tap(find.widgetWithText(FluentButton, 'Descargar'));
    final downloaded = await waitForFile(tester, hubDownloads, 'IMG_E2E_0001.jpg');
    expect(await downloaded.length(), await photo.length());
    expect(p.basename(p.dirname(downloaded.path)), 'Fotos');
    expect(p.basename(p.dirname(p.dirname(downloaded.path))), 'Pixel E2E');
    await waitFor(tester, () {
      final entries = container.read(galleryProvider(phoneId)).entries;
      final e = entries.where((e) => e.item.name == 'IMG_E2E_0001.jpg').firstOrNull;
      return e?.state == MediaState.downloaded ? true : null;
    }, what: 'item marked as downloaded');
    await pumpUntilFound(
      tester,
      find.byWidgetPredicate((w) => w.runtimeType.toString() == '_OnPcMark'),
    );

    // 6. PC → phone.
    final doc = File(p.join(root.path, 'Guion PepoTech.txt'))
      ..writeAsStringSync(List.filled(20000, 'hola').join(' '));
    await hub.sendFiles(phoneId, [doc.path]);
    final received = await waitForFile(tester, phoneDownloads, 'Guion PepoTech.txt');
    expect(await received.length(), await doc.length());

    // 7. Phone → PC: file lands, toast and history on the PC.
    final vid = File(p.join(root.path, 'VID_E2E.mp4'))
      ..writeAsBytesSync(List<int>.generate(3 * 1024 * 1024, (i) => i % 251));
    await phone.sendFiles(pc.deviceId, [vid.path]);
    final got = await waitForFile(tester, hubDownloads, 'VID_E2E.mp4');
    expect(await got.length(), await vid.length());
    await pumpUntilFound(tester, find.text('Transferencia completada'));
    await tester.tap(find.widgetWithText(NavRailItem, 'Transferencias'));
    await settle(tester);
    await pumpUntilFound(tester, find.text('VID_E2E.mp4'));
    expect(find.text('IMG_E2E_0001.jpg'), findsWidgets);
    container.read(toastServiceProvider).dismissAll(); // they cover the tabs
    await settle(tester);
    await tester.tap(find.text('Enviados'));
    await settle(tester);
    await pumpUntilFound(tester, find.text('Guion PepoTech.txt'));
  });
}

/// A few real frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Pumps until [finder] matches.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('not found within $timeout: $finder');
}

/// Pumps until [probe] returns a value.
Future<T> waitFor<T>(
  WidgetTester tester,
  FutureOr<T?> Function() probe, {
  required String what,
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    final v = await probe();
    if (v != null) return v;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('timed out waiting for $what');
}

/// Waits for a finished file called [name] anywhere under [dir].
Future<File> waitForFile(
  WidgetTester tester,
  String dir,
  String name, {
  Duration timeout = const Duration(seconds: 30),
}) => waitFor(
  tester,
  () async {
    await for (final e in Directory(dir).list(recursive: true)) {
      if (e is File && p.basename(e.path) == name) return e;
    }
    return null;
  },
  what: '$name under $dir',
  timeout: timeout,
);
