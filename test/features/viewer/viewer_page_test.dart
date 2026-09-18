import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepoconnect/features/viewer/viewer_page.dart';

import '../gallery/fakes.dart';

bool _showsBytes(Widget w, Uint8List bytes) =>
    w is Image && w.image is MemoryImage && listEquals((w.image as MemoryImage).bytes, bytes);

void main() {
  final now = DateTime.now();
  final entries = [
    fakeEntry(id: 'a', takenAt: now.subtract(const Duration(minutes: 5))),
    fakeEntry(id: 'b', takenAt: now.subtract(const Duration(hours: 2))),
  ];

  testWidgets('shows the cached thumbnail at once and walks the gallery', (tester) async {
    await pumpFeature(
      tester,
      child: ViewerPage(deviceId: fakeDeviceId('pixel8'), id: 'a', session: false),
      overrides: featureOverrides(
        devices: sampleDevices(),
        entries: entries,
        thumbnails: {'a': tinyPng, 'b': tinyPng},
      ),
    );
    expect(find.byWidgetPredicate((w) => _showsBytes(w, tinyPng)), findsWidgets);
    expect(find.text('IMG_a.jpg'), findsOneWidget);
    expect(find.textContaining('1 de 2'), findsOneWidget);
    expect(find.byIcon(FluentIcons.chevron_right_24_regular), findsOneWidget);
    expect(find.byIcon(FluentIcons.chevron_left_24_regular), findsNothing);
    expect(find.text('Descargar'), findsOneWidget);

    await tester.tap(find.byIcon(FluentIcons.chevron_right_24_regular));
    await tester.pumpAndSettle();
    expect(find.text('IMG_b.jpg'), findsOneWidget);
    expect(find.textContaining('2 de 2'), findsOneWidget);
    expect(find.byIcon(FluentIcons.chevron_left_24_regular), findsOneWidget);
    expect(find.byIcon(FluentIcons.chevron_right_24_regular), findsNothing);

    // The info panel lists name, date, resolution and device.
    await tester.tap(find.byIcon(FluentIcons.info_20_regular));
    await tester.pumpAndSettle();
    expect(find.text('Resolución'), findsOneWidget);
    expect(find.text('4000 × 3000'), findsOneWidget);
    expect(find.text('Pixel 8'), findsOneWidget);
  }, variant: desktopVariant);

  testWidgets('session mode shows the counter while waiting', (tester) async {
    await pumpFeature(
      tester,
      child: ViewerPage(deviceId: fakeDeviceId('pixel8'), id: 'a', session: true),
      overrides: featureOverrides(devices: sampleDevices(), entries: entries),
    );
    expect(find.textContaining('Sesión'), findsOneWidget);
    expect(find.text('Esperando fotos nuevas…'), findsOneWidget);
  }, variant: desktopVariant);

  testWidgets('a missing item shows the not-found state', (tester) async {
    await pumpFeature(
      tester,
      child: ViewerPage(deviceId: fakeDeviceId('pixel8'), id: 'zzz', session: false),
      overrides: featureOverrides(devices: sampleDevices(), entries: entries),
    );
    expect(find.text('Este elemento ya no está en la galería'), findsOneWidget);
  }, variant: desktopVariant);
}
