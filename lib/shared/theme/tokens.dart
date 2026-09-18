import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Spacing scale (4 px grid).
abstract final class Space {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii.
abstract final class Radii {
  /// Controls and thumbnails.
  static const double control = 4;

  /// Cards, flyouts, dialogs and toasts.
  static const double card = 8;

  /// Drop zones.
  static const double dropZone = 12;

  static const BorderRadius controlRadius = BorderRadius.all(Radius.circular(control));
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(card));
  static const BorderRadius dropZoneRadius = BorderRadius.all(Radius.circular(dropZone));
}

/// Fixed control sizes (Windows 11 density).
abstract final class Sizes {
  static const double buttonHeight = 32;
  static const double buttonPaddingX = 12;
  static const double buttonIcon = 16;
  static const double toggleWidth = 40;
  static const double toggleHeight = 20;
  static const double settingsRow = 68;
  static const double railWidth = 64;
  static const double railIcon = 20;
  static const double activityPanelWidth = 320;
  static const double toastWidth = 360;
  static const double progressBar = 4;
  static const double iconSmall = 16;
  static const double iconMedium = 20;
  static const double iconLarge = 24;
  static const double iconEmpty = 48;
}

/// Shadows are only used on floating surfaces.
abstract final class PepoShadows {
  static const List<BoxShadow> flyout = [
    BoxShadow(color: Color(0x24000000), offset: Offset(0, 8), blurRadius: 16),
  ];
  static const List<BoxShadow> dialog = [
    BoxShadow(color: Color(0x30000000), offset: Offset(0, 32), blurRadius: 64),
  ];
  static const List<BoxShadow> toast = [
    BoxShadow(color: Color(0x1F000000), offset: Offset(0, 4), blurRadius: 8),
  ];
}

/// PepoFluent colour tokens. One accent, no gradients.
@immutable
class PepoColors extends ThemeExtension<PepoColors> {
  const PepoColors({
    required this.brightness,
    required this.bgBase,
    required this.bgLayer,
    required this.bgLayerAlt,
    required this.card,
    required this.cardStroke,
    required this.divider,
    required this.controlFill,
    required this.controlHover,
    required this.controlPressed,
    required this.controlStroke,
    required this.subtleHover,
    required this.subtlePressed,
    required this.pressedOverlay,
    required this.hoverLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.accent,
    required this.accentHover,
    required this.accentPressed,
    required this.onAccent,
    required this.success,
    required this.caution,
    required this.critical,
    required this.dropBorder,
    required this.dropFill,
    required this.dropFillActive,
    required this.viewerBackdrop,
    required this.focusOuter,
    required this.focusInner,
  });

  final Brightness brightness;

  /// Window background (Mica shows through on Windows).
  final Color bgBase;

  /// Content layer over [bgBase] (WinUI "layer" fill).
  final Color bgLayer;

  /// Solid layer used for flyouts, dialogs and toasts.
  final Color bgLayerAlt;
  final Color card;
  final Color cardStroke;
  final Color divider;
  final Color controlFill;
  final Color controlHover;
  final Color controlPressed;
  final Color controlStroke;
  final Color subtleHover;
  final Color subtlePressed;

  /// Overlay painted while a [Pressable] is held down.
  final Color pressedOverlay;

  /// Radial light that follows the pointer over tiles.
  final Color hoverLight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color accent;
  final Color accentHover;
  final Color accentPressed;
  final Color onAccent;
  final Color success;
  final Color caution;
  final Color critical;
  final Color dropBorder;
  final Color dropFill;
  final Color dropFillActive;
  final Color viewerBackdrop;
  final Color focusOuter;
  final Color focusInner;

  bool get isDark => brightness == Brightness.dark;

