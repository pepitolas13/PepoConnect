import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class DesktopUpdatePlan {
  const DesktopUpdatePlan({
    required this.work,
    required this.destination,
    required this.staged,
    required this.isBundle,
    required this.windows,
    required this.launchPath,
    this.launchArguments = const [],
    this.expectedExecutable,
    this.parentPid,
    this.healthTimeoutSeconds = 45,
  });
  final Directory work;
  final String destination;
  final String staged;
  final bool isBundle;
  final bool windows;
  final String launchPath;
  final List<String> launchArguments;
  final String? expectedExecutable;
  final int? parentPid;
  final int healthTimeoutSeconds;
}

/// Prepared helpers cannot write the installation until BOTH the commit marker
/// exists and the original process has exited. A failed shutdown writes abort.
class DesktopHandoff {
  DesktopHandoff._(this.work);
  final Directory work;

  static Future<DesktopHandoff> prepare(DesktopUpdatePlan plan) async {
    final work = plan.work.absolute;
    if (!p.basename(work.path).startsWith('.pepoconnect-update-')) {
      throw const FileSystemException('Invalid update work directory');
    }
    await work.create(recursive: true);
    final entries = <Map<String, String>>[];
    if (plan.isBundle) {
      final root = Directory(plan.staged).absolute.path;
      await for (final entity in Directory(root).list(recursive: true, followLinks: false)) {
        if (entity is Link) throw const FileSystemException('Update contains a symbolic link');
        if (entity is! File) continue;
        final relative = p.relative(entity.path, from: root);
        final target = p.join(plan.destination, relative);
        await _rejectLinks(target);
        entries.add({
          'source': entity.path,
          'target': target,
          'backup': p.join(work.path, 'backup', relative),
        });
      }
    } else {
      await _rejectLinks(plan.destination);
      entries.add({
        'source': plan.staged,
        'target': plan.destination,
        'backup': p.join(work.path, 'backup', 'previous'),
      });
    }
    if (entries.isEmpty) throw const FileSystemException('Empty update package');
    final config = {
      'work': work.path,
      'entries': entries,
      'parentPid': plan.parentPid ?? pid,
      'launchPath': plan.launchPath,
      'launchArguments': plan.launchArguments,
      'launchCommandLine': plan.launchArguments.map(_quoteWindowsArgument).join(' '),
      'expectedExecutable': plan.expectedExecutable ?? plan.launchPath,
      'healthTimeoutSeconds': plan.healthTimeoutSeconds,
    };
    final handoff = DesktopHandoff._(work);
    if (plan.windows) {
      final configFile = await File(p.join(work.path, 'plan.json'))
          .writeAsString(jsonEncode(config), flush: true);
      final script = await File(p.join(work.path, 'install.ps1'))
          .writeAsString(windowsUpdateScript, flush: true);
      final bootstrap = await File(p.join(work.path, 'start.ps1')).writeAsString(r'''
param([string]$Script, [string]$Config)
$ErrorActionPreference = 'Stop'
Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -WindowStyle Hidden -ArgumentList @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $Script + '"'), '-Config', ('"' + $Config + '"'))
''', flush: true);
      final started = await Process.run(
        'powershell.exe',
        [
          '-NoLogo',
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-WindowStyle',
          'Hidden',
          '-File',
          bootstrap.path,
          '-Script',
          script.path,
          '-Config',
          configFile.path,
        ],
        environment: desktopUpdateEnvironment(Platform.environment),
        includeParentEnvironment: false,
      ).timeout(const Duration(seconds: 15));
      if (started.exitCode != 0) {
        throw FileSystemException('Unable to start update helper: ${started.stderr}');
      }
    } else {
      final script = await File(p.join(work.path, 'install.sh'))
          .writeAsString(linuxUpdateScript(config), flush: true);
      await Process.start(
        '/bin/sh',
        [script.path],
        mode: ProcessStartMode.detached,
        environment: desktopUpdateEnvironment(Platform.environment),
        includeParentEnvironment: false,
      );
    }
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!await File(p.join(work.path, 'ready')).exists()) {
      if (DateTime.now().isAfter(deadline) || await File(p.join(work.path, 'result')).exists()) {
        await handoff.abort();
        final errors = File(p.join(work.path, 'launch-error.txt'));
        throw FileSystemException(
          'The update helper could not start: ${await errors.exists() ? await errors.readAsString() : ''}',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return handoff;
  }

  Future<void> commit() => File(p.join(work.path, 'commit')).writeAsString('commit', flush: true);
  Future<void> abort() => File(p.join(work.path, 'abort')).writeAsString('abort', flush: true);

  Future<String> get finished async {
    final file = File(p.join(work.path, 'result'));
    while (!await file.exists()) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return (await file.readAsString()).trim();
  }
}

Future<void> _rejectLinks(String target) async {
  var current = p.absolute(target);
  while (true) {
    if (await FileSystemEntity.type(current, followLinks: false) == FileSystemEntityType.link) {
      throw const FileSystemException('Installation path contains a symbolic link');
    }
    final parent = p.dirname(current);
    if (parent == current) break;
    current = parent;
  }
}

Map<String, String> desktopUpdateEnvironment(Map<String, String> inherited) {
  final result = Map<String, String>.of(inherited)..remove('PEPOCONNECT_UPDATE_HEALTH');
  if (inherited.containsKey('APPIMAGE') || inherited.containsKey('APPDIR')) {
    for (final key in ['APPIMAGE', 'APPDIR', 'ARGV0', 'OWD', 'LD_LIBRARY_PATH', 'LD_PRELOAD']) {
      result.remove(key);
    }
    final mounted = inherited['APPDIR'];
    if (mounted != null) {
      result['PATH'] = (result['PATH'] ?? '/usr/bin:/bin')
          .split(':')
          .where((entry) => entry != mounted && !entry.startsWith('$mounted/'))
          .join(':');
    }
  }
  return result;
}

const windowsUpdateScript = r'''
param([Parameter(Mandatory=$true)][string]$Config, [switch]$Recover)
$ErrorActionPreference = 'Stop'
$cfg = Get-Content -LiteralPath $Config -Raw -Encoding UTF8 | ConvertFrom-Json
$work = [IO.Path]::GetFullPath($cfg.work)
if (-not ([IO.Path]::GetFileName($work).StartsWith('.pepoconnect-update-'))) { exit 2 }
$abortPath = Join-Path $work 'abort'
$healthPath = Join-Path $work 'health'
$resultPath = Join-Path $work 'result'
$logPath = Join-Path $work 'error.txt'
$done = New-Object 'System.Collections.Generic.List[object]'
$spawned = $null
$restartAt = $null
$installationHealthy = $false
$original = if ($cfg.parentPid -gt 0) { Get-Process -Id $cfg.parentPid -ErrorAction SilentlyContinue } else { $null }
$originalStart = if ($original) { $original.StartTime } else { $null }
function Save-Result([string]$value) { [IO.File]::WriteAllText($resultPath, $value) }
function Move-Safely([string]$source, [string]$target) {
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        try { Move-Item -LiteralPath $source -Destination $target -ErrorAction Stop; return }
        catch { if ($attempt -eq 59) { throw }; Start-Sleep -Milliseconds 100 }
    }
}
function Replace-Safely([string]$source, [string]$target, $backup) {
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        try {
            if ($null -eq $backup) { [IO.File]::Replace($source, $target, [NullString]::Value, $true) }
            else { [IO.File]::Replace($source, $target, $backup, $true) }
            return
        }
        catch { if ($attempt -eq 59) { throw }; Start-Sleep -Milliseconds 100 }
    }
}
function Save-Journal {
    $path = Join-Path $work 'journal.json'
    $temporary = Join-Path $work 'journal.tmp'
    $bytes = [Text.Encoding]::UTF8.GetBytes((@{ records=$done.ToArray() } | ConvertTo-Json -Depth 5))
    $stream = [IO.File]::Open($temporary, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
    if (Test-Path -LiteralPath $path) { [IO.File]::Replace($temporary, $path, [NullString]::Value, $true) }
    else { [IO.File]::Move($temporary, $path) }
}
function Start-App {
    $env:PEPOCONNECT_UPDATE_HEALTH = $healthPath
    $options = @{ FilePath = $cfg.launchPath; WorkingDirectory = [IO.Path]::GetDirectoryName($cfg.launchPath); WindowStyle = 'Hidden'; PassThru = $true }
    if ($cfg.launchArguments.Count -gt 0) {
        $options.ArgumentList = $cfg.launchCommandLine
    }
    Start-Process @options
}
try {
    if ($Recover) {
        if ((Test-Path -LiteralPath $healthPath) -and ((Get-Content -LiteralPath $healthPath -Raw) -eq 'healthy')) { exit 0 }
        if ((Test-Path -LiteralPath $resultPath) -and ((Get-Content -LiteralPath $resultPath -Raw) -in @('installed', 'rolledBack'))) { exit 0 }
        $active = Get-Process -ErrorAction SilentlyContinue | Where-Object {
            try { $_.Path -eq $cfg.expectedExecutable -or $_.Path -eq $cfg.launchPath } catch { $false }
        }
        if ($active) { Save-Result 'recoveryRequired'; exit 2 }
        $journal = Get-Content -LiteralPath (Join-Path $work 'journal.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($record in $journal.records) { $done.Add($record) }
        throw 'Recovering the interrupted update from its journal'
    }
    foreach ($entry in $cfg.entries) {
        if (-not (Test-Path -LiteralPath $entry.source -PathType Leaf)) { throw 'The staged update is missing' }
        $backup = [IO.Path]::GetFullPath($entry.backup)
        if (-not $backup.StartsWith($work + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe backup path' }
    }
    [IO.File]::WriteAllText((Join-Path $work 'ready'), 'ready')
    $deadline = [DateTime]::UtcNow.AddSeconds(180)
    while ($true) {
        if (Test-Path -LiteralPath $abortPath) { Save-Result 'aborted'; exit 0 }
        if ([DateTime]::UtcNow -gt $deadline) { Save-Result 'aborted'; exit 0 }
        $running = if ($cfg.parentPid -gt 0) { Get-Process -Id $cfg.parentPid -ErrorAction SilentlyContinue } else { $null }
        $sameProcess = $running -and ($running.StartTime -eq $originalStart)
        if ((Test-Path -LiteralPath (Join-Path $work 'commit')) -and -not $sameProcess) { break }
        Start-Sleep -Milliseconds 100
    }
    if (Test-Path -LiteralPath $abortPath) { Save-Result 'aborted'; exit 0 }
    foreach ($entry in $cfg.entries) {
        $record = @{ source=$entry.source; target=$entry.target; backup=$entry.backup; existed=(Test-Path -LiteralPath $entry.target); backedUp=$false; written=$false }
        $done.Add($record)
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($entry.target)) | Out-Null
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($entry.backup)) | Out-Null
        Save-Journal
        if ($record.existed) {
            if (-not (Test-Path -LiteralPath $entry.target -PathType Leaf)) { throw 'An update file collides with a directory' }
            Replace-Safely $entry.source $entry.target $entry.backup
            $record.backedUp = $true
        } else {
            Move-Safely $entry.source $entry.target
        }
        $record.written = $true
        Save-Journal
    }
    $restartAt = Get-Date
    $spawned = Start-App
    $deadline = [DateTime]::UtcNow.AddSeconds($cfg.healthTimeoutSeconds)
    $healthy = $false
    while ([DateTime]::UtcNow -lt $deadline) {
        if ((Test-Path -LiteralPath $healthPath) -and ((Get-Content -LiteralPath $healthPath -Raw) -eq 'healthy')) { $healthy=$true; break }
        if ($spawned.HasExited -and $spawned.ExitCode -ne 0) { throw 'The updated application failed to start' }
        Start-Sleep -Milliseconds 200
        $spawned.Refresh()
    }
    if (-not $healthy) { throw 'The updated application did not confirm startup' }
    # This is the commit boundary. Cleanup must never undo a healthy installation:
    # earlier backups may already have been deleted when a later one is locked.
    $installationHealthy = $true
    foreach ($record in $done) {
        if ($record.backedUp) {
            try { Remove-Item -LiteralPath $record.backup -Force }
            catch { try { [IO.File]::AppendAllText($logPath, "`nBackup cleanup: " + $_.Exception.ToString()) } catch {} }
        }
    }
    Save-Result 'installed'
} catch {
    if ($installationHealthy) {
        try { Save-Result 'installed' } catch {}
        exit 0
    }
    try { [IO.File]::WriteAllText($logPath, $_.Exception.ToString()) } catch {}
    if ($restartAt) {
        # Only processes from this restart at the expected installed executable.
        Get-Process -ErrorAction SilentlyContinue | Where-Object {
            try { $_.Path -eq $cfg.expectedExecutable -and $_.StartTime -ge $restartAt } catch { $false }
        } | Stop-Process -Force -ErrorAction SilentlyContinue
        if ($spawned -and -not $spawned.HasExited) { Stop-Process -Id $spawned.Id -Force -ErrorAction SilentlyContinue }
    }
    $restored = $true
    for ($i=$done.Count-1; $i -ge 0; $i--) {
        $record=$done[$i]
        try {
            if (Test-Path -LiteralPath $record.backup -PathType Leaf) {
                if (Test-Path -LiteralPath $record.target -PathType Leaf) { Replace-Safely $record.backup $record.target $null }
                else { Move-Safely $record.backup $record.target }
            } elseif ($record.existed -and $record.written) {
                # A missing backup never authorizes deleting the only installed copy.
                $restored=$false
            } elseif (-not $record.existed -and ($record.written -or -not (Test-Path -LiteralPath $record.source))) {
                if (Test-Path -LiteralPath $record.target -PathType Leaf) { Remove-Item -LiteralPath $record.target -Force }
            }
        } catch { $restored=$false; try { [IO.File]::AppendAllText($logPath, "`nRollback: " + $_.Exception.ToString()) } catch {} }
    }
    if ($restored) {
        if ($done.Count -gt 0) { try { Remove-Item Env:PEPOCONNECT_UPDATE_HEALTH -ErrorAction SilentlyContinue; $cfg.healthTimeoutSeconds=0; Start-App | Out-Null } catch {} }
        Save-Result 'rolledBack'
    } else { Save-Result 'recoveryRequired' }
}
''';

String _sh(String value) => "'${value.replaceAll("'", "'\\''")}'";

// CRT parsing doubles backslashes only before an embedded or closing quote.
String _quoteWindowsArgument(String value) {
  final quoted = value
      .replaceAllMapped(RegExp(r'(\\*)"'), (match) => '${match[1]}${match[1]}\\"')
      .replaceFirstMapped(RegExp(r'(\\+)$'), (match) => '${match[1]}${match[1]}');
  return '"$quoted"';
}

String linuxUpdateScript(Map<String, Object?> config) {
  final work = config['work']! as String;
  final entries = config['entries']! as List<Map<String, String>>;
  final start =
      '${_sh(config['launchPath']! as String)} ${(config['launchArguments']! as List<String>).map(_sh).join(' ')}';
  final replacements = StringBuffer();
  final rollback = StringBuffer();
  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    final source = _sh(entry['source']!);
    final target = _sh(entry['target']!);
    final backup = _sh(entry['backup']!);
    replacements.writeln(
      'mkdir -p -- ${_sh(p.posix.dirname(entry['target']!))} ${_sh(p.posix.dirname(entry['backup']!))} || fail',
    );
    replacements.writeln('touch "\$work/started-$index" || fail');
    replacements.writeln(
      'if [ -e $target ]; then [ -f $target ] && [ ! -L $target ] || fail; touch "\$work/existed-$index" || fail; cp -p -- $target $backup || fail; touch "\$work/backed-$index" || fail; fi',
    );
    replacements.writeln('sync -f "\$work" || fail');
    replacements.writeln('mv -f -- $source $target || fail; touch "\$work/written-$index"');
    rollback.write(
      'if [ -f "\$work/backed-$index" ]; then\n  if [ -f $backup ]; then mv -f -- $backup $target || restored=0; else restored=0; fi\nelif [ -f "\$work/started-$index" ] && [ ! -f "\$work/existed-$index" ] && { [ -f "\$work/written-$index" ] || [ ! -f $source ]; }; then\n  rm -f -- $target || restored=0\nfi\n',
    );
  }
  return '''#!/bin/sh
umask 077
work=${_sh(work)}
parent=${config['parentPid']}
child=''
group=''
result="\$work/result"
exec </dev/null >>"\$work/helper.log" 2>&1
group_alive() {
  [ -n "\$group" ] || return 1
  kill -s 0 -- "-\$group" 2>/dev/null || return 1
  # A terminated zombie cannot use files or overlap the restored application.
  # Read only members of our owned session; /proc is required before handoff.
  for stat in /proc/[0-9]*/stat; do
    [ -r "\$stat" ] || continue
    IFS= read -r statline <"\$stat" || continue
    fields=\${statline##*) }
    set -- \$fields
    if [ "\${3-}" = "\$group" ] && [ "\${4-}" = "\$group" ] && [ "\${1-}" != Z ]; then return 0; fi
  done
  return 1
}
stop_new_instance() {
  [ -n "\$child" ] || return 0
  if [ -z "\$group" ]; then
    # A live setsid monitor without a session handshake is uncertain: retaining
    # the new files is safer than starting a second instance beside it.
    if kill -0 "\$child" 2>/dev/null; then return 1; fi
    return 0
  fi
  case "\$group" in ''|*[!0-9]*) return 1 ;; esac
  [ "\$group" -gt 1 ] && [ "\$group" != "\$\$" ] || return 1
  kill -s TERM -- "-\$group" 2>/dev/null || :
  remaining=20
  while group_alive && [ "\$remaining" -gt 0 ]; do sleep 0.1; remaining=\$((remaining - 1)); done
  if group_alive; then kill -s KILL -- "-\$group" 2>/dev/null || :; fi
  remaining=50
  while group_alive && [ "\$remaining" -gt 0 ]; do sleep 0.1; remaining=\$((remaining - 1)); done
  if group_alive; then return 1; fi
  wait "\$child" 2>/dev/null || :
  return 0
}
fail() {
  if ! stop_new_instance; then printf recoveryRequired >"\$result"; exit 1; fi
  restored=1
  ${rollback.toString()}
  if [ "\$restored" = 1 ]; then
    unset PEPOCONNECT_UPDATE_HEALTH
    $start >/dev/null 2>&1 &
    printf rolledBack >"\$result"
  else printf recoveryRequired >"\$result"; fi
  exit 1
}
if [ "\${1-}" = '--recover' ]; then
  if [ -f "\$work/health" ] && [ "\$(cat "\$work/health")" = healthy ]; then exit 0; fi
  case "\$(cat "\$result" 2>/dev/null)" in installed|rolledBack) exit 0 ;; esac
  fail
fi
if ! command -v setsid >/dev/null 2>&1 || [ ! -r /proc/self/stat ] || ! setsid --fork --wait /bin/sh -c 'exit 0'; then
  printf 'Session isolation is unavailable; the installation has not been changed.\n' >&2
  printf preparationFailed >"\$result"
  exit 1
fi
printf ready >"\$work/ready"
count=0
while :; do
  if [ -f "\$work/abort" ] || [ "\$count" -ge 180 ]; then printf aborted >"\$result"; exit 0; fi
  if [ -f "\$work/commit" ] && { [ "\$parent" = 0 ] || ! kill -0 "\$parent" 2>/dev/null; }; then break; fi
  sleep 1
  count=\$((count + 1))
done
[ ! -f "\$work/abort" ] || { printf aborted >"\$result"; exit 0; }
$replacements
PEPOCONNECT_UPDATE_HEALTH="\$work/health" setsid --fork --wait /bin/sh -c '
  work=\$1
  shift
  printf "%s\n" "\$\$" >"\$work/process-group" || exit 125
  exec "\$@"
' pepoconnect-update "\$work" $start >/dev/null 2>&1 &
child=\$!
remaining=50
while [ ! -s "\$work/process-group" ] && kill -0 "\$child" 2>/dev/null && [ "\$remaining" -gt 0 ]; do
  sleep 0.1
  remaining=\$((remaining - 1))
done
if [ -s "\$work/process-group" ]; then group=\$(cat "\$work/process-group"); else fail; fi
count=0
while [ "\$count" -lt ${config['healthTimeoutSeconds']} ]; do
  if [ -f "\$work/health" ] && [ "\$(cat "\$work/health")" = healthy ]; then
    ${entries.map((e) => 'rm -f -- ${_sh(e['backup']!)}').join('\n    ')}
    printf installed >"\$result"
    exit 0
  fi
  kill -0 "\$child" 2>/dev/null || fail
  sleep 1
  count=\$((count + 1))
done
fail
''';
}
