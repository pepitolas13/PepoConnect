import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../state/engine_providers.dart';
import 'gallery_grouping.dart';

/// Immutable set of selected entry keys plus the anchor used by Shift+click.
@immutable
class GallerySelection {
  const GallerySelection._(this.keys, this.anchor);

  const GallerySelection.empty() : this._(const <String>{}, null);

  final Set<String> keys;

  /// Last key clicked without Shift; ranges start here.
  final String? anchor;

  bool get isEmpty => keys.isEmpty;
  bool get isNotEmpty => keys.isNotEmpty;
  int get length => keys.length;

  bool contains(String key) => keys.contains(key);

  /// Just [key].
  GallerySelection only(String key) => GallerySelection._({key}, key);

  /// Ctrl+click: adds or removes [key] and makes it the anchor.
  GallerySelection toggled(String key) {
    final next = Set.of(keys);
    if (!next.remove(key)) next.add(key);
    return GallerySelection._(next, key);
  }

  /// Shift+click: adds every key between the anchor and [to] in [ordered].
  GallerySelection withRange(List<String> ordered, String to) {
    final from = anchor ?? to;
    final a = ordered.indexOf(from);
    final b = ordered.indexOf(to);
    if (a < 0 || b < 0) return toggled(to);
    final lo = math.min(a, b);
    final hi = math.max(a, b);
    final next = Set.of(keys)..addAll(ordered.sublist(lo, hi + 1));
    return GallerySelection._(next, from);
  }

  GallerySelection withAll(Iterable<String> add) => GallerySelection._({...keys, ...add}, anchor);

  GallerySelection without(Iterable<String> remove) {
    final next = Set.of(keys)..removeAll(remove);
    return GallerySelection._(next, next.contains(anchor) ? anchor : null);
  }

  /// Drops keys that are no longer in the gallery.
  GallerySelection retain(Set<String> existing) {
    if (keys.every(existing.contains)) return this;
    final next = keys.where(existing.contains).toSet();
    return GallerySelection._(next, existing.contains(anchor) ? anchor : null);
  }

  /// The selected entries, in gallery order.
  List<GalleryEntry> entriesFrom(List<GalleryEntry> all) =>
      all.where((e) => keys.contains(galleryEntryKey(e))).toList();

  /// Sum of the known file sizes.
  static int bytesOf(Iterable<GalleryEntry> entries) =>
      entries.fold(0, (sum, e) => sum + (e.item.size ?? 0));
}
