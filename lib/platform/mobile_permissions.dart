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
    this.photosLimited = false,
  });

  final bool photos;
  final bool notifications;
  final bool batteryUnrestricted;

  /// iOS only: access was granted to a hand-picked selection. It counts as
  /// [photos] for iOS, but new photos never show up, so automatic sending
  /// silently does nothing.
  final bool photosLimited;

  bool get allGranted => photos && !photosLimited && notifications && batteryUnrestricted;
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
      photosLimited: await MediaSourcePhotoManager.permissionLimited(),
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

  /// Only the system settings can turn a limited photo selection into full
  /// access; the in-app picker just adds more photos to the selection.
  static Future<void> openSystemSettings() => PepoNative.openAppSettings();
}
