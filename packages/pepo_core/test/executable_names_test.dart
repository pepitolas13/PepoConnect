import 'package:pepo_core/src/transfer/executable_names.dart';
import 'package:test/test.dart';

void main() {
  test('programs are recognised by extension, whatever the case', () {
    for (final name in ['setup.exe', 'Setup.EXE', 'installer.msi', 'app.apk', 'run.bat', 'x.ps1']) {
      expect(ExecutableNames.isExecutable(name), isTrue, reason: name);
    }
  });

  test('double extensions and paths do not hide a program', () {
    expect(ExecutableNames.isExecutable('photo.jpg.exe'), isTrue);
    expect(ExecutableNames.isExecutable('tools/run.cmd'), isTrue);
    expect(ExecutableNames.isExecutable('setup.exe '), isTrue);
  });

  test('ordinary files pass', () {
    for (final name in ['photo.jpg', 'notes.txt', 'README', 'exe', 'archive.exe.zip', '.exe.txt']) {
      expect(ExecutableNames.isExecutable(name), isFalse, reason: name);
    }
  });
}
