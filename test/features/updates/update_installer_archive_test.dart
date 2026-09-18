import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pepoconnect/features/updates/update_archive.dart';

void main() {
  late Directory temp;
  setUp(() async => temp = await Directory.systemTemp.createTemp('pepo-archive-test-'));
  tearDown(() async => temp.delete(recursive: true));

  test('extracts a verified portable archive to staging', () async {
    final archive = Archive()
      ..add(ArchiveFile.string('pepoconnect.exe', 'application'))
      ..add(ArchiveFile.string('data/flutter_assets/AssetManifest.bin', 'assets'));
    final file = await File(p.join(temp.path, 'bundle.zip'))
        .writeAsBytes(ZipEncoder().encode(archive));
    final result = await stageUpdateArchive(file.path, p.join(temp.path, 'staged'), windows: true);
    expect(await File(p.join(result, 'pepoconnect.exe')).readAsString(), 'application');
  });

  test('rejects traversal and ambiguous archive entries before extraction', () async {
    for (final path in [
      '../escape.txt',
      '/absolute',
      r'C:\evil',
      'data/../../evil',
      'file:stream',
      'CON',
    ]) {
      final archive = Archive()..add(ArchiveFile.string(path, 'bad'));
      final file = await File(p.join(temp.path, 'bad.zip'))
          .writeAsBytes(ZipEncoder().encode(archive));
      await expectLater(
        stageUpdateArchive(file.path, p.join(temp.path, 'staged'), windows: true),
        throwsFormatException,
      );
    }
    expect(await File(p.join(temp.path, 'escape.txt')).exists(), isFalse);
  });

  test('rejects missing executable and excessive expanded content', () async {
    final archive = Archive()..add(ArchiveFile.string('other.txt', 'x' * 200));
    final file = await File(p.join(temp.path, 'bad.zip'))
        .writeAsBytes(ZipEncoder().encode(archive));
    await expectLater(
      stageUpdateArchive(
        file.path,
        p.join(temp.path, 'size'),
        windows: true,
        maxExpandedBytes: 100,
      ),
      throwsFormatException,
    );
    await expectLater(
      stageUpdateArchive(file.path, p.join(temp.path, 'missing'), windows: true),
      throwsFormatException,
    );
  });
}
