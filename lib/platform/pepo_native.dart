import 'dart:io';

import 'package:flutter/services.dart';

/// Thin wrapper over the Android `org.pepoconnect/native` channel
/// (`PepoNative.kt`). Every call is a no-op elsewhere.
class PepoNative {
  const PepoNative._();

  static const _channel = MethodChannel('org.pepoconnect/native');

  static bool get _available => Platform.isAndroid;

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

  static Future<void> openAppSettings() async {
    if (!_available) return;
    try {
      await _channel.invokeMethod<void>('openAppSettings');
    } catch (_) {}
  }
}
