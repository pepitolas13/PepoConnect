import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';

import 'pepo_native.dart';

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

  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _mobile.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _mobile.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    if (_ready) return;
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await localNotifier.setup(appName: 'PepoConnect');
      } else if (_isMobile) {
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
          await _android?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              'PepoConnect',
              description: 'Fotos nuevas y transferencias',
              importance: Importance.defaultImportance,
            ),
          );
        }
      }
      _ready = true;
    } catch (_) {
      _ready = false;
      return;
    }
    await promptOnce();
  }

  bool _prompted = false;

  /// Asks the system for permission once (Android 13+ dialog, iOS prompt).
  /// On Android the dialog needs a window: when the engine started behind
  /// the foreground service this waits, and [AppServices] calls it again on
  /// the first resume.
  Future<void> promptOnce() async {
    if (_prompted || !_ready || !_isMobile) return;
    if (Platform.isAndroid && !await PepoNative.hasActivity()) return;
    _prompted = true;
    await requestPermission();
  }

  /// Whether the system lets PepoConnect show notifications.
  Future<bool> enabled() async {
    if (!_isMobile) return true;
    try {
      if (Platform.isAndroid) return await _android?.areNotificationsEnabled() ?? false;
      return (await _ios?.checkPermissions())?.isEnabled ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests permission (Android 13+ dialog, iOS prompt); true if granted.
  /// Without a window on Android there is nobody to show the dialog (the
  /// plugin would crash), so it just reports the current state.
  Future<bool> requestPermission() async {
    if (!_isMobile) return true;
    try {
      if (Platform.isAndroid) {
        if (!await PepoNative.hasActivity()) return await enabled();
        return await _android?.requestNotificationsPermission() ?? false;
      }
      return await _ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    } catch (_) {
      return false;
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
