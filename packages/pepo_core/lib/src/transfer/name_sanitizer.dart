import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Makes remote file names safe for every supported file system.
class NameSanitizer {
  const NameSanitizer._();

  static const _reserved = {
    'CON',
    'PRN',
    'AUX',
    'NUL',
    'COM1',
    'COM2',
    'COM3',
    'COM4',
    'COM5',
    'COM6',
    'COM7',
    'COM8',
    'COM9',
    'LPT1',
    'LPT2',
    'LPT3',
    'LPT4',
    'LPT5',
    'LPT6',
    'LPT7',
    'LPT8',
    'LPT9',
  };

  static const maxBytes = 200;

  /// Returns a safe base name (never a path). Empty or degenerate input
  /// becomes `archivo`.
  static String sanitize(String name, {String fallback = 'archivo'}) {
    var n = name.replaceAll('\\', '/');
    n = n.substring(n.lastIndexOf('/') + 1);
    n = n.replaceAll(RegExp(r'[\x00-\x1F\x7F<>:"|?*]'), '_');
    n = n.trim();
    // Trailing dots/spaces are illegal on Windows.
    n = n.replaceAll(RegExp(r'[. ]+$'), '');
    n = n.replaceAll(RegExp(r'^\.+'), '');
    if (n.isEmpty) return fallback;
    final stem = p.basenameWithoutExtension(n).toUpperCase();
    if (_reserved.contains(stem)) n = '_$n';
    if (utf8.encode(n).length > maxBytes) {
      final ext = p.extension(n);
      var base = p.basenameWithoutExtension(n);
      while (utf8.encode(base + ext).length > maxBytes && base.isNotEmpty) {
        base = base.substring(0, base.length - 1);
      }
      n = base.isEmpty ? fallback + ext : base + ext;
    }
    return n;
  }

  /// A path inside [directory] that does not exist yet: `name.ext`,
  /// `name (2).ext`, `name (3).ext`, ... [taken] lets callers reserve names
  /// that are about to be created.
  static String uniquePath(String directory, String name, {Set<String>? taken}) {
    final safe = sanitize(name);
    final ext = p.extension(safe);
    final base = p.basenameWithoutExtension(safe);
    var candidate = p.join(directory, safe);
    var i = 2;
    while (_exists(candidate, taken)) {
      candidate = p.join(directory, '$base ($i)$ext');
      i++;
    }
    return candidate;
  }

  static bool _exists(String path, Set<String>? taken) =>
      (taken?.contains(path) ?? false) ||
      FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;
}