  static const PepoColors light = PepoColors(
    brightness: Brightness.light,
    bgBase: Color(0xFFF3F3F3),
    bgLayer: Color(0x80FFFFFF),
    bgLayerAlt: Color(0xFFFFFFFF),
    card: Color(0xB3FFFFFF),
    cardStroke: Color(0x0F000000),
    divider: Color(0x14000000),
    controlFill: Color(0xB3FFFFFF),
    controlHover: Color(0x80F9F9F9),
    controlPressed: Color(0x4DF9F9F9),
    controlStroke: Color(0x0F000000),
    subtleHover: Color(0x09000000),
    subtlePressed: Color(0x06000000),
    pressedOverlay: Color(0x0F000000),
    hoverLight: Color(0x14FFFFFF),
    textPrimary: Color(0xE4000000),
    textSecondary: Color(0x9E000000),
    textTertiary: Color(0x72000000),
    textDisabled: Color(0x5C000000),
    accent: Color(0xFF005FB8),
    accentHover: Color(0xE6005FB8),
    accentPressed: Color(0xCC005FB8),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF0F7B0F),
    caution: Color(0xFF9D5D00),
    critical: Color(0xFFC42B1C),
    dropBorder: Color(0xFF7FB8E6),
    dropFill: Color(0xFFEAF3FC),
    dropFillActive: Color(0xFFD9EAF9),
    viewerBackdrop: Color(0xF50B0B0B),
    focusOuter: Color(0xE4000000),
    focusInner: Color(0xFFFFFFFF),
  );

  static const PepoColors dark = PepoColors(
    brightness: Brightness.dark,
    bgBase: Color(0xFF202020),
    bgLayer: Color(0x4D3A3A3A),
    bgLayerAlt: Color(0x09FFFFFF),
    card: Color(0x0DFFFFFF),
    cardStroke: Color(0x19000000),
    divider: Color(0x14FFFFFF),
    controlFill: Color(0x0FFFFFFF),
    controlHover: Color(0x15FFFFFF),
    controlPressed: Color(0x08FFFFFF),
    controlStroke: Color(0x12FFFFFF),
    subtleHover: Color(0x0FFFFFFF),
    subtlePressed: Color(0x0AFFFFFF),
    pressedOverlay: Color(0x14FFFFFF),
    hoverLight: Color(0x14FFFFFF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xC5FFFFFF),
    textTertiary: Color(0x87FFFFFF),
    textDisabled: Color(0x5DFFFFFF),
    accent: Color(0xFF60CDFF),
    accentHover: Color(0xE660CDFF),
    accentPressed: Color(0xCC60CDFF),
    onAccent: Color(0xFF000000),
    success: Color(0xFF6CCB5F),
    caution: Color(0xFFFCE100),
    critical: Color(0xFFFF99A4),
    dropBorder: Color(0xFF60CDFF),
    dropFill: Color(0x1F60CDFF),
    dropFillActive: Color(0x3360CDFF),
    viewerBackdrop: Color(0xF50B0B0B),
    focusOuter: Color(0xFFFFFFFF),
    focusInner: Color(0xFF000000),
  );

  /// Solid surface for floating layers (flyouts, dialogs, toasts).
  Color get flyoutSurface => isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFFFFFF);

  /// Solid surface for dialogs.
  Color get dialogSurface => isDark ? const Color(0xFF272727) : const Color(0xFFFFFFFF);

  /// Soft tint used behind status content (info bars, pills).
  Color tint(Color base, [double alpha = 0.12]) => base.withValues(alpha: alpha);

  @override
  PepoColors copyWith({Color? bgBase, Color? accent}) => PepoColors(
    brightness: brightness,
    bgBase: bgBase ?? this.bgBase,
    bgLayer: bgLayer,
    bgLayerAlt: bgLayerAlt,
    card: card,
    cardStroke: cardStroke,
    divider: divider,
    controlFill: controlFill,
    controlHover: controlHover,
    controlPressed: controlPressed,
    controlStroke: controlStroke,
    subtleHover: subtleHover,
    subtlePressed: subtlePressed,
    pressedOverlay: pressedOverlay,
    hoverLight: hoverLight,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    textTertiary: textTertiary,
    textDisabled: textDisabled,
    accent: accent ?? this.accent,
    accentHover: accentHover,
    accentPressed: accentPressed,
    onAccent: onAccent,
    success: success,
    caution: caution,
    critical: critical,
    dropBorder: dropBorder,
    dropFill: dropFill,
    dropFillActive: dropFillActive,
    viewerBackdrop: viewerBackdrop,
    focusOuter: focusOuter,
    focusInner: focusInner,
  );

  @override
  PepoColors lerp(PepoColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return PepoColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      bgBase: c(bgBase, other.bgBase),
      bgLayer: c(bgLayer, other.bgLayer),
      bgLayerAlt: c(bgLayerAlt, other.bgLayerAlt),
      card: c(card, other.card),
      cardStroke: c(cardStroke, other.cardStroke),
      divider: c(divider, other.divider),
      controlFill: c(controlFill, other.controlFill),
      controlHover: c(controlHover, other.controlHover),
      controlPressed: c(controlPressed, other.controlPressed),
      controlStroke: c(controlStroke, other.controlStroke),
      subtleHover: c(subtleHover, other.subtleHover),
      subtlePressed: c(subtlePressed, other.subtlePressed),
      pressedOverlay: c(pressedOverlay, other.pressedOverlay),
      hoverLight: c(hoverLight, other.hoverLight),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      textDisabled: c(textDisabled, other.textDisabled),
      accent: c(accent, other.accent),
      accentHover: c(accentHover, other.accentHover),
      accentPressed: c(accentPressed, other.accentPressed),
      onAccent: c(onAccent, other.onAccent),
      success: c(success, other.success),
      caution: c(caution, other.caution),
      critical: c(critical, other.critical),
      dropBorder: c(dropBorder, other.dropBorder),
      dropFill: c(dropFill, other.dropFill),
      dropFillActive: c(dropFillActive, other.dropFillActive),
      viewerBackdrop: c(viewerBackdrop, other.viewerBackdrop),
      focusOuter: c(focusOuter, other.focusOuter),
      focusInner: c(focusInner, other.focusInner),
    );
  }

  /// Every colour of the palette, for tests and the dev gallery.
  Map<String, Color> toMap() => {
    'bgBase': bgBase,
    'bgLayer': bgLayer,
    'bgLayerAlt': bgLayerAlt,
    'card': card,
    'cardStroke': cardStroke,
    'divider': divider,
    'controlFill': controlFill,
    'controlHover': controlHover,
    'controlPressed': controlPressed,
    'controlStroke': controlStroke,
    'subtleHover': subtleHover,
    'subtlePressed': subtlePressed,
    'pressedOverlay': pressedOverlay,
    'hoverLight': hoverLight,
    'textPrimary': textPrimary,
    'textSecondary': textSecondary,
    'textTertiary': textTertiary,
    'textDisabled': textDisabled,
    'accent': accent,
    'accentHover': accentHover,
    'accentPressed': accentPressed,
    'onAccent': onAccent,
    'success': success,
    'caution': caution,
    'critical': critical,
    'dropBorder': dropBorder,
    'dropFill': dropFill,
    'dropFillActive': dropFillActive,
    'viewerBackdrop': viewerBackdrop,
    'focusOuter': focusOuter,
    'focusInner': focusInner,
  };
}

