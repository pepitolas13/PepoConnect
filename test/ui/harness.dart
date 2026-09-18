import 'package:flutter/material.dart';
import 'package:pepoconnect/app/theme.dart';
import 'package:pepoconnect/shared/i18n/l10n.dart';
import 'package:pepoconnect/shared/motion/motion_scope.dart';

/// Minimal app around a widget under test.
Widget harness({
  required Widget child,
  bool animations = true,
  bool dark = false,
  Locale locale = const Locale('es'),
}) {
  return MaterialApp(
    theme: dark ? buildDarkTheme() : buildLightTheme(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MotionScope(
      enabled: animations,
      child: Scaffold(body: Center(child: child)),
    ),
  );
}
