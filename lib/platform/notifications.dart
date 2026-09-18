import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';

/// System notifications: Windows/Linux toasts via `local_notifier`, Android
/// and iOS via `flutter_local_notifications`.
class SystemNotifications {
  SystemNotifications._();

  static final SystemNotifications instance = SystemNotifications._();

  final _mobile = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  int _nextId = 1;
  void Function(String payload)? onTap;

  static const _channelId = 'pepoconnect.events';

  /// Android status-bar icon: `res/drawable-*/ic_stat_pepoconnect.png`, a white
  /// glyph on transparent rendered by `tool/brand/render_icons.py`. Android
  /// only keeps the alpha of the small icon and tints it with [_androidAccent].
  static const _androidSmallIcon = 'ic_stat_pepoconnect';
  static const _androidAccent = Color(0xFF0A3D8F);

  Future<void> init() async {
    if (_ready) return;
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await localNotifier.setup(appName: 'PepoConnect');
      } else if (Platform.isAndroid || Platform.isIOS) {
        await _mobile.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings(_androidSmallIcon),
            iOS: DarwinInitializationSettings(),
          ),
          onDidReceiveNotificationResponse: (r) {
            final payload = r.payload;
            if (payload != null) onTap?.call(payload);
          },
        );
        if (Platform.isAndroid) {
          final android = _mobile
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          await android?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              'PepoConnect',
              description: 'Fotos nuevas y transferencias',
              importance: Importance.defaultImportance,
            ),
          );
          await android?.requestNotificationsPermission();
        } else {
          await _mobile
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true);
        }
      }
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Shows a notification. [actions] are button labels (desktop only);
  /// [onAction] receives the tapped index.
  Future<void> show({
    required String title,
    String? body,
    String? payload,
    List<String> actions = const [],
    void Function(int index)? onAction,
    VoidCallbackLike? onClick,
  }) async {
    if (!_ready) return;
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final n = LocalNotification(
          title: title,
          body: body,
          actions: [for (final a in actions) LocalNotificationAction(text: a)],
        );
        n.onClick = () {
          onClick?.call();
          if (payload != null) onTap?.call(payload);
        };
        n.onClickAction = (i) => onAction?.call(i);
        await n.show();
      } else {
        await _mobile.show(
          id: _nextId++,
          title: title,
          body: body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              'PepoConnect',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              icon: _androidSmallIcon,
              color: _androidAccent,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: payload,
        );
      }
    } catch (_) {
      // Notifications are best effort.
    }
  }
}

typedef VoidCallbackLike = void Function();