/// Windows 11 type ramp, exposed by name so call sites read like the spec.
@immutable
class PepoTypography extends ThemeExtension<PepoTypography> {
  const PepoTypography({
    required this.caption,
    required this.body,
    required this.bodyStrong,
    required this.bodyLarge,
    required this.subtitle,
    required this.title,
    required this.titleLarge,
    required this.railLabel,
  });

  /// 12/16.
  final TextStyle caption;

  /// 14/20.
  final TextStyle body;

  /// 14/20 semibold.
  final TextStyle bodyStrong;

  /// 18/24.
  final TextStyle bodyLarge;

  /// 20/28 semibold.
  final TextStyle subtitle;

  /// 28/36 semibold.
  final TextStyle title;

  /// 40/52 semibold.
  final TextStyle titleLarge;

  /// 11/14, used under rail icons.
  final TextStyle railLabel;

  @override
  PepoTypography copyWith() => this;

  @override
  PepoTypography lerp(PepoTypography? other, double t) {
    if (other == null) return this;
    TextStyle s(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return PepoTypography(
      caption: s(caption, other.caption),
      body: s(body, other.body),
      bodyStrong: s(bodyStrong, other.bodyStrong),
      bodyLarge: s(bodyLarge, other.bodyLarge),
      subtitle: s(subtitle, other.subtitle),
      title: s(title, other.title),
      titleLarge: s(titleLarge, other.titleLarge),
      railLabel: s(railLabel, other.railLabel),
    );
  }
}

/// Convenience accessors: `context.pepo.accent`, `context.text.body`.
extension PepoThemeContext on BuildContext {
  PepoColors get pepo => Theme.of(this).extension<PepoColors>() ?? PepoColors.light;

  PepoTypography get text =>
      Theme.of(this).extension<PepoTypography>() ?? _fallbackTypography(pepo.textPrimary);
}

PepoTypography _fallbackTypography(Color color) {
  TextStyle s(double size, double height, [FontWeight weight = FontWeight.w400]) =>
      TextStyle(fontSize: size, height: height / size, fontWeight: weight, color: color);
  return PepoTypography(
    caption: s(12, 16),
    body: s(14, 20),
    bodyStrong: s(14, 20, FontWeight.w600),
    bodyLarge: s(18, 24),
    subtitle: s(20, 28, FontWeight.w600),
    title: s(28, 36, FontWeight.w600),
    titleLarge: s(40, 52, FontWeight.w600),
    railLabel: s(11, 14),
  );
}

/// Linear interpolation helper for painters that animate token values.
double lerpValue(double a, double b, double t) => lerpDouble(a, b, t) ?? a;
