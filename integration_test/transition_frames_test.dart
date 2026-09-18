// Grabs the frames of every page transition of the real app as PNG files, so
// the motion can be reviewed frame by frame (no bare background between
// sections, the grid already under the viewer while the photo flies home):
//   flutter test integration_test/transition_frames_test.dart -d windows
// Output: build/transition-frames/<step>_<ms>ms.png (override with
// PEPO_FRAMES_DIR). The millisecond in the name is real time since the
// navigation was requested.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pepoconnect/app/app_services.dart';
import 'package:pepoconnect/app/shell/nav_rail.dart';
import 'package:pepoconnect/features/gallery/gallery_tile.dart';

import 'support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('frames of every transition to PNG', (tester) async {
    final dir =
        Platform.environment['PEPO_FRAMES_DIR'] ??
        p.join(Directory.current.path, 'build', 'transition-frames');
    final w = await E2eWorld.start(tester);

    /// Runs [trigger], then grabs the next [count] frames about [stepMs]
    /// apart (plus the readback time) and writes them once the motion is over.
    Future<void> frames(
      String step,
      Future<void> Function() trigger, {
      int count = 8,
      int stepMs = 20,
    }) async {
      final boundary =
          w.boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final shots = <(int, ui.Image)>[];
      await trigger();
      final clock = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        if (i == 0) {
          await tester.pump();
        } else {
          await tester.pump(Duration(milliseconds: stepMs));
        }
        final at = clock.elapsedMilliseconds;
        shots.add((at, await boundary.toImage()));
      }
      await settle(tester);
      for (final (at, image) in shots) {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final file = File(p.join(dir, '${step}_${at.toString().padLeft(3, '0')}ms.png'));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      }
    }

    // Onboarding → pairing → a gallery with photos (as in screenshots_test).
    await tester.tap(find.text('Añadir móvil'));
    await settle(tester);
    await pumpUntilFound(tester, find.text('Abre la app y escanea este código'));
    await w.pairThroughQr(tester);
    await pumpUntilFound(tester, find.text('Emparejado'), timeout: const Duration(seconds: 15));
    await tester.tap(find.text('Empezar'));
    await settle(tester);
    await pumpUntilFound(tester, find.textContaining('Pixel E2E'));
    const colors = [
      (200, 120, 40),
      (40, 120, 200),
      (60, 160, 90),
      (180, 60, 90),
      (120, 120, 120),
      (230, 200, 80),
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
    w.container.read(toastServiceProvider).dismissAll();
    await settle(tester);

    Future<void> go(String label) => tester.tap(find.widgetWithText(NavRailItem, label));

    // Sections: the grid dissolves into the transfers page and back.
    await frames('01_gallery_to_transfers', () => go('Transferencias'));
    await frames('02_transfers_to_gallery', () => go('Galería'));

    // The viewer over the grid (Hero flight) and back with Esc.
    await frames('03_open_viewer', () async {
      await tester.tap(find.byType(GalleryTile).at(2));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.byType(GalleryTile).at(2));
    });
    await Future<void>.delayed(const Duration(milliseconds: 800)); // preview
    await settle(tester);
    await frames('04_close_viewer', () => tester.sendKeyEvent(LogicalKeyboardKey.escape));

    // A page pushed over the shell (pairing from Settings) and back.
    await go('Ajustes');
    await settle(tester);
    await frames('05_push_pairing', () => tester.tap(find.text('Añadir dispositivo')));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await settle(tester);
    await frames('06_pop_pairing', () => tester.tap(find.text('Atrás')));
  });
}
