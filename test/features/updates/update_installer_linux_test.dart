import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pepoconnect/features/updates/update_desktop.dart';

void main() {
  final shells = Platform.isWindows
      ? [r'C:\Program Files\Git\bin\bash.exe', r'C:\Program Files\Git\usr\bin\dash.exe']
      : ['/bin/sh'];
  for (final shell in shells) {
    group(p.basename(shell), () => _helperTests(shell));
  }
}

void _helperTests(String shell) {
  String shellPath(String path) => Platform.isWindows
      ? '/${path.substring(0, 1).toLowerCase()}${path.substring(2).replaceAll('\\', '/')}'
      : path;
  late Directory temp;
  late String shellSearchPath;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pepo-linux-helper-');
    shellSearchPath = '/usr/bin:/bin';
    if (Platform.isWindows && File(shell).existsSync()) {
      // Git Bash lacks util-linux setsid. Perl uses the same real MSYS POSIX
      // session/group operations, including a waiting parent as setsid -f -w.
      final bin = await Directory(p.join(temp.path, 'bin')).create();
      final setsid = await File(p.join(bin.path, 'setsid')).writeAsString(r'''#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(setsid);
die 'unexpected setsid arguments' unless shift(@ARGV) eq '--fork' && shift(@ARGV) eq '--wait';
my $pid = fork();
die 'fork failed' unless defined $pid;
if ($pid) { waitpid($pid, 0); exit(($? & 127) ? 128 + ($? & 127) : $? >> 8); }
setsid() >= 0 or die 'setsid failed';
exec @ARGV or die 'exec failed';
''');
      await Process.run(shell, ['-c', r'chmod +x -- "$1"', 'test', shellPath(setsid.path)]);
      shellSearchPath = '${shellPath(bin.path)}:$shellSearchPath';
    }
  });
  tearDown(() async => temp.delete(recursive: true));

  test('helper environment discards the previous mounted AppImage and health marker', () {
    final environment = desktopUpdateEnvironment({
      'APPIMAGE': '/home/app.AppImage',
      'APPDIR': '/tmp/.mount_old',
      'LD_LIBRARY_PATH': '/tmp/.mount_old/lib',
      'LD_PRELOAD': '/tmp/.mount_old/inject.so',
      'PEPOCONNECT_UPDATE_HEALTH': '/old/health',
      'DISPLAY': ':0',
      'HOME': '/home/dan',
    });
    for (final key in [
      'APPIMAGE',
      'APPDIR',
      'LD_LIBRARY_PATH',
      'LD_PRELOAD',
      'PEPOCONNECT_UPDATE_HEALTH',
    ]) {
      expect(environment.containsKey(key), isFalse);
    }
    expect(environment['DISPLAY'], ':0');
    expect(environment['HOME'], '/home/dan');
  });

  for (final success in [true, false]) {
    test(
      'Linux helper ${success ? 'replaces and restarts' : 'rolls back a failed restart'} with safely quoted paths',
      () async {
        final work = await Directory(p.join(temp.path, ".pepoconnect-update-user's files"))
            .create();
        final target = await File(p.join(temp.path, "user's app.bin")).writeAsString('old');
        final staged = await File(p.join(temp.path, 'new.bin')).writeAsString('new');
        final untouched = await File(p.join(temp.path, 'personal.txt')).writeAsString('keep');
        final script = await File(p.join(work.path, 'install.sh')).writeAsString(
          linuxUpdateScript({
            'work': shellPath(work.path),
            'parentPid': 0,
            'entries': [
              {
                'source': shellPath(staged.path),
                'target': shellPath(target.path),
                'backup': '${shellPath(work.path)}/backup/previous',
              },
            ],
            'launchPath': '/usr/bin/sh',
            'launchArguments': [
              '-c',
              success ? r'printf healthy > "$PEPOCONNECT_UPDATE_HEALTH"; sleep 1' : 'exit 2',
            ],
            'healthTimeoutSeconds': 3,
          }),
        );
        await File(p.join(work.path, 'commit')).writeAsString('commit');
        final result = await Process.run(
          shell,
          [shellPath(script.path)],
          environment: {'PATH': shellSearchPath},
        ).timeout(const Duration(seconds: 15));
        expect(result.exitCode, success ? 0 : 1, reason: '${result.stderr}');
        expect(
          await File(p.join(work.path, 'result')).readAsString(),
          success ? 'installed' : 'rolledBack',
        );
        expect(await target.readAsString(), success ? 'new' : 'old');
        expect(await untouched.readAsString(), 'keep');
      },
      skip: !File(shell).existsSync(),
    );
  }

  test(
    'Linux rollback stops a forked AppImage runner before restarting the previous version',
    () async {
      final work = await Directory(p.join(temp.path, '.pepoconnect-update-forked-runner')).create();
      final installed = await File(p.join(temp.path, 'app.AppImage')).writeAsString(r'''#!/bin/sh
work="$1"
if [ -f "$work/payload.pid" ]; then
  payload=$(cat "$work/payload.pid")
  if kill -0 "$payload" 2>/dev/null; then printf overlap >"$work/overlap"; fi
fi
printf restarted >"$work/old-restarted"
''');
      await File(p.join(work.path, 'payload.sh')).writeAsString(r'''#!/bin/sh
trap '' TERM
printf '%s' "$$" >"$1/payload.pid"
exec /usr/bin/sleep 30
''');
      final staged = await File(p.join(temp.path, 'new.AppImage')).writeAsString(r'''#!/bin/sh
/usr/bin/sh "$1/payload.sh" "$1" &
wait "$!"
''');
      final script = await File(p.join(work.path, 'install.sh')).writeAsString(
        linuxUpdateScript({
          'work': shellPath(work.path),
          'parentPid': 0,
          'entries': [
            {
              'source': shellPath(staged.path),
              'target': shellPath(installed.path),
              'backup': '${shellPath(work.path)}/backup/previous',
            },
          ],
          'launchPath': '/usr/bin/sh',
          'launchArguments': [shellPath(installed.path), shellPath(work.path)],
          'healthTimeoutSeconds': 2,
        }),
      );
      await File(p.join(work.path, 'commit')).writeAsString('commit');
      try {
        await Process.run(
          shell,
          [shellPath(script.path)],
          environment: {'PATH': shellSearchPath, 'APPIMAGE_EXTRACT_AND_RUN': '1'},
        ).timeout(const Duration(seconds: 20));
        expect(await File(p.join(work.path, 'result')).readAsString(), 'rolledBack');
        for (var i = 0; i < 30 && !await File(p.join(work.path, 'old-restarted')).exists(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(await File(p.join(work.path, 'old-restarted')).exists(), isTrue);
        expect(
          await File(p.join(work.path, 'overlap')).exists(),
          isFalse,
          reason: 'The failed new runner must stop before the restored version is started',
        );
      } finally {
        // The red regression intentionally leaves its own fixture runner behind.
        await Process.run(
          shell,
          [
            '-c',
            r'if [ -f "$1/payload.pid" ]; then kill -9 "$(cat "$1/payload.pid")" 2>/dev/null || :; fi',
            'test',
            shellPath(work.path),
          ],
          environment: {'PATH': shellSearchPath},
        );
      }
    },
    skip: !File(shell).existsSync(),
  );

  test(
    'Linux helper refuses unsupported session isolation before changing installed files',
    () async {
      final work = await Directory(p.join(temp.path, '.pepoconnect-update-no-sessions')).create();
      final target = await File(p.join(temp.path, 'installed')).writeAsString('old');
      final staged = await File(p.join(temp.path, 'staged')).writeAsString('new');
      final bin = await Directory(p.join(temp.path, 'unsupported-bin')).create();
      final unsupported = await File(p.join(bin.path, 'setsid'))
          .writeAsString('#!/bin/sh\nexit 1\n');
      await Process.run(shell, ['-c', r'chmod +x -- "$1"', 'test', shellPath(unsupported.path)]);
      final script = await File(p.join(work.path, 'install.sh')).writeAsString(
        linuxUpdateScript({
          'work': shellPath(work.path),
          'parentPid': 0,
          'entries': [
            {
              'source': shellPath(staged.path),
              'target': shellPath(target.path),
              'backup': '${shellPath(work.path)}/backup/previous',
            },
          ],
          'launchPath': '/usr/bin/sh',
          'launchArguments': ['-c', 'exit 0'],
          'healthTimeoutSeconds': 1,
        }),
      );
      await File(p.join(work.path, 'commit')).writeAsString('commit');
      final result = await Process.run(
        shell,
        [shellPath(script.path)],
        environment: {'PATH': '${shellPath(bin.path)}:$shellSearchPath'},
      ).timeout(const Duration(seconds: 5));
      expect(result.exitCode, 1);
      expect(await File(p.join(work.path, 'result')).readAsString(), 'preparationFailed');
      expect(await File(p.join(work.path, 'ready')).exists(), isFalse);
      expect(await target.readAsString(), 'old');
      expect(await staged.readAsString(), 'new');
    },
    skip: !File(shell).existsSync(),
  );
}
