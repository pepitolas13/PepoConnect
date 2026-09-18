import 'dart:io';

import 'package:flutter/services.dart';

/// Thin wrapper over the `org.pepoconnect/native` channel (`PepoNative.kt` on
/// Android, `AppDelegate.swift` on iOS). Every call is a no-op elsewhere.
class PepoNative {
  const PepoNative._();

  static const _channel = MethodChannel('org.pepoconnect/native');

  static bool get _available => Platform.isAndroid;

  /// Android has the native side of this channel.
  static bool get isSupported => _available;

  /// Clipboard text handed over by the native side (Android quick-settings
  /// tile / launcher shortcut). Returns `{'sent': [device names]}`.
  static Future<Map<String, Object?>> Function(String text)? onClipboardText;

  /// Listens for native → Dart calls. Idempotent.
  static void init() {
    if (!_available) return;
    _channel.setMethodCallHandler(_onCall);
  }

  static Future<Object?> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'clipboardText':
        final text = call.arguments as String? ?? '';
        final handler = onClipboardText;
        if (handler == null || text.isEmpty) return {'sent': <String>[]};
        return handler(text);
      default:
        throw MissingPluginException('${call.method} is not handled in Dart');
    }
  }

  /// Tells the native side that [init] ran. A native → Dart call made
  /// before the handler exists sits in the channel buffer unanswered, so
  /// the native side must not use the channel until it hears this.
  static Future<void> markClipboardReady() async {
    if (!_available) return;
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
    if (!_available) return true;
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
    if (!_available) return false;
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
    if (!_available) return false;
    try {
      return await _channel.invokeMethod<bool>('serviceUpdate', {'title': title, 'text': text}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> serviceStop() async {
    if (!_available) return;
    try {
      await _channel.invokeMethod<void>('serviceStop');
    } catch (_) {}
  }

  static Future<bool> serviceRunning() async {
    if (!_available) return false;
    try {
      return await _channel.invokeMethod<bool>('serviceRunning') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> acquireMulticastLock() async {
    if (!_available) return;
    try {
      await _channel.invokeMethod<void>('acquireMulticastLock');
    } catch (_) {}
  }

  static Future<void> releaseMulticastLock() async {
    if (!_available) return;
    try {
      await _channel.invokeMethod<void>('releaseMulticastLock');
    } catch (_) {}
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!_available) return true;
    try {
      return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> requestIgnoreBatteryOptimizations() async {
    if (!_available) return;
    try {
      await _channel.invokeMethod<void>('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  /// Copies a received file into `Download/PepoConnect` through MediaStore
  /// so it shows up in the Files app. Returns the content URI or null.
  static Future<String?> saveToDownloads(String path, String name, String mime) async {
    if (!_available) return null;
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
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('playWav', {'wav': wav, 'sampleRate': sampleRate}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openAppSettings() async {
    if (!_available) return;
    try {
      await _channel.invokeMethod<void>('openAppSettings');
    } catch (_) {}
  }
}
