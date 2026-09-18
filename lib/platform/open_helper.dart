import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

/// Opens files and folders with the system's default handlers.
class OpenHelper {
  const OpenHelper._();

  /// Opens a file with its default application.
  static Future<bool> openFile(String path) async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        return await launchUrl(Uri.file(path));
      }
      final r = await OpenFilex.open(path);
      return r.type == ResultType.done;
    } catch (_) {
      return false;
    }
  }

  /// Opens a folder in the file manager.
  static Future<bool> openFolder(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.start('explorer.exe', [path], runInShell: false);
        return true;
      }
      if (Platform.isLinux) {
        await Process.start('xdg-open', [path]);
        return true;
      }
      return await launchUrl(Uri.directory(path));
    } catch (_) {
      return false;
    }
  }

  /// Opens the folder containing [path] with the file selected when possible.
  static Future<bool> showInFolder(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.start('explorer.exe', ['/select,', path], runInShell: false);
        return true;
      }
      if (Platform.isLinux) {
        // Try the freedesktop FileManager1 interface; fall back to the folder.
        final r = await Process.run('dbus-send', [
          '--session',
          '--dest=org.freedesktop.FileManager1',
          '--type=method_call',
          '/org/freedesktop/FileManager1',
          'org.freedesktop.FileManager1.ShowItems',
          'array:string:${Uri.file(path)}',
          'string:',
        ]);
        if (r.exitCode == 0) return true;
        return await openFolder(p.dirname(path));
      }
      return await openFolder(p.dirname(path));
    } catch (_) {
      return openFolder(p.dirname(path));
    }
  }

  static Future<bool> openUrl(String url) async {
    try {
      return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
