import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepo_core/pepo_core.dart';
import 'package:pepoconnect/features/gallery/gallery_grouping.dart';
import 'package:pepoconnect/features/gallery/gallery_page.dart';
import 'package:pepoconnect/features/gallery/gallery_selection.dart';
import 'package:pepoconnect/features/gallery/gallery_tile.dart';
import 'package:pepoconnect/shared/util/format.dart';
import 'package:pepoconnect/shared/widgets/pepo_checkbox.dart';
import 'package:pepoconnect/shared/widgets/section_header.dart';
import 'package:pepoconnect/state/engine_providers.dart';

import 'fakes.dart';

List<GalleryEntry> sampleEntries(DateTime now) {
  final today = DateTime(now.year, now.month, now.day, 10);
  final yesterday = DateTime(now.year, now.month, now.day - 1, 18);
  final older = DateTime(now.year, now.month - 2, 10, 12);
  return [
    fakeEntry(id: 'a', takenAt: today, size: 3 * 1024 * 1024, state: MediaState.fresh),
    fakeEntry(id: 'b', takenAt: today.subtract(const Duration(hours: 1)), size: 5 * 1024 * 1024),
    fakeEntry(id: 'c', takenAt: yesterday, kind: MediaKind.video, durationMs: 65000),
    fakeEntry(id: 'd', takenAt: older, state: MediaState.downloaded, localPath: r'C:\x\d.jpg'),
    fakeEntry(id: 'e', takenAt: older.subtract(const Duration(days: 3))),
  ];
}

void main() {
  group('groupGalleryEntries', () {
    test('splits today, yesterday and months', () {
      final now = DateTime(2026, 9, 18, 12);
      final groups = groupGalleryEntries(sampleEntries(now), now: now);
      expect(groups.map((g) => g.kind), [
        GalleryGroupKind.today,
        GalleryGroupKind.yesterday,
        GalleryGroupKind.month,
      ]);
      expect(groups[0].length, 2);
      expect(groups[1].length, 1);
      expect(groups[2].key, '2026-07');
      expect(groups[2].length, 2);
      expect(groups[2].month, DateTime(2026, 7));
    });
  });

  group('GallerySelection', () {
    test('toggles, ranges and counts bytes', () {
      final entries = sampleEntries(DateTime(2026, 9, 18));
      final keys = [for (final e in entries) galleryEntryKey(e)];
      var s = const GallerySelection.empty().toggled(keys[0]);
      expect(s.length, 1);
      expect(s.anchor, keys[0]);
      s = s.withRange(keys, keys[2]);
      expect(s.keys, {keys[0], keys[1], keys[2]});
      expect(s.anchor, keys[0]);
      s = s.toggled(keys[1]);
      expect(s.contains(keys[1]), isFalse);
      expect(GallerySelection.bytesOf(s.entriesFrom(entries)), 6 * 1024 * 1024);
      final pruned = s.retain({keys[0]});
      expect(pruned.keys, {keys[0]});
      expect(pruned.anchor, isNull);
    });
  });

  testWidgets('groups tiles by month with today and yesterday apart', (tester) async {
    final now = DateTime.now();
    final entries = sampleEntries(now);
    await pumpFeature(
      tester,
      child: const GalleryPage(),
      overrides: featureOverrides(
        devices: sampleDevices(),
        entries: entries,
        thumbnails: {for (final e in entries) e.id: tinyPng},
      ),
    );
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Ayer'), findsOneWidget);
    final older = DateTime(now.year, now.month - 2);
    expect(find.text(formatMonth(older, locale: 'es')), findsOneWidget);
    expect(find.byType(SectionHeader), findsNWidgets(3));
    expect(find.byType(GalleryTile), findsNWidgets(5));
    expect(find.text('Nuevo'), findsOneWidget);
    expect(find.text('1:05'), findsOneWidget);
    expect(find.text('Galería de Pixel 8'), findsNothing);
    expect(find.text('Todos los dispositivos'), findsOneWidget);
  }, variant: desktopVariant);

  testWidgets('selecting a group counts items and bytes', (tester) async {
    final now = DateTime.now();
    final entries = sampleEntries(now);
    await pumpFeature(
      tester,
      child: const GalleryPage(),
      overrides: featureOverrides(devices: sampleDevices(), entries: entries),
    );
    // The first check box belongs to the "Hoy" group (3 MB + 5 MB).
    await tester.tap(find.byType(PepoCheckbox).first);
    await tester.pumpAndSettle();
    // formatBytes joins number and unit with a non-breaking space.
    final label = '2 seleccionados (${formatBytes(8 * 1024 * 1024, locale: 'es')})';
    expect(find.text(label), findsOneWidget);
    expect(find.text('Eliminar del móvil'), findsOneWidget);

    // Esc clears the selection and brings the header back.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text(label), findsNothing);
    expect(find.text('Todos los dispositivos'), findsOneWidget);
  }, variant: desktopVariant);

  testWidgets('offline device shows the connect hint', (tester) async {
    await pumpFeature(
      tester,
      child: const GalleryPage(),
      overrides: featureOverrides(
        devices: [fakeDevice(id: 'ipad', name: 'iPad', connected: false)],
        galleryLoaded: false,
      ),
    );
    expect(find.text('Conecta el móvil para ver la galería'), findsOneWidget);
  }, variant: desktopVariant);

  testWidgets('without devices the gallery asks to pair one', (tester) async {
    await pumpFeature(
      tester,
      child: const GalleryPage(),
      overrides: featureOverrides(devices: const []),
    );
    expect(find.text('Aún no hay dispositivos'), findsOneWidget);
    expect(find.text('Añadir dispositivo'), findsOneWidget);
  }, variant: desktopVariant);
}
