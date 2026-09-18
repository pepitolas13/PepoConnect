import 'package:flutter/material.dart';

import '../shared/theme/pepo_theme.dart';
import '../state/app_settings.dart';

/// Light theme. Pass `transparentBackground: windowEffectsActive.value` on
/// Windows so Mica shows through.
ThemeData buildLightTheme({bool transparentBackground = false}) =>
    PepoTheme.light(transparentBackground: transparentBackground);

ThemeData buildDarkTheme({bool transparentBackground = false}) =>
    PepoTheme.dark(transparentBackground: transparentBackground);

/// `AppThemeMode` → `ThemeMode` for `MaterialApp.themeMode`.
ThemeMode themeModeOf(AppThemeMode mode) => switch (mode) {
  AppThemeMode.system => ThemeMode.system,
  AppThemeMode.light => ThemeMode.light,
  AppThemeMode.dark => ThemeMode.dark,
};

/// Whether the effective brightness is dark (for Mica and the tray icon).
bool isDarkFor(AppThemeMode mode, Brightness platformBrightness) => switch (mode) {
  AppThemeMode.system => platformBrightness == Brightness.dark,
  AppThemeMode.light => false,
  AppThemeMode.dark => true,
};
