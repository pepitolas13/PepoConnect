import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../motion/fluent_page_transitions.dart';
import 'platform_fonts.dart';
import 'tokens.dart';

/// Builds the PepoFluent [ThemeData] (Material 3 underneath, Fluent on top).
abstract final class PepoTheme {
  /// Light theme. [transparentBackground] is set on Windows when Mica is
  /// active so the window backdrop shows through the scaffold.
  static ThemeData light({bool transparentBackground = false, TargetPlatform? platform}) =>
      _build(PepoColors.light, transparentBackground: transparentBackground, platform: platform);

  static ThemeData dark({bool transparentBackground = false, TargetPlatform? platform}) =>
      _build(PepoColors.dark, transparentBackground: transparentBackground, platform: platform);

  static PepoTypography typography(PepoColors c, {TargetPlatform? platform}) {
    final body = PlatformFonts.family(platform);
    final display = PlatformFonts.displayFamily(platform);
    final fallback = PlatformFonts.fallback(platform);
    TextStyle s(
      double size,
      double height, {
      FontWeight weight = FontWeight.w400,
      String? family,
      Color? color,
    }) => TextStyle(
      fontSize: size,
      height: height / size,
      fontWeight: weight,
      fontFamily: family ?? body,
      fontFamilyFallback: fallback,
      color: color ?? c.textPrimary,
      leadingDistribution: TextLeadingDistribution.even,
    );
    return PepoTypography(
      caption: s(12, 16, color: c.textSecondary),
      body: s(14, 20),
      bodyStrong: s(14, 20, weight: FontWeight.w600),
      bodyLarge: s(18, 24),
      subtitle: s(20, 28, weight: FontWeight.w600, family: display),
      title: s(28, 36, weight: FontWeight.w600, family: display),
      titleLarge: s(40, 52, weight: FontWeight.w600, family: display),
      railLabel: s(11, 14),
    );
  }

  static ThemeData _build(
    PepoColors c, {
    required bool transparentBackground,
    TargetPlatform? platform,
  }) {
    final t = typography(c, platform: platform);
    final scheme = ColorScheme(
      brightness: c.brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.accent,
      onSecondary: c.onAccent,
      error: c.critical,
      onError: c.isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      surface: c.isDark ? const Color(0xFF272727) : const Color(0xFFFFFFFF),
      onSurface: c.textPrimary,
      surfaceContainerHighest: c.isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF9F9F9),
      onSurfaceVariant: c.textSecondary,
      outline: c.controlStroke,
      outlineVariant: c.divider,
    );
    final textTheme = TextTheme(
      displayLarge: t.titleLarge,
      displayMedium: t.titleLarge,
      displaySmall: t.title,
      headlineLarge: t.titleLarge,
      headlineMedium: t.title,
      headlineSmall: t.subtitle,
      titleLarge: t.title,
      titleMedium: t.subtitle,
      titleSmall: t.bodyStrong,
      bodyLarge: t.bodyLarge,
      bodyMedium: t.body,
      bodySmall: t.caption,
      labelLarge: t.bodyStrong,
      labelMedium: t.caption.copyWith(fontWeight: FontWeight.w600, color: c.textPrimary),
      labelSmall: t.railLabel,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: scheme,
      platform: platform,
      fontFamily: PlatformFonts.family(platform),
      fontFamilyFallback: PlatformFonts.fallback(platform),
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      scaffoldBackgroundColor: transparentBackground ? Colors.transparent : c.bgBase,
      canvasColor: c.bgBase,
      dividerColor: c.divider,
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: c.textPrimary, size: Sizes.iconMedium),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: FluentPageTransitionsBuilder(),
          TargetPlatform.linux: FluentPageTransitionsBuilder(),
          TargetPlatform.macOS: FluentPageTransitionsBuilder(),
          TargetPlatform.android: FluentPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FluentPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accent.withValues(alpha: 0.35),
        selectionHandleColor: c.accent,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.hovered) ? 6.0 : 2.0,
        ),
        radius: const Radius.circular(3),
        thumbColor: WidgetStateProperty.all(c.textTertiary),
        crossAxisMargin: 2,
        mainAxisMargin: 4,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 600),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: c.flyoutSurface,
          borderRadius: Radii.controlRadius,
          border: Border.all(color: c.cardStroke),
          boxShadow: PepoShadows.toast,
        ),
        textStyle: t.caption.copyWith(color: c.textPrimary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.dialogSurface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.cardRadius),
        titleTextStyle: t.subtitle,
        contentTextStyle: t.body,
      ),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.cardRadius,
          side: BorderSide(color: c.cardStroke),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.flyoutSurface,
        contentTextStyle: t.body,
        shape: const RoundedRectangleBorder(borderRadius: Radii.cardRadius),
        behavior: SnackBarBehavior.floating,
      ),
      extensions: [c, t],
    );
    return base;
  }
}
