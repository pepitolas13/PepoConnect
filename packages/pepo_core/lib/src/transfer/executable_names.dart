/// Files that run as a program when opened (`.exe`, `.msi`, `.apk`...).
///
/// Off by default on both ends: the sender refuses to queue them and the
/// receiver rejects the offer, each unless its own "allow executables"
/// setting is on. Both devices have to opt in for one to go through.
abstract final class ExecutableNames {
  static const Set<String> extensions = {
    '.exe',
    '.msi',
    '.msix',
    '.appx',
    '.bat',
    '.cmd',
    '.com',
    '.scr',
    '.pif',
    '.ps1',
    '.vbs',
    '.vbe',
    '.js',
    '.jse',
    '.wsf',
    '.hta',
    '.jar',
    '.apk',
  };

  /// `Setup.EXE`, `photo.jpg.exe`, `tools/run.bat` are executables;
  /// `notes.txt`, `README` are not.
  static bool isExecutable(String name) {
    final lower = name.trim().toLowerCase();
    final dot = lower.lastIndexOf('.');
    if (dot < 0) return false;
    return extensions.contains(lower.substring(dot));
  }
}

/// Thrown by the sender when an executable is queued while the setting is off.
class ExecutableBlockedException implements Exception {
  const ExecutableBlockedException(this.name);

  final String name;

  @override
  String toString() => 'executables are not allowed: $name';
}
