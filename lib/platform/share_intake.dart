import 'dart:async';
import 'dart:io';

import 'package:share_handler/share_handler.dart';

/// "Share with PepoConnect": files handed over by other apps (Android share
/// sheet, iOS share extension when present). [onFiles] receives local paths.
class ShareIntake {
  ShareIntake({required this.onFiles, this.onText});

  final void Function(List<String> paths) onFiles;
  final void Function(String text)? onText;
  StreamSubscription<SharedMedia>? _sub;

  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  Future<void> start() async {
    if (!isSupported) return;
    try {
      final handler = ShareHandlerPlatform.instance;
      final initial = await handler.getInitialSharedMedia();
      if (initial != null) {
        _handle(initial);
        // Otherwise the launch share is served again on the next start.
        await handler.resetInitialSharedMedia();
      }
      _sub = handler.sharedMediaStream.listen(_handle);
    } catch (_) {
      // Plugin missing on this platform build: ignore.
    }
  }

  void _handle(SharedMedia media) {
    final paths = <String>[];
    for (final a in media.attachments ?? const <SharedAttachment?>[]) {
      if (a == null) continue;
      final path = a.path;
      if (path.isNotEmpty) paths.add(path);
    }
    if (paths.isNotEmpty) onFiles(paths);
    final text = media.content;
    if (text != null && text.isNotEmpty && paths.isEmpty) onText?.call(text);
  }

  Future<void> dispose() async => _sub?.cancel();
}
