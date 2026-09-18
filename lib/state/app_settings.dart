import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light / dark / follow the system.
enum AppThemeMode { system, light, dark }

/// User preferences. Persisted as one JSON blob in shared preferences.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.locale = 'system',
    this.animations = true,
    this.downloadRoot,
    this.separateByDevice = true,
    this.startWithSystem = false,
    this.minimizeToTray = true,
    this.notifications = true,
    this.sounds = false,
    this.deviceName,
    this.clipboardSharing = false,
    this.autoSendPhotos = false,
    this.backgroundService = true,
    this.defaultHubId,
    this.onboarded = false,
    this.allowExecutables = false,
    this.galleryTileSize = GalleryTileSize.medium,
    this.gallerySquare = true,
    this.activityPanelOpen = true,
    this.railExpanded = false,
    this.windowBounds,
  });

  final AppThemeMode themeMode;

  /// `system`, `es` or `en`.
  final String locale;
  final bool animations;

  /// Null = platform default (`Pictures/PepoConnect`).
  final String? downloadRoot;
  final bool separateByDevice;
  final bool startWithSystem;
  final bool minimizeToTray;
  final bool notifications;
  final bool sounds;

  /// Null = host name / device model.
  final String? deviceName;
  final bool clipboardSharing;

  /// Mobile: send every new photo to the default hub automatically.
  final bool autoSendPhotos;

  /// Mobile: keep the foreground service (and the connection) alive.
  final bool backgroundService;
  final String? defaultHubId;
  final bool onboarded;

  /// Unison refused executables; we only warn unless this is on.
  final bool allowExecutables;
  final GalleryTileSize galleryTileSize;
  final bool gallerySquare;
  final bool activityPanelOpen;
  final bool railExpanded;

  /// `[x, y, w, h]` of the desktop window.
  final List<double>? windowBounds;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    String? locale,
    bool? animations,
    String? downloadRoot,
    bool clearDownloadRoot = false,
    bool? separateByDevice,
    bool? startWithSystem,
    bool? minimizeToTray,
    bool? notifications,
    bool? sounds,
    String? deviceName,
    bool? clipboardSharing,
    bool? autoSendPhotos,
    bool? backgroundService,
    String? defaultHubId,
    bool clearDefaultHub = false,
    bool? onboarded,
    bool? allowExecutables,
    GalleryTileSize? galleryTileSize,
    bool? gallerySquare,
    bool? activityPanelOpen,
    bool? railExpanded,
    List<double>? windowBounds,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    locale: locale ?? this.locale,
    animations: animations ?? this.animations,
    downloadRoot: clearDownloadRoot ? null : (downloadRoot ?? this.downloadRoot),
    separateByDevice: separateByDevice ?? this.separateByDevice,
    startWithSystem: startWithSystem ?? this.startWithSystem,
    minimizeToTray: minimizeToTray ?? this.minimizeToTray,
    notifications: notifications ?? this.notifications,
    sounds: sounds ?? this.sounds,
    deviceName: deviceName ?? this.deviceName,
    clipboardSharing: clipboardSharing ?? this.clipboardSharing,
    autoSendPhotos: autoSendPhotos ?? this.autoSendPhotos,
    backgroundService: backgroundService ?? this.backgroundService,
    defaultHubId: clearDefaultHub ? null : (defaultHubId ?? this.defaultHubId),
    onboarded: onboarded ?? this.onboarded,
    allowExecutables: allowExecutables ?? this.allowExecutables,
    galleryTileSize: galleryTileSize ?? this.galleryTileSize,
    gallerySquare: gallerySquare ?? this.gallerySquare,
    activityPanelOpen: activityPanelOpen ?? this.activityPanelOpen,
    railExpanded: railExpanded ?? this.railExpanded,
    windowBounds: windowBounds ?? this.windowBounds,
  );

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.name,
    'locale': locale,
    'animations': animations,
    'downloadRoot': downloadRoot,
    'separateByDevice': separateByDevice,
    'startWithSystem': startWithSystem,
    'minimizeToTray': minimizeToTray,
    'notifications': notifications,
    'sounds': sounds,
    'deviceName': deviceName,
    'clipboardSharing': clipboardSharing,
    'autoSendPhotos': autoSendPhotos,
    'backgroundService': backgroundService,
    'defaultHubId': defaultHubId,
    'onboarded': onboarded,
    'allowExecutables': allowExecutables,
    'galleryTileSize': galleryTileSize.name,
    'gallerySquare': gallerySquare,
    'activityPanelOpen': activityPanelOpen,
    'railExpanded': railExpanded,
    'windowBounds': windowBounds,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    themeMode: AppThemeMode.values.byName(j['themeMode'] as String? ?? 'system'),
    locale: j['locale'] as String? ?? 'system',
    animations: j['animations'] as bool? ?? true,
    downloadRoot: j['downloadRoot'] as String?,
    separateByDevice: j['separateByDevice'] as bool? ?? true,
    startWithSystem: j['startWithSystem'] as bool? ?? false,
    minimizeToTray: j['minimizeToTray'] as bool? ?? true,
    notifications: j['notifications'] as bool? ?? true,
    sounds: j['sounds'] as bool? ?? false,
    deviceName: j['deviceName'] as String?,
    clipboardSharing: j['clipboardSharing'] as bool? ?? false,
    autoSendPhotos: j['autoSendPhotos'] as bool? ?? false,
    backgroundService: j['backgroundService'] as bool? ?? true,
    defaultHubId: j['defaultHubId'] as String?,
    onboarded: j['onboarded'] as bool? ?? false,
    allowExecutables: j['allowExecutables'] as bool? ?? false,
    galleryTileSize: GalleryTileSize.values.byName(j['galleryTileSize'] as String? ?? 'medium'),
    gallerySquare: j['gallerySquare'] as bool? ?? true,
    activityPanelOpen: j['activityPanelOpen'] as bool? ?? true,
    railExpanded: j['railExpanded'] as bool? ?? false,
    windowBounds: (j['windowBounds'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList(),
  );
}

enum GalleryTileSize { large, medium, small }

/// Overridden in `main` with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

class SettingsNotifier extends Notifier<AppSettings> {
  static const _key = 'pepo.settings';

  /// Reads the persisted settings without a provider (used before the
  /// container exists).
  static AppSettings load(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_key);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  /// Applies [change] and persists the result.
  Future<void> update(AppSettings Function(AppSettings current) change) async {
    final next = change(state);
    state = next;
    await ref.read(sharedPreferencesProvider).setString(_key, jsonEncode(next.toJson()));
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
