import 'dart:async';
import 'dart:typed_data';

import '../protocol/models.dart';

/// Additions/removals detected in the device gallery.
class MediaChange {
  const MediaChange({this.added = const [], this.removed = const []});
  final List<MediaItem> added;
  final List<String> removed;
}

/// Access to the photos and videos of this device. Implemented per platform:
/// `photo_manager` on Android/iOS, folders on Linux/desktop.
abstract class MediaSource {
  /// Newest first. [since] limits to items taken after that instant.
  Future<MediaPage> index({
    int page = 0,
    int pageSize = 200,
    Set<MediaKind>? kinds,
    DateTime? since,
  });

  Future<MediaItem?> item(String id);

  /// JPEG thumbnail with the long edge at most [maxPx], or null.
  Future<Uint8List?> thumbnail(String id, {int maxPx = 320});

  /// JPEG preview with the long edge at most [maxPx], or null.
  Future<Uint8List?> preview(String id, {int maxPx = 1600});

  /// Path of the original file, ready to be sent. On platforms that export
  /// to a temporary file, call [releaseOriginal] afterwards.
  Future<String?> originalPath(String id);

  Future<void> releaseOriginal(String id, String path) async {}

  /// Deletes items on the device; returns the ids actually deleted.
  Future<List<String>> delete(List<String> ids);

  /// Live changes (new photos, deletions).
  Stream<MediaChange> get changes;

  Future<void> start();
  Future<void> stop();
}
