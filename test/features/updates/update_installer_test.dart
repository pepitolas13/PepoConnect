import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pepoconnect/features/settings/update_checker.dart';
import 'package:pepoconnect/features/updates/update_desktop.dart';
import 'package:pepoconnect/features/updates/update_download.dart';
import 'package:pepoconnect/features/updates/update_installer.dart';
import 'package:pepoconnect/features/updates/update_target.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  final bytes = utf8.encode('verified release executable');
  const base = 'https://github.com/pepitolas13/PepoConnect/releases/download/v1.2.3';
  const channel = MethodChannel('test/updater');
  setUp(() async => temp = await Directory.systemTemp.createTemp('pepo-installer-test-'));
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
    await temp.delete(recursive: true);
  });

  ({UpdateCheckResult release, UpdateTransport Function() transport}) fixture(
    String name, {
    String? hash,
    String checksumTag = 'v1.2.3',
    void Function()? onAsset,
  }) {
    final checksum = utf8.encode('${hash ?? sha256.convert(bytes)}  $name\n');
    return (
      release: UpdateCheckResult(
        latest: '1.2.3',
        url: 'https://github.com/pepitolas13/PepoConnect/releases/tag/v1.2.3',
        isNewer: true,
        assets: [
          UpdateAsset(name: name, url: '$base/$name', size: bytes.length),
          UpdateAsset(
            name: 'SHA256SUMS.txt',
            url: '$base/SHA256SUMS.txt'.replaceFirst('v1.2.3', checksumTag),
            size: checksum.length,
          ),
        ],
      ),
      transport: () => _Transport((uri) async {
        if (uri.pathSegments.last == name) onAsset?.call();
        return UpdateResponse(
          200,
          {},
          Stream.value(uri.pathSegments.last == 'SHA256SUMS.txt' ? checksum : bytes),
        );
      }),
    );
  }

  test('a bad checksum never prepares replacement or requests restart', () async {
    final data = fixture('PepoConnect-win-x64.exe', hash: '0' * 64);
    final installed = await File(p.join(temp.path, 'PepoConnect.exe')).writeAsString('old');
    var prepared = false;
    var restarted = false;
    final installer = UpdateInstaller(
      runtime: UpdateRuntime(
        os: 'windows',
        architecture: 'x64',
        executable: installed.path,
        environment: {'PEPOCONNECT_LAUNCHER': installed.path},
      ),
      temporaryDirectory: () async => temp,
      transportFactory: data.transport,
      prepareDesktop: (plan) async {
        prepared = true;
        return _Handoff(plan.work);
      },
    );
    await expectLater(
      installer.install(
        data.release,
        onProgress: (_) {},
        beforeRestart: () async {
          restarted = true;
        },
      ),
      throwsA(isA<UpdateInstallException>().having((e) => e.code, 'code', 'verification')),
    );
    expect(prepared, isFalse);
    expect(restarted, isFalse);
    expect(await installed.readAsString(), 'old');
    installer.dispose();
  });

  test('checksum from another release is rejected before any download', () async {
    final data = fixture('PepoConnect-android-arm64-v8a.apk', checksumTag: 'v1.2.2');
    final installer = UpdateInstaller(
      runtime: const UpdateRuntime(os: 'android', architecture: 'arm64', executable: ''),
      temporaryDirectory: () async => temp,
      transportFactory: data.transport,
      nativeChannel: channel,
    );
    await expectLater(
      installer.install(data.release, onProgress: (_) {}, beforeRestart: () async {}),
      throwsA(isA<UpdateInstallException>().having((e) => e.code, 'code', 'verification')),
    );
    installer.dispose();
  });

  test('failed restart callback aborts helper and leaves installation untouched', () async {
    final data = fixture('PepoConnect-win-x64.exe');
    final installed = await File(p.join(temp.path, 'PepoConnect.exe')).writeAsString('old');
    late _Handoff handoff;
    final installer = UpdateInstaller(
      runtime: UpdateRuntime(
        os: 'windows',
        architecture: 'x64',
        executable: installed.path,
        environment: {'PEPOCONNECT_LAUNCHER': installed.path},
      ),
      temporaryDirectory: () async => temp,
      transportFactory: data.transport,
      prepareDesktop: (plan) async => handoff = _Handoff(plan.work),
    );
    await expectLater(
      installer.install(
        data.release,
        onProgress: (_) {},
        beforeRestart: () async {
          throw const UpdateInstallException('busy', 'Transfer active');
        },
      ),
      throwsA(isA<UpdateInstallException>().having((e) => e.code, 'code', 'busy')),
    );
    expect(handoff.committed, isTrue);
    expect(handoff.aborted, isTrue);
    expect(await installed.readAsString(), 'old');
    expect(await handoff.work.exists(), isFalse);
    installer.dispose();
  });

  test('desktop download cache is removed before the restart callback exits', () async {
    final data = fixture('PepoConnect-win-x64.exe');
    final installed = await File(p.join(temp.path, 'PepoConnect.exe')).writeAsString('old');
    final installer = UpdateInstaller(
      runtime: UpdateRuntime(
        os: 'windows',
        architecture: 'x64',
        executable: installed.path,
        environment: {'PEPOCONNECT_LAUNCHER': installed.path},
      ),
      temporaryDirectory: () async => temp,
      transportFactory: data.transport,
      launchArguments: const ['--profile', 'office pc'],
      prepareDesktop: (plan) async {
        expect(plan.launchArguments, ['--profile', 'office pc']);
        return _Handoff(plan.work);
      },
    );
    await installer.install(
      data.release,
      onProgress: (_) {},
      beforeRestart: () async {
        expect(
          await temp
              .list()
              .where((entity) => p.basename(entity.path).startsWith('pepoconnect-download-'))
              .isEmpty,
          isTrue,
        );
      },
    );
    installer.dispose();
  });

  test('Flatpak needs checksums and a failed portal launch is actionable', () async {
    final data = fixture('PepoConnect-linux-x64.flatpak');
    final installer = UpdateInstaller(
      runtime: const UpdateRuntime(
        os: 'linux',
        architecture: 'x64',
        executable: '/app/pepoconnect',
        environment: {'FLATPAK_ID': 'org.pepoconnect.PepoConnect'},
      ),
      temporaryDirectory: () async => temp,
      transportFactory: data.transport,
      openFile: (_) async => false,
    );
    final incomplete = UpdateCheckResult(
      latest: data.release.latest,
      url: data.release.url,
      isNewer: true,
      assets: [data.release.assets.first],
    );
    expect(await installer.support(incomplete), UpdateSupport.unavailable);
    await expectLater(
      installer.install(data.release, onProgress: (_) {}, beforeRestart: () async {}),
      throwsA(isA<UpdateInstallException>().having((e) => e.code, 'code', 'unsupported')),
    );
    installer.dispose();
  });

  test('startup confirmation ignores stale or unwritable helper markers', () async {
    final work = await Directory(p.join(temp.path, '.pepoconnect-update-health')).create();
    final marker = p.join(work.path, 'health');
    await Directory(marker).create();
    await UpdateInstaller.confirmStartup(environment: {'PEPOCONNECT_UPDATE_HEALTH': marker});
    await Directory(marker).delete();
    await File(p.join(work.path, 'result')).writeAsString('installed');
    await UpdateInstaller.confirmStartup(environment: {'PEPOCONNECT_UPDATE_HEALTH': marker});
    expect(await File(marker).exists(), isFalse);
  });

  test('Android permission retry reuses verified bytes and checks native eligibility', () async {
    var assetDownloads = 0;
    var allowed = false;
    var installs = 0;
    var restartCalls = 0;
    final data = fixture('PepoConnect-android-arm64-v8a.apk', onAsset: () => assetDownloads++);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        switch (call.method) {
          case 'updateCacheDirectory':
            return temp.path;
          case 'updateCanInstall':
            return allowed;
          case 'updateInstall':
            installs++;
            final args = call.arguments as Map;
            expect(await File(args['path'] as String).readAsBytes(), bytes);
            expect(args['version'], '1.2.3');
            expect(args['sha256'], sha256.convert(bytes).toString());
            return allowed ? 'installerOpened' : 'permissionRequired';
        }
        throw StateError('Unexpected native method: ${call.method}');
      },
    );
    final installer = UpdateInstaller(
      runtime: const UpdateRuntime(os: 'android', architecture: 'arm64', executable: ''),
      temporaryDirectory: () async => temp,
      transportFactory: data.transport,
      nativeChannel: channel,
    );
    Future<void> restart() async {
      restartCalls++;
    }

    expect(
      await installer.install(data.release, onProgress: (_) {}, beforeRestart: restart),
      UpdateInstallOutcome.permissionRequired,
    );
    expect(await installer.canResumeAfterPermission(), isFalse);
    allowed = true;
    expect(await installer.canResumeAfterPermission(), isTrue);
    expect(
      await installer.install(data.release, onProgress: (_) {}, beforeRestart: restart),
      UpdateInstallOutcome.installerOpened,
    );
    expect(assetDownloads, 1);
    expect(installs, 2);
    expect(restartCalls, 0);
    installer.dispose();
  });
}

class _Transport implements UpdateTransport {
  _Transport(this.respond);
  final Future<UpdateResponse> Function(Uri) respond;
  @override
  Future<UpdateResponse> open(Uri uri) => respond(uri);
  @override
  void close() {}
}

class _Handoff implements DesktopHandoff {
  _Handoff(this.work);
  @override
  final Directory work;
  bool committed = false;
  bool aborted = false;
  @override
  Future<void> commit() async {
    committed = true;
  }

  @override
  Future<void> abort() async {
    aborted = true;
  }

  @override
  Future<String> get finished async => aborted ? 'aborted' : 'installed';
}
