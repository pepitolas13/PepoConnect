// Renders every screen of the real app to PNG files for a visual review:
//   flutter test integration_test/screenshots_test.dart -d windows
// Output: build/screenshots/*.png (override with PEPO_SHOTS_DIR).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pepoconnect/app/app_services.dart';
import 'package:pepoconnect/app/shell/nav_rail.dart';
import 'package:pepoconnect/features/gallery/gallery_tile.dart';
import 'package:pepoconnect/state/app_settings.dart';

import 'support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every screen to PNG', (tester) async {
    final dir =
        Platform.environment['PEPO_SHOTS_DIR'] ??
        p.join(Directory.current.path, 'build', 'screenshots');
    final w = await E2eWorld.start(tester);
    Future<void> shot(String name) async {
      await w.capture(tester, p.join(dir, '$name.png'));
    }

    Future<void> go(String label) async {
      await tester.tap(find.widgetWithText(NavRailItem, label));
      await settle(tester);
    }

    // Onboarding and pairing.
    await shot('01_onboarding');
    await tester.tap(find.text('Añadir móvil'));
    await settle(tester);
    await pumpUntilFound(tester, find.text('Abre la app y escanea este código'));
    await shot('02_pairing_qr');
    await w.pairThroughQr(tester);
    await pumpUntilFound(tester, find.text('Emparejado'), timeout: const Duration(seconds: 15));
    await shot('03_pairing_done');
    await tester.tap(find.text('Empezar'));
    await settle(tester);

    // Gallery: empty, then with photos, a selection and the viewer.
    await pumpUntilFound(tester, find.textContaining('Pixel E2E'));
    await shot('04_gallery_empty');
    const colors = [
      (200, 120, 40),
      (40, 120, 200),
      (60, 160, 90),
      (180, 60, 90),
      (120, 120, 120),
      (230, 200, 80),
      (90, 60, 160),
      (20, 20, 30),
    ];
    for (var i = 0; i < colors.length; i++) {
      final (r, g, b) = colors[i];
      await w.takePhoto('IMG_2026091${i % 10}_00$i.jpg', r: r, g: g, b: b);
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    await waitFor(
      tester,
      () => find.byType(GalleryTile).evaluate().length >= colors.length ? true : null,
      what: 'all tiles',
      timeout: const Duration(seconds: 30),
    );
    await Future<void>.delayed(const Duration(seconds: 2)); // thumbnails
    await shot('05_gallery_new');
    w.container.read(toastServiceProvider).dismissAll();
    await settle(tester);
    await tester.tap(find.byType(GalleryTile).at(1));
    await tester.pump(const Duration(milliseconds: 400));
    await pumpUntilFound(tester, find.textContaining('1 seleccionado'));
    await shot('06_gallery_selection');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    await tester.tap(find.byType(GalleryTile).at(2));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.byType(GalleryTile).at(2));
    await settle(tester);
    await Future<void>.delayed(const Duration(milliseconds: 800)); // preview
    await settle(tester);
    await shot('07_viewer');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);

    // Transfers with history and a toast, then the guest share dialog.
    final doc = File(p.join(w.root.path, 'Presupuesto 2026.xlsx'))
      ..writeAsBytesSync(List.filled(300 * 1024, 7));
    await w.hub.sendFiles(w.phoneId, [doc.path]);
    await waitForFile(tester, w.phoneDownloads, 'Presupuesto 2026.xlsx');
    final clip = File(p.join(w.root.path, 'VID_20260918_1830.mp4'))
      ..writeAsBytesSync(List.filled(2 * 1024 * 1024, 9));
    await w.phone.sendFiles((await w.phone.devices()).single.deviceId, [clip.path]);
    await waitForFile(tester, w.hubDownloads, 'VID_20260918_1830.mp4');
    await pumpUntilFound(tester, find.text('Transferencia completada'));
    await go('Transferencias');
    await pumpUntilFound(tester, find.text('VID_20260918_1830.mp4'));
    await shot('08_transfers_toast');
    w.container.read(toastServiceProvider).dismissAll();
    await settle(tester);
    await shot('09_transfers');
    await tester.tap(find.text('Compartir con cualquiera'));
    await settle(tester);
    await shot('10_guest_share');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);

    // Activity and settings.
    await go('Actividad');
    await shot('11_activity');
    await go('Ajustes');
    await shot('12_settings_general');
    // Pushing the pairing page over the shell: mid-transition frame, then the
    // settled page (the shell underneath must be gone).
    await tester.tap(find.text('Añadir dispositivo'));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 90));
    await w.capture(tester, p.join(dir, '12b_transition_mid.png'), settle: false);
    await settle(tester);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await shot('12c_pairing_pushed');
    await tester.tap(find.text('Atrás'));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 60));
    await w.capture(tester, p.join(dir, '12d_transition_back_mid.png'), settle: false);
    await settle(tester);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await shot('12e_settings_after_back');
    await tester.tap(find.text('Notificaciones').last);
    await settle(tester);
    await shot('13_settings_notifications');
    await tester.tap(find.text('Acerca de').last);
    await settle(tester);
    await shot('14_settings_about');

    // The other theme (the shots above follow the system theme).
    final dark =
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness == Brightness.dark;
    final other = dark ? AppThemeMode.light : AppThemeMode.dark;
    final suffix = dark ? 'light' : 'dark';
    w.container.read(settingsProvider.notifier).update((s) => s.copyWith(themeMode: other));
    await settle(tester);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await shot('15_settings_$suffix');
    await go('Galería');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await shot('16_gallery_$suffix');
    await go('Transferencias');
    await shot('17_transfers_$suffix');
    w.container
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(themeMode: AppThemeMode.light));
    await settle(tester);

    // Compact layout (what a phone or a Linux phone shows).
    tester.view.physicalSize = const Size(420, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await settle(tester);
    await shot('18_compact_transfers');
    await tester.tap(find.text('Galería').last);
    await settle(tester);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await shot('19_compact_gallery');
    await tester.tap(find.text('Ajustes').last);
    await settle(tester);
    await shot('20_compact_settings');
    tester.view.resetPhysicalSize();
    await settle(tester);
  });
}
