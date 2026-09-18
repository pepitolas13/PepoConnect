import 'dart:io';

import 'media_source_photo_manager.dart';
import 'notifications.dart';
import 'pepo_native.dart';

/// State of the permissions the mobile app needs.
class MobilePermissionState {
  const MobilePermissionState({
    required this.photos,
    required this.notifications,
    required this.batteryUnrestricted,
  });

  final bool photos;
  final bool notifications;
  final bool batteryUnrestricted;

  bool get allGranted => photos && notifications && batteryUnrestricted;
}

/// Requests and checks Android/iOS permissions (photos, notifications,
/// battery optimisation exemption).
class MobilePermissions {
  const MobilePermissions._();

  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static Future<MobilePermissionState> check() async {
    if (!isMobile) {
      return const MobilePermissionState(
        photos: true,
        notifications: true,
        batteryUnrestricted: true,
      );
    }
    return MobilePermissionState(
      photos: await MediaSourcePhotoManager.hasPermission(),
      notifications: await SystemNotifications.instance.enabled(),
      batteryUnrestricted: Platform.isIOS || await PepoNative.isIgnoringBatteryOptimizations(),
    );
  }

  static Future<bool> requestPhotos() => MediaSourcePhotoManager.requestPermission();

  static Future<bool> requestNotifications() async {
    if (!isMobile) return true;
    return SystemNotifications.instance.requestPermission();
  }

  static Future<void> requestBattery() async {
    if (!Platform.isAndroid) return;
    await PepoNative.requestIgnoreBatteryOptimizations();
  }
}
