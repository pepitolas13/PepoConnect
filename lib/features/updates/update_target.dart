import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../settings/update_checker.dart';

class UpdateRuntime {
  const UpdateRuntime({
    required this.os,
    required this.architecture,
    required this.executable,
    this.environment = const {},
  });
  factory UpdateRuntime.current() => UpdateRuntime.detect(
    os: Platform.operatingSystem,
    architecture: Abi.current().toString().split('_').last,
    executable: Platform.resolvedExecutable,
    environment: {
      ...Platform.environment,
      if (Platform.isLinux && File('/.flatpak-info').existsSync())
        'FLATPAK_ID': 'org.pepoconnect.PepoConnect',
    },
  );
  factory UpdateRuntime.detect({
    required String os,
    required String architecture,
    required String executable,
    required Map<String, String> environment,
  }) {
    final detected = Map<String, String>.of(environment);
    if (os == 'windows' && !detected.containsKey('PEPOCONNECT_LAUNCHER')) {
      final locator = File(p.windows.join(p.windows.dirname(executable), '.launcher-path'));
      if (locator.existsSync()) {
        // An unreadable/stale locator deliberately prevents the raw-ZIP fallback:
        // updating only that bundle would be undone by its old launcher.
        try {
          detected['PEPOCONNECT_LAUNCHER'] = locator.readAsStringSync().trim();
        } on FileSystemException {
          detected['PEPOCONNECT_LAUNCHER'] = '';
        }
      } else if (File(p.windows.join(p.windows.dirname(executable), '.bundle-id')).existsSync()) {
        // Older launcher bundles lack a locator. They need one launch through the
        // new stub; treating them as a raw ZIP would allow the old stub to revert.
        detected['PEPOCONNECT_LAUNCHER'] = '';
      }
    }
    return UpdateRuntime(
      os: os,
      architecture: architecture,
      executable: executable,
      environment: detected,
    );
  }
  final String os;
  final String architecture;
  final String executable;
  final Map<String, String> environment;
}

enum UpdateTargetKind {
  windowsLauncher,
  windowsBundle,
  appImage,
  linuxBundle,
  android,
  flatpak,
  ios,
}

class UpdateTarget {
  const UpdateTarget(this.kind, this.asset, this.destination, this.launchPath);
  final UpdateTargetKind kind;
  final UpdateAsset asset;
  final String destination;
  final String launchPath;
  bool get isBundle =>
      kind == UpdateTargetKind.windowsBundle || kind == UpdateTargetKind.linuxBundle;
}

UpdateTarget? selectUpdateTarget(UpdateRuntime runtime, UpdateCheckResult release) {
  UpdateTarget? target(
    UpdateTargetKind kind,
    String name, [
    String destination = '',
    String? launchPath,
  ]) {
    final asset = release.assetNamed(name);
    return asset == null ? null : UpdateTarget(kind, asset, destination, launchPath ?? destination);
  }

  final arch = runtime.architecture;
  if (runtime.os == 'ios') {
    return target(UpdateTargetKind.ios, 'PepoConnect-ios-signed.ipa') ??
        target(UpdateTargetKind.ios, 'PepoConnect-ios-unsigned.ipa');
  }
  if (runtime.os == 'android') {
    final abi = switch (arch) {
      'arm64' => 'arm64-v8a',
      'arm' => 'armeabi-v7a',
      'x64' => 'x86_64',
      _ => null,
    };
    if (abi == null) return null;
    return target(UpdateTargetKind.android, 'PepoConnect-android-$abi.apk');
  }
  if (runtime.os == 'windows' && arch == 'x64') {
    final launcher = runtime.environment['PEPOCONNECT_LAUNCHER'];
    if (launcher != null) {
      return p.windows.isAbsolute(launcher)
          ? target(UpdateTargetKind.windowsLauncher, 'PepoConnect-win-x64.exe', launcher)
          : null;
    }
    if (p.windows.basename(runtime.executable).toLowerCase() != 'pepoconnect.exe') return null;
    return target(
      UpdateTargetKind.windowsBundle,
      'PepoConnect-win-x64-portable.zip',
      p.windows.dirname(runtime.executable),
      runtime.executable,
    );
  }
  if (runtime.os != 'linux' || !['x64', 'arm64'].contains(arch)) return null;
  if (runtime.environment.containsKey('FLATPAK_ID')) {
    return target(UpdateTargetKind.flatpak, 'PepoConnect-linux-$arch.flatpak');
  }
  final appImage = runtime.environment['APPIMAGE'];
  if (appImage != null && p.posix.isAbsolute(appImage)) {
    return target(UpdateTargetKind.appImage, 'PepoConnect-linux-$arch.AppImage', appImage);
  }
  if (p.posix.basename(runtime.executable) == 'pepoconnect' &&
      p.posix.basename(p.posix.dirname(runtime.executable)) == 'bundle') {
    final root = p.posix.dirname(p.posix.dirname(runtime.executable));
    return target(
      UpdateTargetKind.linuxBundle,
      'PepoConnect-linux-$arch.tar.gz',
      root,
      p.posix.join(root, 'PepoConnect.sh'),
    );
  }
  return null;
}
