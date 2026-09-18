import 'package:flutter/widgets.dart';

import '../../shared/i18n/l10n.dart';
import '../../shared/util/format.dart';
import '../../state/engine_providers.dart';

/// "Today" and "yesterday" get their own groups; everything else is a month.
enum GalleryGroupKind { today, yesterday, month }

/// A run of gallery entries under one heading.
@immutable
class GalleryGroup {
  const GalleryGroup({
    required this.key,
    required this.kind,
    required this.month,
    required this.entries,
  });

  /// `today`, `yesterday` or `2026-09`.
  final String key;
  final GalleryGroupKind kind;

  /// First day of the month the group belongs to.
  final DateTime month;
  final List<GalleryEntry> entries;

  int get length => entries.length;
}

/// Stable identity of an entry across devices: `deviceId/id`.
String galleryEntryKey(GalleryEntry e) => galleryKeyOf(e.deviceId, e.id);

String galleryKeyOf(String deviceId, String id) => '$deviceId/$id';

/// Groups [entries] (expected newest first) by day for today and yesterday
/// and by month for the rest, keeping the order of first appearance.
List<GalleryGroup> groupGalleryEntries(List<GalleryEntry> entries, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final yesterday = DateTime(n.year, n.month, n.day - 1);
  final order = <String>[];
  final buckets = <String, List<GalleryEntry>>{};
  final kinds = <String, GalleryGroupKind>{};
  final months = <String, DateTime>{};
  for (final e in entries) {
    final at = e.takenAt;
    final day = DateTime(at.year, at.month, at.day);
    final String key;
    final GalleryGroupKind kind;
    if (day == today) {
      key = 'today';
      kind = GalleryGroupKind.today;
    } else if (day == yesterday) {
      key = 'yesterday';
      kind = GalleryGroupKind.yesterday;
    } else {
      key = '${at.year}-${at.month.toString().padLeft(2, '0')}';
      kind = GalleryGroupKind.month;
    }
    final bucket = buckets.putIfAbsent(key, () {
      order.add(key);
      kinds[key] = kind;
      months[key] = DateTime(at.year, at.month);
      return <GalleryEntry>[];
    });
    bucket.add(e);
  }
  return [
    for (final key in order)
      GalleryGroup(key: key, kind: kinds[key]!, month: months[key]!, entries: buckets[key]!),
  ];
}

/// Localized heading: "Hoy", "Ayer", "Septiembre de 2026".
String galleryGroupTitle(BuildContext context, GalleryGroup group) {
  final t = context.t;
  return switch (group.kind) {
    GalleryGroupKind.today => t.galleryGroupToday,
    GalleryGroupKind.yesterday => t.galleryGroupYesterday,
    GalleryGroupKind.month => formatMonth(
      group.month,
      locale: Localizations.localeOf(context).toString(),
    ),
  };
}
