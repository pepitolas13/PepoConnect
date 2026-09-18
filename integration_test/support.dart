// Shared scaffolding for the on-device tests: the real app (the PC) plus a
// headless "phone" engine in the same process, both on temp folders, talking
// over real TLS sockets on loopback.

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pepo_core/pepo_core.dart';
import 'package:pepoconnect/app/app.dart';
import 'package:pepoconnect/app/app_services.dart';
import 'package:pepoconnect/app/bootstrap.dart';
import 'package:pepoconnect/shared/motion/toast.dart';
import 'package:pepoconnect/state/app_settings.dart';
import 'package:pepoconnect/state/engine_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const hubPort = 47610;
const phonePort = 47611;

class E2eWorld {
  E2eWorld._({
    required this.root,
    required this.hub,
    required this.phone,
    required this.container,
    required this.prefs,
  });

  final Directory root;
  final PepoEngine hub;
  final PepoEngine phone;
  final ProviderContainer container;
  final SharedPreferences prefs;
  final boundaryKey = GlobalKey();

  String get hubDownloads => p.join(root.path, 'hub_downloads');
  String get phoneMedia => p.join(root.path, 'phone_media');
  String get phoneDownloads => p.join(root.path, 'phone_downloads');
  String get phoneId => phone.identity.deviceId;

  /// Starts both engines and pumps the app. [initialPrefs] seeds the settings
  /// (for example `{'onboarded': true}`).
  static Future<E2eWorld> start(
    WidgetTester tester, {
    Map<String, Object> initialPrefs = const {},
  }) async {
    final root = await Directory.systemTemp.createTemp('pepo_e2e_');
    final hubData = p.join(root.path, 'hub');
    final phoneData = p.join(root.path, 'phone');
    for (final d in ['hub_downloads', 'phone_media', 'phone_downloads']) {
      await Directory(p.join(root.path, d)).create(recursive: true);
    }

    SharedPreferences.setMockInitialValues(initialPrefs);
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsNotifier.load(prefs);
    final hub = await startEngine(
      settings: settings,
      paths: AppPaths(
        dataDir: hubData,
        defaultDownloadRoot: p.join(root.path, 'hub_downloads'),
        cacheDir: p.join(hubData, 'cache'),
      ),
      options: const LaunchOptions(profile: 'e2e', port: hubPort),
    );

    final phone = PepoEngine(
      EngineConfig(
        dataDir: phoneData,
        downloadRoot: p.join(root.path, 'phone_downloads'),
        deviceName: 'Pixel E2E',
        platform: DevicePlatform.android,
        role: DeviceRole.phone,
        appVersion: '0.0.0',
        model: 'Pixel 8',
        listenPort: phonePort,
        udpDiscovery: false,
        profile: 'e2e-phone',
      ),
      mediaSource: MediaSourceFs(
        roots: [p.join(root.path, 'phone_media')],
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
    final world = E2eWorld._(
      root: root,
      hub: hub,
      phone: phone,
      container: container,
      prefs: prefs,
    );
    addTearDown(world.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: world.boundaryKey,
        child: UncontrolledProviderScope(container: container, child: const PepoApp()),
      ),
    );
    await settle(tester);
    return world;
  }

  /// Pairs the phone with the PC through the QR the pairing page is showing.
  Future<PairedDevice> pairThroughQr(WidgetTester tester) async {
    final invite = await waitFor(tester, () {
      final i = hub.currentInvite;
      return i?.qrText == null ? null : i;
    }, what: 'QR invite');
    // Point the phone at loopback so the test does not depend on the LAN.
    final uri = Uri.parse(invite.qrText!);
    final qr = uri.replace(queryParameters: {...uri.queryParameters, 'a': '127.0.0.1'}).toString();
    final pc = await phone.pairWithQrText(qr);
    await waitFor(tester, () async {
      final d = await hub.devices();
      return d.length == 1 && d.single.connected && d.single.deviceId == phoneId ? true : null;
    }, what: 'phone connected on the PC');
    return pc;
  }

  /// Writes a JPEG into the phone's camera folder.
  Future<File> takePhoto(String name, {int r = 200, int g = 120, int b = 40}) async {
    final f = File(p.join(phoneMedia, name));
    await f.writeAsBytes(ImageOps.solidJpeg(1600, 1200, r: r, g: g, b: b));
    return f;
  }

  /// Renders the whole app to a PNG file. Pass `settle: false` to grab the
  /// current frame (for example in the middle of a transition).
  Future<File> capture(WidgetTester tester, String path, {bool settle = true}) async {
    if (settle) await settleFrames(tester);
    final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    return file;
  }

  Future<void> dispose() async {
    container.dispose();
    await hub.stop();
    await phone.stop();
    try {
      await root.delete(recursive: true);
    } catch (_) {}
  }
}

/// A few real frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Same as [settle]; a named alias for members that shadow it.
Future<void> settleFrames(WidgetTester tester) => settle(tester);

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
