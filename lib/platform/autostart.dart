import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:win32_registry/win32_registry.dart';

/// "Start with the system" on Windows (HKCU Run key) and Linux
/// (`~/.config/autostart`). The launcher path is re-written on every start
/// because a portable executable may be moved.
class Autostart {
  const Autostart._();

  static const _valueName = 'PepoConnect';
  static const _runKey = r'Software\Microsoft\Windows\CurrentVersion\Run';

  /// Executable to register: the portable launcher when we were started by
  /// it, otherwise the running binary.
  static String launcherPath() =>
      Platform.environment['PEPOCONNECT_LAUNCHER'] ?? Platform.resolvedExecutable;

  static bool get isSupported => Platform.isWindows || Platform.isLinux;

  static Future<bool> isEnabled() async {
    try {
      if (Platform.isWindows) {
        final key = RegistryKey.openCurrentUser(RegistryAccess.read).open(_runKey);
        try {
          return key.getString(_valueName) != null;
        } finally {
          key.close();
        }
      }
      if (Platform.isLinux) return await File(_linuxDesktopPath()).exists();
    } catch (_) {}
    return false;
  }

  static Future<void> setEnabled(bool enabled) async {
    try {
      if (Platform.isWindows) {
        final key = RegistryKey.openCurrentUser(RegistryAccess.readWrite)
            .open(_runKey, config: const RegistryOpenConfig(access: RegistryAccess.readWrite));
        try {
          if (enabled) {
            key.setValue(_valueName, RegistryValue.string('"${launcherPath()}" --minimized'));
          } else {
            try {
              key.removeValue(_valueName);
            } catch (_) {}
          }
        } finally {
          key.close();
        }
      } else if (Platform.isLinux) {
        final f = File(_linuxDesktopPath());
        if (enabled) {
          await f.parent.create(recursive: true);
          await f.writeAsString('''
[Desktop Entry]
Type=Application
Name=PepoConnect
Exec="${launcherPath()}" --minimized
Icon=org.pepoconnect.PepoConnect
Terminal=false
X-GNOME-Autostart-enabled=true
''');
        } else if (await f.exists()) {
          await f.delete();
        }
      }
    } catch (_) {
      // Not fatal: the setting simply does not stick.
    }
  }

  /// Re-registers the current path when autostart is on (portable moves).
  static Future<void> refresh() async {
    if (await isEnabled()) await setEnabled(true);
  }

  static String _linuxDesktopPath() {
    final home = Platform.environment['HOME'] ?? '.';
    final config = Platform.environment['XDG_CONFIG_HOME'] ?? p.join(home, '.config');
    return p.join(config, 'autostart', 'org.pepoconnect.PepoConnect.desktop');
  }
}
