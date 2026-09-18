import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepoconnect/features/activity/activity_list.dart';
import 'package:pepoconnect/features/activity/activity_page.dart';
import 'package:pepoconnect/features/activity/activity_panel_content.dart';
import 'package:pepoconnect/shared/util/format.dart';
import 'package:pepoconnect/state/activity.dart';
import 'package:pepoconnect/state/engine_providers.dart';

import '../gallery/fakes.dart';

List<ActivityEntry> sampleActivity(DateTime now) {
  final today = DateTime(now.year, now.month, now.day, 15, 51);
  final yesterday = DateTime(now.year, now.month, now.day - 1, 9, 12);
  final older = DateTime(now.year, now.month, now.day - 6, 20, 0);
  return [
    fakeActivity(id: '1', at: today, fileName: 'IMG_0142.jpg', mediaId: 'm1'),
    fakeActivity(
      id: '2',
      at: today.subtract(const Duration(minutes: 3)),
      kind: ActivityKind.received,
      fileName: 'IMG_0142.jpg',
      path: r'C:\fotos\IMG_0142.jpg',
    ),
    fakeActivity(id: '3', at: yesterday, kind: ActivityKind.connected, read: true),
    fakeActivity(
      id: '4',
      at: older,
      kind: ActivityKind.failed,
      fileName: 'video.mp4',
      text: 'Sin espacio',
      read: true,
    ),
  ];
}

void main() {
  test('groupActivityByDay keeps one group per day, newest first', () {
    final now = DateTime(2026, 9, 18, 12);
    final groups = groupActivityByDay(sampleActivity(now));
    expect(groups.length, 3);
    expect(groups[0].day, DateTime(2026, 9, 18));
    expect(groups[0].entries.length, 2);
    expect(groups[1].day, DateTime(2026, 9, 17));
    expect(groups[2].day, DateTime(2026, 9, 12));
  });

  testWidgets('the page groups by day and marks everything read', (tester) async {
    final now = DateTime.now();
    final entries = sampleActivity(now);
    await pumpFeature(
      tester,
      child: const ActivityPage(),
      overrides: featureOverrides(devices: sampleDevices(), activity: entries),
    );
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Ayer'), findsOneWidget);
    final older = DateTime(now.year, now.month, now.day - 6);
    expect(find.text(formatDate(older, locale: 'es')), findsOneWidget);
    expect(find.text('Foto nueva en Pixel 8'), findsOneWidget);
    expect(find.text('Recibido IMG_0142.jpg de Pixel 8'), findsOneWidget);
    expect(find.text('Pixel 8 conectado'), findsOneWidget);
    expect(find.text('No se pudo transferir video.mp4'), findsOneWidget);
    expect(find.text('Marcar todo como leído'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(ActivityPage)));
    expect(container.read(unreadActivityProvider), 2);
    await tester.pump(ActivityPage.markReadDelay + const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(container.read(unreadActivityProvider), 0);
    expect(find.text('Marcar todo como leído'), findsNothing);
  }, variant: desktopVariant);

  testWidgets('the page shows the empty state without entries', (tester) async {
    await pumpFeature(
      tester,
      child: const ActivityPage(),
      overrides: featureOverrides(devices: sampleDevices()),
    );
    expect(find.text('Sin actividad reciente'), findsOneWidget);
  }, variant: desktopVariant);

  testWidgets('the panel content lists the same groups compactly', (tester) async {
    final now = DateTime.now();
    await pumpFeature(
      tester,
      child: const SizedBox(width: 320, child: ActivityPanelContent()),
      overrides: featureOverrides(devices: sampleDevices(), activity: sampleActivity(now)),
    );
    expect(find.byType(ActivityList), findsOneWidget);
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Ayer'), findsOneWidget);
    await tester.pump(ActivityPage.markReadDelay + const Duration(milliseconds: 100));
  }, variant: desktopVariant);
}
