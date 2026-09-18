import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pepo_core/src/protocol/models.dart';
import 'package:pepo_core/src/transfer/folder_layout.dart';
import 'package:pepo_core/src/transfer/name_sanitizer.dart';
import 'package:test/test.dart';

void main() {
  test('sanitize strips paths, control chars and reserved names', () {
    expect(NameSanitizer.sanitize('../../etc/passwd'), 'passwd');
    expect(NameSanitizer.sanitize(r'C:\Users\x\foto.jpg'), 'foto.jpg');
    expect(NameSanitizer.sanitize('a<b>c:d"e|f?g*h.txt'), 'a_b_c_d_e_f_g_h.txt');
    expect(NameSanitizer.sanitize('CON.txt'), '_CON.txt');
    expect(NameSanitizer.sanitize('lpt1'), '_lpt1');
    expect(NameSanitizer.sanitize('trailing. '), 'trailing');
    expect(NameSanitizer.sanitize('...'), 'archivo');
    expect(NameSanitizer.sanitize(''), 'archivo');
    expect(NameSanitizer.sanitize('  ñandú 🦙.JPG '), 'ñandú 🦙.JPG');
    final long = '${'x' * 300}.jpeg';
    final s = NameSanitizer.sanitize(long);
    expect(s.length, lessThanOrEqualTo(200));
    expect(s, endsWith('.jpeg'));
  });

  test('uniquePath appends counters', () async {
    final dir = await Directory.systemTemp.createTemp('pepo_names_');
    addTearDown(() => dir.delete(recursive: true));
    expect(NameSanitizer.uniquePath(dir.path, 'a.txt'), p.join(dir.path, 'a.txt'));
    File(p.join(dir.path, 'a.txt')).writeAsStringSync('1');
    expect(NameSanitizer.uniquePath(dir.path, 'a.txt'), p.join(dir.path, 'a (2).txt'));
    File(p.join(dir.path, 'a (2).txt')).writeAsStringSync('2');
    expect(NameSanitizer.uniquePath(dir.path, 'a.txt'), p.join(dir.path, 'a (3).txt'));
    final taken = {p.join(dir.path, 'b')};
    expect(NameSanitizer.uniquePath(dir.path, 'b', taken: taken), p.join(dir.path, 'b (2)'));
  });

  test('folder layout separates or unifies devices', () {
    const separate = FolderLayout(root: '/root');
    expect(separate.directoryFor(deviceFolder: 'Pixel 8', kind: MediaKind.image),
        p.join('/root', 'Pixel 8', 'Fotos'));
    expect(separate.directoryFor(deviceFolder: 'Pixel 8', kind: MediaKind.video),
        p.join('/root', 'Pixel 8', 'Vídeos'));
    expect(separate.directoryFor(deviceFolder: 'Pixel 8'), p.join('/root', 'Pixel 8', 'Archivos'));
    final unified = separate.copyWith(separateByDevice: false);
    expect(unified.directoryFor(deviceFolder: 'Pixel 8', kind: MediaKind.image),
        p.join('/root', 'Fotos'));
    expect(FolderLayout.folderNameFor('Pixel 8', ['Pixel 8']), 'Pixel 8-2');
    expect(FolderLayout.folderNameFor('Pixel 8', ['Pixel 8', 'Pixel 8-2']), 'Pixel 8-3');
    expect(FolderLayout.folderNameFor('a/b:c', []), 'b_c');
  });
}
