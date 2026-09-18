import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/bootstrap.dart';
import '../../state/app_settings.dart';
import '../../state/engine_providers.dart';

/// Facts about this device that only the engine knows (effective name, id,
/// download root, version). Tests override the provider instead of faking
/// an engine.
@immutable
class LocalDeviceFacts {
  const LocalDeviceFacts({
    required this.deviceName,
    required this.systemName,
    required this.shortId,
    required this.downloadRoot,
    required this.appVersion,
    this.profile,
  });

  /// Name announced on the network right now.
  final String deviceName;

  /// Host name on desktop, model on mobile; shown under the editable name.
  final String systemName;

  /// `PEPO-XXXX-XXXX`.
  final String shortId;

  /// Folder the engine writes received files to right now.
  final String downloadRoot;
  final String appVersion;

  /// Second-instance profile, if any.
  final String? profile;
}

final localDeviceFactsProvider = Provider<LocalDeviceFacts>((ref) {
  final engine = ref.watch(engineProvider);
  // The engine emits a devices change when the local name changes, which is
  // the cheapest signal that `engine.config` moved.
  ref.watch(devicesProvider);
  final config = engine.config;
  return LocalDeviceFacts(
    deviceName: config.deviceName,
    systemName: isDesktop ? _hostName() : (config.model ?? config.deviceName),
    shortId: engine.shortId,
    downloadRoot: config.downloadRoot,
    appVersion: config.appVersion,
    profile: config.profile,
  );
});

String _hostName() {
  try {
    return Platform.localHostname;
  } catch (_) {
    return 'PC';
  }
}

/// Settings changes that need the engine on top of the persisted value.
/// Everything else is applied by `AppServices` when the settings change.
class SettingsActions {
  SettingsActions(this._ref);

  final Ref _ref;

  /// Back to the platform default folder. `AppServices` only pushes non-null
  /// roots to the engine, so the default is applied here.
  Future<void> resetDownloadRoot() async {
    final engine = _ref.read(engineProvider);
    final paths = await AppPaths.resolve(LaunchOptions(profile: engine.config.profile));
    await engine.setDownloadRoot(paths.defaultDownloadRoot);
    await _ref.read(settingsProvider.notifier).update((s) => s.copyWith(clearDownloadRoot: true));
    _ref.invalidate(localDeviceFactsProvider);
  }

  /// Mobile: forward every new photo to [hubId] (or stop doing so).
  void setAutoSend(String hubId, bool enabled) {
    _ref.read(engineProvider).setAutoSend(hubId, enabled);
  }

  /// Every preference back to its default. Paired devices, the window
  /// geometry and the onboarding flag are kept.
  Future<void> resetAll() async {
    final engine = _ref.read(engineProvider);
    final profile = engine.config.profile;
    final identity = await defaultDeviceIdentity();
    final name = profile == null ? identity.name : '${identity.name} ($profile)';
    final paths = await AppPaths.resolve(LaunchOptions(profile: profile));
    await _ref
        .read(settingsProvider.notifier)
        .update((s) => AppSettings(onboarded: s.onboarded, windowBounds: s.windowBounds));
    await engine.setDeviceName(name);
    await engine.setDownloadRoot(paths.defaultDownloadRoot);
    engine.setSeparateByDevice(true);
    _ref.invalidate(localDeviceFactsProvider);
  }
}

final settingsActionsProvider = Provider<SettingsActions>(SettingsActions.new);
