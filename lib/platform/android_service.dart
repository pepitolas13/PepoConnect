import 'dart:io';

import 'pepo_native.dart';

/// The Android foreground service (`PepoForegroundService.kt`) that keeps the
/// process, and with it the engine in this isolate, alive while the app is
/// not on screen: persistent notification, wake / Wi-Fi / multicast locks.
///
/// Nothing runs in the service. With it up, the window can be closed or
/// swiped away and Dart keeps going; if Android kills the process anyway,
/// or the phone reboots, the service comes back on its own and boots the
/// engine headless, so the PC gets its phone back without anyone opening
/// the app (`main()` runs and the UI attaches later).
class AndroidService {
  const AndroidService._();

  static bool get isSupported => Platform.isAndroid;

  /// Starts the service, or updates its notification if it already runs.
  /// [idleText] is what the notification shows when the service comes back
  /// on its own, before anything is connected.
  static Future<bool> start({
    required String title,
    required String text,
    required String idleText,
  }) async {
    if (!isSupported) return false;
    return PepoNative.serviceStart(title: title, text: text, idle: idleText);
  }

  static Future<void> update({required String title, required String text}) async {
    if (!isSupported) return;
    await PepoNative.serviceUpdate(title: title, text: text);
  }

  static Future<void> stop() async {
    if (!isSupported) return;
    await PepoNative.serviceStop();
  }

  static Future<bool> isRunning() async => isSupported && await PepoNative.serviceRunning();
}
