import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'pepo_native.dart';

/// Keeps the Android process alive while connected so photos keep flowing
/// with the screen off. The engine itself runs in the main isolate; the
/// service only holds the foreground notification, wake/Wi-Fi locks and the
/// multicast lock.
///
/// Limitation of this design: if the user swipes the app away from Recents
/// the UI isolate is destroyed and the connection drops until the app is
/// opened again.
class AndroidService {
  const AndroidService._();

  static bool get isSupported => Platform.isAndroid;
  static bool _initialized = false;

  static Future<void> init() async {
    if (!isSupported || _initialized) return;
    _initialized = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'pepoconnect.service',
        channelName: 'PepoConnect en segundo plano',
        channelDescription: 'Mantiene la conexión con el PC',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
        allowAutoRestart: true,
      ),
    );
  }

  static Future<bool> start({required String title, required String text}) async {
    if (!isSupported) return false;
    await init();
    await PepoNative.acquireMulticastLock();
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(notificationTitle: title, notificationText: text);
      return true;
    }
    final result = await FlutterForegroundTask.startService(
      serviceId: 47473,
      notificationTitle: title,
      notificationText: text,
      notificationIcon: null,
      callback: pepoServiceCallback,
    );
    return result is ServiceRequestSuccess;
  }

  static Future<void> update({required String title, required String text}) async {
    if (!isSupported) return;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(notificationTitle: title, notificationText: text);
    }
  }

  static Future<void> stop() async {
    if (!isSupported) return;
    await PepoNative.releaseMulticastLock();
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  static Future<bool> isRunning() async =>
      isSupported && await FlutterForegroundTask.isRunningService;
}

/// Entry point of the service isolate. It does nothing but exist: the
/// engine lives in the main isolate.
@pragma('vm:entry-point')
void pepoServiceCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveHandler());
}

class _KeepAliveHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
