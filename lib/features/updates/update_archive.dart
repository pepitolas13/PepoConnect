import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

/// Extraction stays off the UI isolate. No archive-controlled links, parent
/// traversals, duplicate paths, device names or alternate streams are accepted.
Future<String> stageUpdateArchive(
  String file,
  String output, {
  required bool windows,
  int maxExpandedBytes = 2 * 1024 * 1024 * 1024,
  String? cancellationFile,
}) => Isolate.run(() => _extract(file, output, windows, maxExpandedBytes, cancellationFile));

String _extract(
  String file,
  String output,
  bool windows,
  int maxExpandedBytes,
  String? cancellationFile,
) {
  void checkCancelled() {
    if (cancellationFile != null && File(cancellationFile).existsSync()) {
      throw const FormatException('Update cancelled');
    }
  }

  checkCancelled();
  final destination = Directory(output)..createSync(recursive: true);
  InputFileStream? input;
  try {
    String archivePath = file;
    if (!windows) {
      archivePath = p.join(destination.parent.path, 'unpacked.tar');
      final gzipInput = InputFileStream(file);
      final tarOutput = _LimitedOutput(archivePath, maxExpandedBytes, checkCancelled);
      try {
        if (!const GZipDecoder().decodeStream(gzipInput, tarOutput, verify: true)) {
          throw const FormatException('Truncated compressed update');
        }
      } finally {
        gzipInput.closeSync();
        tarOutput.closeSync();
      }
    }
    input = InputFileStream(archivePath);
    final archive = windows
        ? ZipDecoder().decodeStream(input, verify: true)
        : TarDecoder().decodeStream(input, verify: true);
    if (archive.length > 20000) throw const FormatException('Too many update files');
    final seen = <String>{};
    var expanded = 0;
    String? tarRoot;
    // Validate every entry before writing the first package file.
    for (final entry in archive) {
      checkCancelled();
      final parts = entry.name.replaceAll('\\', '/').split('/');
      if (parts.last.isEmpty) parts.removeLast();
      if (parts.isEmpty ||
          entry.isSymbolicLink ||
          parts.any(
            (part) =>
                part.isEmpty ||
                part == '.' ||
                part == '..' ||
                part.contains(':') ||
                part.contains(RegExp(r'[\x00-\x1f]')) ||
                part.endsWith(' ') ||
                part.endsWith('.') ||
                RegExp(
                  r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$',
                  caseSensitive: false,
                ).hasMatch(part),
          )) {
        throw const FormatException('Unsafe update archive path');
      }
      if (!seen.add(parts.join('/').toLowerCase())) {
        throw const FormatException('Duplicate update archive path');
      }
      if (!windows) {
        tarRoot ??= parts.first;
        if (parts.first != tarRoot ||
            !RegExp(r'^PepoConnect-linux-(x64|arm64)$').hasMatch(tarRoot)) {
          throw const FormatException('Invalid Linux bundle layout');
        }
      }
      if (entry.isFile) expanded += entry.size;
      if (entry.size < 0 || expanded > maxExpandedBytes) {
        throw const FormatException('Expanded update exceeds limit');
      }
    }
    for (final entry in archive) {
      checkCancelled();
      final relative = entry.name.replaceAll('\\', '/');
      final path = p.joinAll([output, ...relative.split('/')]);
      if (entry.isDirectory) {
        Directory(path).createSync(recursive: true);
        continue;
      }
      File(path).parent.createSync(recursive: true);
      final sink = _LimitedOutput(path, entry.size, checkCancelled);
      try {
        entry.writeContent(sink);
        if (sink.length != entry.size) throw const FormatException('Truncated update entry');
      } finally {
        sink.closeSync();
      }
      if (!windows && Platform.isLinux) {
        final chmod = Process.runSync('/bin/chmod', [
          entry.unixPermissions & 0x49 != 0 ? '755' : '644',
          '--',
          path,
        ]);
        if (chmod.exitCode != 0) {
          throw FileSystemException('Cannot set update file permissions', path);
        }
      }
    }
    final root = windows ? output : p.join(output, tarRoot!);
    if (!File(p.join(root, windows ? 'pepoconnect.exe' : 'bundle/pepoconnect')).existsSync() ||
        !Directory(p.join(root, windows ? 'data/flutter_assets' : 'bundle/data/flutter_assets'))
            .existsSync() ||
        (!windows && !File(p.join(root, 'PepoConnect.sh')).existsSync())) {
      throw const FormatException('The update does not contain a complete application');
    }
    return root;
  } finally {
    input?.closeSync();
    if (!windows) {
      final tar = File(p.join(destination.parent.path, 'unpacked.tar'));
      if (tar.existsSync()) tar.deleteSync();
    }
  }
}

class _LimitedOutput extends OutputFileStream {
  _LimitedOutput(String file, this.limit, this.checkCancelled)
    : super.withFileHandle(FileHandle(file, mode: FileAccess.write));
  final int limit;
  final void Function() checkCancelled;
  @override
  void writeBytes(List<int> bytes, {int? length}) {
    checkCancelled();
    if (this.length + (length ?? bytes.length) > limit) {
      throw const FormatException('Expanded update exceeds limit');
    }
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeByte(int value) {
    checkCancelled();
    if (length + 1 > limit) throw const FormatException('Expanded update exceeds limit');
    super.writeByte(value);
  }
}
