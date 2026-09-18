import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pepoconnect/features/settings/update_checker.dart';
import 'package:pepoconnect/features/updates/update_target.dart';

void main() {
  UpdateCheckResult release(List<String> names) => UpdateCheckResult(
    latest: '1.2.3',
    url: 'https://github.com/pepitolas13/PepoConnect/releases/tag/v1.2.3',
    isNewer: true,
    assets: names
        .map(
          (name) => UpdateAsset(
            name: name,
            url: 'https://github.com/pepitolas13/PepoConnect/releases/download/v1.2.3/$name',
            size: 3,
          ),
        )
        .toList(),
  );
  test('Windows launcher replaces launcher rather than extracted bundle', () {
    final target = selectUpdateTarget(
      UpdateRuntime(
        os: 'windows',
        architecture: 'x64',
        executable: r'C:\Users\Dan\app\pepoconnect.exe',
        environment: const {'PEPOCONNECT_LAUNCHER': r'D:\Downloads\PepoConnect.exe'},
      ),
      release(['PepoConnect-win-x64.exe']),
    );
    expect(target?.kind, UpdateTargetKind.windowsLauncher);
    expect(target?.destination, r'D:\Downloads\PepoConnect.exe');
  });
  test('Windows raw bundle chooses portable ZIP and unsupported arch is rejected', () {
    final target = selectUpdateTarget(
      UpdateRuntime(
        os: 'windows',
        architecture: 'x64',
        executable: r'C:\PepoConnect\pepoconnect.exe',
      ),
      release(['PepoConnect-win-x64-portable.zip']),
    );
    expect(target?.kind, UpdateTargetKind.windowsBundle);
    expect(target?.destination, r'C:\PepoConnect');
    expect(
      selectUpdateTarget(
        UpdateRuntime(os: 'windows', architecture: 'arm64', executable: r'C:\app.exe'),
        release(['PepoConnect-win-x64.exe']),
      ),
      isNull,
    );
  });
  test(
    'Windows pinned app resolves its persisted launcher and never falls back when missing',
    () async {
      final temp = await Directory.systemTemp.createTemp('pepo-locator-');
      try {
        final executable = p.join(temp.path, 'pepoconnect.exe');
        final launcher = p.join(temp.path, 'PepoConnect-launcher.exe');
        await File(p.join(temp.path, '.launcher-path')).writeAsString(launcher);
        final runtime = UpdateRuntime.detect(
          os: 'windows',
          architecture: 'x64',
          executable: executable,
          environment: const {},
        );
        final target = selectUpdateTarget(
          runtime,
          release(['PepoConnect-win-x64.exe', 'PepoConnect-win-x64-portable.zip']),
        );
        expect(target?.kind, UpdateTargetKind.windowsLauncher);
        expect(target?.destination, launcher);
        await File(p.join(temp.path, '.launcher-path')).writeAsString('invalid-relative.exe');
        expect(
          selectUpdateTarget(
            UpdateRuntime.detect(
              os: 'windows',
              architecture: 'x64',
              executable: executable,
              environment: const {},
            ),
            release(['PepoConnect-win-x64.exe', 'PepoConnect-win-x64-portable.zip']),
          ),
          isNull,
        );
      } finally {
        await temp.delete(recursive: true);
      }
    },
    skip: !Platform.isWindows,
  );
  test('Linux chooses AppImage, tarball or Flatpak explicitly for process architecture', () {
    final assets = release([
      'PepoConnect-linux-arm64.AppImage',
      'PepoConnect-linux-arm64.tar.gz',
      'PepoConnect-linux-arm64.flatpak',
    ]);
    expect(
      selectUpdateTarget(
        UpdateRuntime(
          os: 'linux',
          architecture: 'arm64',
          executable: '/tmp/.mount/app',
          environment: const {'APPIMAGE': '/home/dan/PepoConnect.AppImage'},
        ),
        assets,
      )?.kind,
      UpdateTargetKind.appImage,
    );
    final tar = selectUpdateTarget(
      UpdateRuntime(
        os: 'linux',
        architecture: 'arm64',
        executable: '/home/dan/PepoConnect/bundle/pepoconnect',
      ),
      assets,
    );
    expect(tar?.kind, UpdateTargetKind.linuxBundle);
    expect(tar?.destination, '/home/dan/PepoConnect');
    expect(
      selectUpdateTarget(
        UpdateRuntime(
          os: 'linux',
          architecture: 'arm64',
          executable: '/app/bin/app',
          environment: const {'FLATPAK_ID': 'org.pepoconnect.PepoConnect'},
        ),
        assets,
      )?.kind,
      UpdateTargetKind.flatpak,
    );
  });
  test('Android selects exact process ABI and iOS has external route', () {
    final assets = release([
      'PepoConnect-android-arm64-v8a.apk',
      'PepoConnect-android-x86_64.apk',
      'PepoConnect-ios-unsigned.ipa',
    ]);
    expect(
      selectUpdateTarget(
        UpdateRuntime(os: 'android', architecture: 'arm64', executable: ''),
        assets,
      )?.asset.name,
      'PepoConnect-android-arm64-v8a.apk',
    );
    expect(
      selectUpdateTarget(
        UpdateRuntime(os: 'android', architecture: 'x64', executable: ''),
        assets,
      )?.asset.name,
      'PepoConnect-android-x86_64.apk',
    );
    expect(
      selectUpdateTarget(
        UpdateRuntime(os: 'ios', architecture: 'arm64', executable: ''),
        assets,
      )?.kind,
      UpdateTargetKind.ios,
    );
  });
}
