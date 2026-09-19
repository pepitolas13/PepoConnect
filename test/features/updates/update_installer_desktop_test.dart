import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pepoconnect/features/updates/update_desktop.dart';

void main() {
  late Directory temp;
  setUp(() async => temp = await Directory.systemTemp.createTemp('pepo-update-smoke-'));
  tearDown(() async {
    // Detached helpers publish their result just before exiting. Their cwd now
    // correctly lives in this fixture, so wait for Windows to release its handle.
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (true) {
      try {
        await temp.delete(recursive: true);
        break;
      } on FileSystemException catch (error) {
        if (error.osError?.errorCode != 32 || DateTime.now().isAfter(deadline)) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  test('Windows helper releases the installation working directory before restart', () async {
    final app = await Directory(p.join(temp.path, 'app')).create();
    final destination = await File(p.join(temp.path, 'launcher.bin')).writeAsString('old');
    final staged = await File(p.join(temp.path, 'new.bin')).writeAsString('new');
    final previousDirectory = Directory.current;
    late DesktopHandoff handoff;
    try {
      // The real launcher starts Flutter with app/ as its working directory.
      Directory.current = app;
      handoff = await DesktopHandoff.prepare(
        DesktopUpdatePlan(
          work: await Directory(p.join(temp.path, '.pepoconnect-update-cwd')).create(),
          destination: destination.path,
          staged: staged.path,
          isBundle: false,
          windows: true,
          parentPid: 0,
          launchPath: p.join(temp.path, 'missing.exe'),
        ),
      );
    } finally {
      Directory.current = previousDirectory;
    }
    try {
      // Exiting Flutter must leave this directory free for the launcher swap.
      await app.rename(p.join(temp.path, 'app.old'));
    } finally {
      await handoff.abort();
      expect(await handoff.finished.timeout(const Duration(seconds: 10)), 'aborted');
    }
  }, skip: !Platform.isWindows);

  test('Windows helper replaces file and retains old file until successful startup', () async {
    final destination = await File(p.join(temp.path, 'instalación app.bin')).writeAsString('old');
    final staged = await File(p.join(temp.path, 'new app.bin')).writeAsString('new');
    final handoff = await DesktopHandoff.prepare(
      DesktopUpdatePlan(
        work: await Directory(p.join(temp.path, '.pepoconnect-update-smoke')).create(),
        destination: destination.path,
        staged: staged.path,
        isBundle: false,
        windows: true,
        parentPid: 0,
        healthTimeoutSeconds: 5,
        launchPath: r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe',
        launchArguments: const [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r'[IO.File]::WriteAllText($env:PEPOCONNECT_UPDATE_HEALTH, "healthy")',
        ],
      ),
    );
    expect(await destination.readAsString(), 'old');
    await handoff.commit();
    expect(await handoff.finished.timeout(const Duration(seconds: 15)), 'installed');
    expect(await destination.readAsString(), 'new');
    await Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-WindowStyle',
      'Hidden',
      '-File',
      p.join(handoff.work.path, 'install.ps1'),
      '-Config',
      p.join(handoff.work.path, 'plan.json'),
      '-Recover',
    ]);
    expect(await handoff.finished, 'installed');
    expect(await destination.readAsString(), 'new');
  }, skip: !Platform.isWindows);

  test('Windows helper restores previous file when new application cannot start', () async {
    final destination = await File(p.join(temp.path, 'app.bin')).writeAsString('old');
    final staged = await File(p.join(temp.path, 'new.bin')).writeAsString('new');
    final handoff = await DesktopHandoff.prepare(
      DesktopUpdatePlan(
        work: await Directory(p.join(temp.path, '.pepoconnect-update-rollback')).create(),
        destination: destination.path,
        staged: staged.path,
        isBundle: false,
        windows: true,
        parentPid: 0,
        healthTimeoutSeconds: 2,
        launchPath: p.join(temp.path, 'missing.exe'),
      ),
    );
    await handoff.commit();
    expect(await handoff.finished.timeout(const Duration(seconds: 15)), 'rolledBack');
    expect(await destination.readAsString(), 'old');
  }, skip: !Platform.isWindows);

  test('Windows helper aborts prepared update before touching installed files', () async {
    final destination = await File(p.join(temp.path, 'app.bin')).writeAsString('old');
    final staged = await File(p.join(temp.path, 'new.bin')).writeAsString('new');
    final handoff = await DesktopHandoff.prepare(
      DesktopUpdatePlan(
        work: await Directory(p.join(temp.path, '.pepoconnect-update-abort')).create(),
        destination: destination.path,
        staged: staged.path,
        isBundle: false,
        windows: true,
        parentPid: pid,
        launchPath: destination.path,
      ),
    );
    await handoff.commit();
    await handoff.abort();
    expect(await handoff.finished.timeout(const Duration(seconds: 15)), 'aborted');
    expect(await destination.readAsString(), 'old');
  }, skip: !Platform.isWindows);

  test('Windows bundle update preserves unknown files and rolls back all replaced files', () async {
    final destination = await Directory(p.join(temp.path, 'installation')).create();
    await File(p.join(destination.path, 'app.exe')).writeAsString('old');
    await File(p.join(destination.path, 'user photos.txt')).writeAsString('personal');
    final staged = await Directory(p.join(temp.path, 'staged')).create();
    await File(p.join(staged.path, 'app.exe')).writeAsString('new');
    await File(p.join(staged.path, 'new.dll')).writeAsString('new dependency');
    final handoff = await DesktopHandoff.prepare(
      DesktopUpdatePlan(
        work: await Directory(p.join(temp.path, '.pepoconnect-update-bundle')).create(),
        destination: destination.path,
        staged: staged.path,
        isBundle: true,
        windows: true,
        parentPid: 0,
        launchPath: p.join(temp.path, 'missing.exe'),
      ),
    );
    await handoff.commit();
    expect(await handoff.finished.timeout(const Duration(seconds: 15)), 'rolledBack');
    expect(await File(p.join(destination.path, 'app.exe')).readAsString(), 'old');
    expect(await File(p.join(destination.path, 'user photos.txt')).readAsString(), 'personal');
    expect(await File(p.join(destination.path, 'new.dll')).exists(), isFalse);
  }, skip: !Platform.isWindows);

  test('Windows backup cleanup failure never rolls back a healthy new application', () async {
    final destination = await Directory(p.join(temp.path, 'installation')).create();
    final staged = await Directory(p.join(temp.path, 'staged')).create();
    for (final name in ['alpha.dll', 'beta.dll']) {
      await File(p.join(destination.path, name)).writeAsString('old');
      await File(p.join(staged.path, name)).writeAsString('new');
    }
    final work = await Directory(p.join(temp.path, '.pepoconnect-update-locked-backup')).create();
    final application = await File(p.join(temp.path, 'healthy.ps1')).writeAsString(r'''
param([string]$Work)
$stream = [IO.File]::Open((Join-Path $Work 'backup\beta.dll'), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
try {
    [IO.File]::WriteAllText($env:PEPOCONNECT_UPDATE_HEALTH, 'healthy')
    while (-not (Test-Path -LiteralPath (Join-Path $Work 'release-lock'))) { Start-Sleep -Milliseconds 100 }
} finally { $stream.Dispose() }
''');
    final handoff = await DesktopHandoff.prepare(
      DesktopUpdatePlan(
        work: work,
        destination: destination.path,
        staged: staged.path,
        isBundle: true,
        windows: true,
        parentPid: 0,
        healthTimeoutSeconds: 5,
        launchPath: r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe',
        launchArguments: [
          '-NoProfile',
          '-NonInteractive',
          '-File',
          application.path,
          '-Work',
          work.path,
        ],
      ),
    );
    try {
      await handoff.commit();
      expect(await handoff.finished.timeout(const Duration(seconds: 20)), 'installed');
      expect(await File(p.join(destination.path, 'alpha.dll')).readAsString(), 'new');
      expect(await File(p.join(destination.path, 'beta.dll')).readAsString(), 'new');
    } finally {
      await File(p.join(work.path, 'release-lock')).writeAsString('release');
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }, skip: !Platform.isWindows);

  test(
    'Windows atomic replacement keeps the current executable present when staging is locked',
    () async {
      final destination = await File(p.join(temp.path, 'installed.bin')).writeAsString('old');
      final staged = await File(p.join(temp.path, 'staged.bin')).writeAsString('new');
      final work = await Directory(p.join(temp.path, '.pepoconnect-update-atomic')).create();
      final lockScript = await File(p.join(temp.path, 'lock.ps1')).writeAsString(r'''
param([string]$Source, [string]$Work)
$stream = [IO.File]::Open($Source, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
try {
  [IO.File]::WriteAllText((Join-Path $Work 'locked'), 'locked')
  while (-not (Test-Path -LiteralPath (Join-Path $Work 'release'))) { Start-Sleep -Milliseconds 50 }
} finally { $stream.Dispose() }
''');
      final handoff = await DesktopHandoff.prepare(
        DesktopUpdatePlan(
          work: work,
          destination: destination.path,
          staged: staged.path,
          isBundle: false,
          windows: true,
          parentPid: 0,
          launchPath: p.join(temp.path, 'missing.exe'),
        ),
      );
      final locker = await Process.start('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-WindowStyle',
        'Hidden',
        '-File',
        lockScript.path,
        '-Source',
        staged.path,
        '-Work',
        work.path,
      ]);
      await locker.stdin.close();
      while (!await File(p.join(work.path, 'locked')).exists()) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      try {
        await handoff.commit();
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(await destination.exists(), isTrue);
        expect(await destination.readAsString(), 'old');
      } finally {
        await File(p.join(work.path, 'release')).writeAsString('release');
        await locker.exitCode.timeout(const Duration(seconds: 5));
        await handoff.finished.timeout(const Duration(seconds: 15));
      }
    },
    skip: !Platform.isWindows,
  );

  test('Windows rollback completes even when diagnostic logging fails', () async {
    final destination = await File(p.join(temp.path, 'installed.bin')).writeAsString('old');
    final staged = await File(p.join(temp.path, 'staged.bin')).writeAsString('new');
    final work = await Directory(p.join(temp.path, '.pepoconnect-update-log-failure')).create();
    await Directory(p.join(work.path, 'error.txt')).create();
    final handoff = await DesktopHandoff.prepare(
      DesktopUpdatePlan(
        work: work,
        destination: destination.path,
        staged: staged.path,
        isBundle: false,
        windows: true,
        parentPid: 0,
        launchPath: p.join(temp.path, 'missing.exe'),
      ),
    );
    await handoff.commit();
    expect(await handoff.finished.timeout(const Duration(seconds: 5)), 'rolledBack');
    expect(await destination.readAsString(), 'old');
  }, skip: !Platform.isWindows);

  test(
    'Windows restart preserves profile arguments with quotes and trailing backslashes',
    () async {
      final destination = await File(p.join(temp.path, 'installed.bin')).writeAsString('old');
      final staged = await File(p.join(temp.path, 'staged.bin')).writeAsString('new');
      final work = await Directory(p.join(temp.path, '.pepoconnect-update-arguments')).create();
      final script = await File(p.join(temp.path, 'check-arguments.ps1')).writeAsString(r'''
param([string]$Profile)
if ($Profile -cne 'C:\Profiles\work "quoted"\') { exit 12 }
[IO.File]::WriteAllText($env:PEPOCONNECT_UPDATE_HEALTH, 'healthy')
''');
      final handoff = await DesktopHandoff.prepare(
        DesktopUpdatePlan(
          work: work,
          destination: destination.path,
          staged: staged.path,
          isBundle: false,
          windows: true,
          parentPid: 0,
          healthTimeoutSeconds: 3,
          launchPath: r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe',
          launchArguments: [
            '-NoProfile',
            '-NonInteractive',
            '-File',
            script.path,
            '-Profile',
            'C:\\Profiles\\work "quoted"\\',
          ],
        ),
      );
      await handoff.commit();
      expect(await handoff.finished.timeout(const Duration(seconds: 10)), 'installed');
    },
    skip: !Platform.isWindows,
  );
}
