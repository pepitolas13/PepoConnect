import 'package:flutter/foundation.dart';

/// System font per platform. Nothing is bundled: the OS face is used.
abstract final class PlatformFonts {
  /// Family for body text, or null to keep the engine default (Roboto on
  /// Android, the platform default on the web).
  static String? family([TargetPlatform? platform]) {
    switch (platform ?? defaultTargetPlatform) {
      case TargetPlatform.windows:
        return 'Segoe UI Variable Text';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'CupertinoSystemText';
      case TargetPlatform.linux:
        return 'Cantarell';
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return null;
    }
  }

  /// Family for large titles (Windows uses the "Display" optical size).
  static String? displayFamily([TargetPlatform? platform]) {
    switch (platform ?? defaultTargetPlatform) {
      case TargetPlatform.windows:
        return 'Segoe UI Variable Display';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'CupertinoSystemDisplay';
      default:
        return family(platform);
    }
  }

  /// Fallback families tried when the primary face is missing.
  static List<String>? fallback([TargetPlatform? platform]) {
    switch (platform ?? defaultTargetPlatform) {
      case TargetPlatform.windows:
        return const ['Segoe UI Variable', 'Segoe UI', 'Segoe UI Emoji'];
      case TargetPlatform.linux:
        return const ['Adwaita Sans', 'Noto Sans', 'DejaVu Sans'];
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const ['.SF UI Text', 'Helvetica Neue'];
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return null;
    }
  }
}
