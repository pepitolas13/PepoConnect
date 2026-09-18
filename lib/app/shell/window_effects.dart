import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';

/// True once Mica is drawing behind the window; the theme then uses a
/// transparent scaffold. Watch it to rebuild the theme.
final ValueNotifier<bool> windowEffectsActive = ValueNotifier<bool>(false);

/// Applies Mica on Windows 11 (build 22000+). Any failure leaves the solid
/// background in place. Call it from `main` after `runApp`, and again when
/// the brightness changes.
Future<bool> applyWindowEffects({required bool dark}) async {
  if (kIsWeb || !Platform.isWindows || !_supportsMica()) {
    windowEffectsActive.value = false;
    return false;
  }
  try {
    await Window.initialize();
    await Window.setEffect(effect: WindowEffect.mica, dark: dark);
    windowEffectsActive.value = true;
    return true;
  } catch (e, s) {
    debugPrint('Mica unavailable: $e\n$s');
    windowEffectsActive.value = false;
    try {
      await Window.setEffect(
        effect: WindowEffect.solid,
        color: dark ? const Color(0xFF202020) : const Color(0xFFF3F3F3),
        dark: dark,
      );
    } catch (_) {}
    return false;
  }
}

/// Reverts to a solid window (used when the user switches theme and Mica
/// must be re-applied with the other brightness, or on shutdown).
Future<void> clearWindowEffects() async {
  if (kIsWeb || !Platform.isWindows) return;
  try {
    await Window.setEffect(effect: WindowEffect.disabled);
  } catch (_) {}
  windowEffectsActive.value = false;
}

/// Windows reports "Windows 10 ... (Build 22621)" for Windows 11.
bool _supportsMica() {
  final match = RegExp(r'Build (\d+)').firstMatch(Platform.operatingSystemVersion);
  final build = int.tryParse(match?.group(1) ?? '');
  return build != null && build >= 22000;
}
