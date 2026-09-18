import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/engine_providers.dart';

/// Synchronous lookup of a thumbnail already held in memory.
typedef ThumbnailLookup = Uint8List? Function(String deviceId, String id);

/// The engine's in-memory thumbnail cache, exposed as a function so pages
/// (gallery, viewer, activity, transfers) can paint instantly and tests can
/// swap it for a map.
final thumbnailLookupProvider = Provider<ThumbnailLookup>((ref) {
  final engine = ref.watch(engineProvider);
  return engine.gallery.cachedThumbnail;
});
