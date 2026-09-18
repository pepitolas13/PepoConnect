// Real end-to-end run on a desktop: the full app (the PC) and a headless
// "phone" engine in the same process, talking over real TLS sockets on
// loopback. Run with:
//   flutter test integration_test/e2e_test.dart -d windows
// Everything lives in a temp folder; the user's settings are mocked.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pepo_core/pepo_core.dart';
import 'package:pepoconnect/app/app_services.dart';
import 'package:pepoconnect/app/shell/nav_rail.dart';
import 'package:pepoconnect/features/gallery/gallery_tile.dart';
import 'package:pepoconnect/shared/widgets/fluent_button.dart';
import 'package:pepoconnect/state/engine_providers.dart';

import 'support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pair by QR, new photo, download, transfers both ways', (tester) async {
    final w = await E2eWorld.start(tester);
    final hub = w.hub;
    final phone = w.phone;

    // 1. First run: onboarding → "Añadir móvil" → pairing page with a QR.
    expect(find.text('¿Cómo quieres usar PepoConnect?'), findsOneWidget);
    await tester.tap(find.text('Añadir móvil'));
    await settle(tester);

    // 2. The phone "scans" the QR.
    final pc = await w.pairThroughQr(tester);
    expect(pc.name, contains('e2e'));

    // 3. The PC shows "Emparejado"; "Empezar" lands on the gallery of the phone.
    await pumpUntilFound(tester, find.text('Emparejado'), timeout: const Duration(seconds: 15));
    await tester.tap(find.text('Empezar'));
    await settle(tester);
    await pumpUntilFound(tester, find.textContaining('Pixel E2E'));

    // 4. A photo taken on the phone appears on the PC as "Nuevo".
    final photo = await w.takePhoto('IMG_E2E_0001.jpg');
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
    final downloaded = await waitForFile(tester, w.hubDownloads, 'IMG_E2E_0001.jpg');
    expect(await downloaded.length(), await photo.length());
    expect(p.basename(p.dirname(downloaded.path)), 'Fotos');
    expect(p.basename(p.dirname(p.dirname(downloaded.path))), 'Pixel E2E');
    await waitFor(tester, () {
      final entries = w.container.read(galleryProvider(w.phoneId)).entries;
      final e = entries.where((e) => e.item.name == 'IMG_E2E_0001.jpg').firstOrNull;
      return e?.state == MediaState.downloaded ? true : null;
    }, what: 'item marked as downloaded');
    await pumpUntilFound(
      tester,
      find.byWidgetPredicate((w) => w.runtimeType.toString() == '_OnPcMark'),
    );

    // 6. PC → phone.
    final doc = File(p.join(w.root.path, 'Guion PepoTech.txt'))
      ..writeAsStringSync(List.filled(20000, 'hola').join(' '));
    await hub.sendFiles(w.phoneId, [doc.path]);
    final received = await waitForFile(tester, w.phoneDownloads, 'Guion PepoTech.txt');
    expect(await received.length(), await doc.length());

    // 7. Phone → PC: file lands, toast and history on the PC.
    final vid = File(p.join(w.root.path, 'VID_E2E.mp4'))
      ..writeAsBytesSync(List<int>.generate(3 * 1024 * 1024, (i) => i % 251));
    await phone.sendFiles(pc.deviceId, [vid.path]);
    final got = await waitForFile(tester, w.hubDownloads, 'VID_E2E.mp4');
    expect(await got.length(), await vid.length());
    await pumpUntilFound(tester, find.text('Transferencia completada'));
    await tester.tap(find.widgetWithText(NavRailItem, 'Transferencias'));
    await settle(tester);
    await pumpUntilFound(tester, find.text('VID_E2E.mp4'));
    expect(find.text('IMG_E2E_0001.jpg'), findsWidgets);
    w.container.read(toastServiceProvider).dismissAll(); // they cover the tabs
    await settle(tester);
    await tester.tap(find.text('Enviados'));
    await settle(tester);
    await pumpUntilFound(tester, find.text('Guion PepoTech.txt'));
  });
}
