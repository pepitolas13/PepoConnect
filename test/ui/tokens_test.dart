import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepoconnect/app/theme.dart';
import 'package:pepoconnect/shared/theme/pepo_theme.dart';
import 'package:pepoconnect/shared/theme/tokens.dart';

void main() {
  test('light and dark palettes define the same complete set of tokens', () {
    final light = PepoColors.light.toMap();
    final dark = PepoColors.dark.toMap();
    expect(light.keys.toSet(), dark.keys.toSet());
    expect(light.length, greaterThanOrEqualTo(30));
    for (final entry in light.entries) {
      expect(entry.value, isA<Color>(), reason: entry.key);
    }
    // Spot checks against the spec.
    expect(light['bgBase'], const Color(0xFFF3F3F3));
    expect(dark['bgBase'], const Color(0xFF202020));
    expect(light['accent'], const Color(0xFF005FB8));
    expect(dark['accent'], const Color(0xFF60CDFF));
    expect(light['textPrimary'], const Color(0xE4000000));
    expect(dark['textPrimary'], const Color(0xFFFFFFFF));
    expect(light['dropBorder'], const Color(0xFF7FB8E6));
    expect(light['dropFill'], const Color(0xFFEAF3FC));
    expect(light['success'], const Color(0xFF0F7B0F));
    expect(dark['critical'], const Color(0xFFFF99A4));
    expect(light['viewerBackdrop'], const Color(0xF50B0B0B));
  });

  test('palettes interpolate', () {
    final mid = PepoColors.light.lerp(PepoColors.dark, 0.5);
    expect(mid.bgBase, Color.lerp(PepoColors.light.bgBase, PepoColors.dark.bgBase, 0.5));
    expect(PepoColors.light.lerp(null, 0.5), PepoColors.light);
  });

  test('themes carry the extensions and the Windows 11 type ramp', () {
    final light = buildLightTheme();
    final dark = buildDarkTheme();
    expect(light.useMaterial3, isTrue);
    expect(light.extension<PepoColors>(), PepoColors.light);
    expect(dark.extension<PepoColors>(), PepoColors.dark);
    expect(light.scaffoldBackgroundColor, PepoColors.light.bgBase);
    expect(
      buildLightTheme(transparentBackground: true).scaffoldBackgroundColor,
      Colors.transparent,
    );
    expect(light.splashFactory, NoSplash.splashFactory);
    expect(light.hoverColor, Colors.transparent);

    final t = light.extension<PepoTypography>()!;
    expect(t.caption.fontSize, 12);
    expect(t.body.fontSize, 14);
    expect(t.bodyStrong.fontWeight, FontWeight.w600);
    expect(t.bodyLarge.fontSize, 18);
    expect(t.subtitle.fontSize, 20);
    expect(t.title.fontSize, 28);
    expect(t.titleLarge.fontSize, 40);
    expect(t.railLabel.fontSize, 11);
    expect(light.textTheme.bodyMedium!.fontSize, 14);
    expect(light.textTheme.titleLarge!.fontSize, 28);
  });

  test('typography resolves the platform font family', () {
    final windows = PepoTheme.typography(PepoColors.light, platform: TargetPlatform.windows);
    expect(windows.body.fontFamily, 'Segoe UI Variable Text');
    expect(windows.title.fontFamily, 'Segoe UI Variable Display');
    expect(windows.body.fontFamilyFallback, contains('Segoe UI'));
    final android = PepoTheme.typography(PepoColors.light, platform: TargetPlatform.android);
    expect(android.body.fontFamily, isNull);
    final linux = PepoTheme.typography(PepoColors.light, platform: TargetPlatform.linux);
    expect(linux.body.fontFamily, 'Cantarell');
    expect(linux.body.fontFamilyFallback, ['Adwaita Sans', 'Noto Sans', 'DejaVu Sans']);
  });
}
