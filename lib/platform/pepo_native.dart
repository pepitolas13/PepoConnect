import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin wrapper over the `org.pepoconnect/native` channel (`PepoNative.kt` on
/// Android, `AppDelegate.swift` + `PepoBackground.swift` on iOS). Every call
/// is a no-op elsewhere.
class PepoNative {
  const PepoNative._();

  static const _channel = MethodChannel('org.pepoconnect/native');

  /// Which native side to talk to. Only tests set it; everywhere else it is
  /// the platform the app is really running on.
  @visibleForTesting
  static String? debugPlatform;

  static String get _os => debugPlatform ?? Platform.operatingSystem;

  /// The foreground service, the clipboard tile, MediaStore: Android only.
  static bool get _android => _os == 'android';

  /// The background engine: iPhone only.
  static bool get isIos => _os == 'ios';

  /// The chime and the background engine exist on both phones.
  static bool get _mobile => _android || isIos;

  /// True where the channel has a native side at all.
  static bool get isSupported => _mobile;

  /// Clipboard text handed over by the native side (Android quick-settings
  /// tile / launcher shortcut). Returns `{'sent': [device names]}`.
  static Future<Map<String, Object?>> Function(String text)? onClipboardText;

  /// iOS handed us a `BGAppRefreshTask` / `BGProcessingTask`. Whatever this
  /// does must finish quickly and end with [backgroundTaskDone].
  static Future<void> Function(String id)? onBackgroundTask;

  /// Listens for native → Dart calls. Idempotent.
  static void init() {
    if (!_mobile) return;
    _channel.setMethodCallHandler(_onCall);
  }

  static Future<Object?> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'clipboardText':
        final text = call.arguments as String? ?? '';
        final handler = onClipboardText;
        if (handler == null || text.isEmpty) return {'sent': <String>[]};
        return handler(text);
      case 'backgroundTask':
        final args = (call.arguments as Map?)?.cast<String, Object?>();
        final id = args?['id'] as String? ?? '';
        final handler = onBackgroundTask;
        if (handler != null) await handler(id);
        return null;
      default:
        throw MissingPluginException('${call.method} is not handled in Dart');
    }
  }

  /// Tells the native side that [init] ran. A native → Dart call made
  /// before the handler exists sits in the channel buffer unanswered, so
  /// the native side must not use the channel until it hears this.
  static Future<void> markClipboardReady() async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('clipboardReady');
    } catch (_) {}
  }

  /// True while a window (MainActivity) is attached to this engine. False
  /// when Dart was started behind the foreground service and the app has
  /// not been opened since: platform calls that need a window (clipboard,
  /// permission dialogs) have nobody to answer them then, and some never
  /// complete. Always true where there is no such service.
  static Future<bool> hasActivity() async {
    if (!_android) return true;
    try {
      return await _channel.invokeMethod<bool>('hasActivity') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Starts the foreground service, or updates its notification when it is
  /// already running. [idle] is what it shows when the service comes back
  /// on its own (process killed, reboot) before Dart reports a connection.
  static Future<bool> serviceStart({
    required String title,
    required String text,
    required String idle,
  }) async {
    if (!_android) return false;
    try {
      return await _channel.invokeMethod<bool>('serviceStart', {
            'title': title,
            'text': text,
            'idle': idle,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> serviceUpdate({required String title, required String text}) async {
    if (!_android) return false;
    try {
      return await _channel.invokeMethod<bool>('serviceUpdate', {'title': title, 'text': text}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> serviceStop() async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('serviceStop');
    } catch (_) {}
  }

  static Future<bool> serviceRunning() async {
    if (!_android) return false;
    try {
      return await _channel.invokeMethod<bool>('serviceRunning') ?? false;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // iOS background engine

  /// Tells iOS that [init] ran, so it may push `backgroundTask` calls. Also
  /// hands over any task that arrived while nobody was listening.
  static Future<void> markBackgroundReady() async {
    if (!isIos) return;
    try {
      await _channel.invokeMethod<void>('backgroundReady');
    } catch (_) {}
  }

  /// Starts the silent-audio loop that keeps the process out of iOS's
  /// suspended state. False when the audio session refused.
  static Future<bool> keepAliveStart() async {
    if (!isIos) return false;
    try {
      return await _channel.invokeMethod<bool>('keepAliveStart') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> keepAliveStop() async {
    if (!isIos) return;
    try {
      await _channel.invokeMethod<void>('keepAliveStop');
    } catch (_) {}
  }

  /// Holds (or releases) a `beginBackgroundTask` assertion: the ~30 s iOS
  /// grants on request, so a transfer in flight is not cut off when the app
  /// leaves the screen.
  static Future<bool> backgroundHold(bool on) async {
    if (!isIos) return false;
    try {
      return await _channel.invokeMethod<bool>('backgroundHold', {'on': on}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// `{running, playing, held, refresh, startedAt}`; null off iOS.
  static Future<Map<String, Object?>?> backgroundStatus() async {
    if (!isIos) return null;
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>('backgroundStatus');
      return raw?.cast<String, Object?>();
    } catch (_) {
      return null;
    }
  }

  /// Hands a `BGTask` back to iOS. Not answering it wastes the app's budget
  /// for the next ones.
  static Future<void> backgroundTaskDone(String id, {bool ok = true}) async {
    if (!isIos) return;
    try {
      await _channel.invokeMethod<void>('backgroundTaskDone', {'id': id, 'ok': ok});
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------

  static Future<void> acquireMulticastLock() async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('acquireMulticastLock');
    } catch (_) {}
  }

  static Future<void> releaseMulticastLock() async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('releaseMulticastLock');
    } catch (_) {}
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!_android) return true;
    try {
      return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> requestIgnoreBatteryOptimizations() async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  /// Copies a received file into `Download/PepoConnect` through MediaStore
  /// so it shows up in the Files app. Returns the content URI or null.
  static Future<String?> saveToDownloads(String path, String name, String mime) async {
    if (!_android) return null;
    try {
      return await _channel.invokeMethod<String>('saveToDownloads', {
        'path': path,
        'name': name,
        'mime': mime,
      });
    } catch (_) {
      return null;
    }
  }

  /// Plays a short 16-bit mono WAV (the transfer chime) on the notification
  /// stream. Android and iOS; false when it could not be played.
  static Future<bool> playWav(Uint8List wav, {required int sampleRate}) async {
    if (!_mobile) return false;
    try {
      return await _channel.invokeMethod<bool>('playWav', {'wav': wav, 'sampleRate': sampleRate}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openAppSettings() async {
    if (!_mobile) return;
    try {
      await _channel.invokeMethod<void>('openAppSettings');
    } catch (_) {}
  }
}
