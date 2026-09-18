import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:pepo_core/pepo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/app_services.dart';
import 'app/bootstrap.dart';
import 'app/shell/window_effects.dart';
import 'features/updates/update_providers.dart';
import 'platform/desktop_integration.dart';
import 'platform/media_source_photo_manager.dart';
import 'platform/notifications.dart';
import 'shared/motion/toast.dart';
import 'state/app_settings.dart';
import 'state/engine_providers.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final options = LaunchOptions.parse(args);
  if (options.profile == null) await DesktopIntegration.ensureSingleInstance(args);
  _setupLogging();

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsNotifier.load(prefs);
  final paths = await AppPaths.resolve(options);

  MediaSource? mediaSource;
  if (Platform.isAndroid || Platform.isIOS) {
    mediaSource = MediaSourcePhotoManager(cacheDir: p.join(paths.cacheDir, 'own'));
  }
  final engine = await startEngine(
    settings: settings,
    paths: paths,
    options: options,
    mediaSource: mediaSource,
  );

  if (DesktopIntegration.isSupported) {
    final b = settings.windowBounds;
    await DesktopIntegration.instance.init(
      title: options.profile == null ? 'PepoConnect' : 'PepoConnect (${options.profile})',
      bounds: b != null && b.length == 4 ? Rect.fromLTWH(b[0], b[1], b[2], b[3]) : null,
      startHidden: options.minimized,
    );
    DesktopIntegration.instance.minimizeToTray = settings.minimizeToTray;
  }
  await SystemNotifications.instance.init();

  final toasts = ToastService();
  final container = ProviderContainer(
    overrides: [
      updateLaunchArgumentsProvider.overrideWithValue(List.unmodifiable(args)),
      sharedPreferencesProvider.overrideWithValue(prefs),
      engineProvider.overrideWithValue(engine),
      dataDirProvider.overrideWithValue(paths.dataDir),
      toastServiceProvider.overrideWithValue(toasts),
    ],
  );
  if (DesktopIntegration.isSupported) {
    final desktop = DesktopIntegration.instance;
    desktop.onBoundsChanged = (r) => container
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(windowBounds: [r.left, r.top, r.width, r.height]));
    desktop.onPauseAll = () {
      for (final t in engine.activeTransfers) {
        engine.cancelTransfer(t.id, pause: true);
      }
    };
    desktop.onOpenDownloads = () =>
        Process.run(Platform.isWindows ? 'explorer.exe' : 'xdg-open', [engine.config.downloadRoot]);
    desktop.onQuit = () => engine.stop();
  }

  runApp(UncontrolledProviderScope(container: container, child: const PepoApp()));

  if (Platform.isWindows) {
    final dark = _isDark(settings.themeMode);
    await applyWindowEffects(dark: dark);
  }
}

bool _isDark(AppThemeMode mode) => switch (mode) {
  AppThemeMode.system => PlatformDispatcher.instance.platformBrightness == Brightness.dark,
  AppThemeMode.light => false,
  AppThemeMode.dark => true,
};

void _setupLogging() {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((r) {
    debugPrint('[${r.level.name}] ${r.loggerName}: ${r.message}');
  });
}
