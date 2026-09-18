import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pepo_core/pepo_core.dart';
import 'package:window_manager/window_manager.dart';

import '../../platform/desktop_integration.dart';
import '../../platform/pepo_native.dart';
import '../../state/app_settings.dart';
import '../../state/engine_providers.dart';
import '../settings/settings_providers.dart';
import '../settings/update_checker.dart';
import 'update_controller.dart';
import 'update_installer.dart';

/// Preserve the exact startup options across an updater restart.
final updateLaunchArgumentsProvider = Provider<List<String>>((ref) => const []);

final updateStoreProvider = Provider<UpdateStore>(
  (ref) => PreferencesUpdateStore(ref.read(sharedPreferencesProvider)),
);

final updateCanInstallProvider = Provider<bool>((ref) {
  ref.watch(engineEventsProvider);
  final engine = ref.read(engineProvider);
  return engine.guestSession == null &&
      engine.activeGuestTransfers == 0 &&
      !engine.activeTransfers.any(
        (t) => t.state == TransferState.active || t.state == TransferState.queued,
      );
});

/// Keep foreground offers out of a hidden tray window or a headless Android engine.
final updateForegroundProvider = Provider<Future<bool> Function()>(
  (ref) => () async {
    if (Platform.isAndroid) return PepoNative.hasActivity();
    if (DesktopIntegration.isSupported) {
      return await windowManager.isVisible() && !await windowManager.isMinimized();
    }
    return true;
  },
);

final updateControllerProvider = Provider<UpdateController>((ref) {
  // A device rename or connection event must not replace an in-flight updater.
  final version = ref.read(localDeviceFactsProvider).appVersion;
  final controller = UpdateController(
    currentVersion: version,
    store: ref.watch(updateStoreProvider),
    installer: UpdateInstaller(launchArguments: ref.read(updateLaunchArgumentsProvider)),
    check: () => checkForUpdates(currentVersion: version),
    canInstall: () {
      final engine = ref.read(engineProvider);
      return engine.guestSession == null &&
          engine.activeGuestTransfers == 0 &&
          !engine.activeTransfers.any(
            (t) => t.state == TransferState.active || t.state == TransferState.queued,
          );
    },
    beforeRestart: () async {
      await ref.read(engineProvider).stop();
      await DesktopIntegration.instance.quit();
    },
  );
  ref.onDispose(controller.dispose);
  return controller;
});
