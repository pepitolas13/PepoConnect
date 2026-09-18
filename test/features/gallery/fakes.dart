// Shared test helpers for the feature pages. The doubles themselves live in
// `lib/dev/fakes.dart` (re-exported here) so the dev widget gallery uses the
// same ones.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pepo_core/pepo_core.dart';
import 'package:pepoconnect/app/theme.dart';
import 'package:pepoconnect/dev/fakes.dart';
import 'package:pepoconnect/shared/i18n/l10n.dart';
import 'package:pepoconnect/shared/motion/motion_scope.dart';
import 'package:pepoconnect/shared/motion/toast.dart';
import 'package:pepoconnect/state/activity.dart';
import 'package:pepoconnect/state/app_settings.dart';
import 'package:pepoconnect/state/engine_providers.dart';

export 'package:pepoconnect/dev/fakes.dart';

/// Overrides for a feature page, with animations off by default.
/// `unreadActivityProvider` stays real so it follows the fake activity.
List<Override> featureOverrides({
  AppSettings settings = const AppSettings(animations: false),
  List<DeviceView>? devices,
  TransfersState transfers = const TransfersState(),
  List<GalleryEntry> entries = const [],
  Map<String, Uint8List> thumbnails = const {},
  bool galleryLoaded = true,
  List<ActivityEntry> activity = const [],
  ToastService? toasts,
}) => fakeOverrides(
  settings: settings,
  devices: devices,
  transfers: transfers,
  entries: entries,
  thumbnails: thumbnails,
  galleryLoaded: galleryLoaded,
  activity: activity,
  toasts: toasts,
);

/// Desktop behaviour (hover check boxes, tooltips, no pull to refresh).
final TargetPlatformVariant desktopVariant = TargetPlatformVariant.only(TargetPlatform.windows);

/// Touch behaviour (check boxes always visible, tap opens the viewer).
final TargetPlatformVariant touchVariant = TargetPlatformVariant.only(TargetPlatform.android);

/// Pumps [child] inside the app chrome at [size], with motion off and the
/// Spanish locale. Pass `variant: desktopVariant` (or [touchVariant]) to
/// `testWidgets` so the platform is set and restored properly.
Future<void> pumpFeature(
  WidgetTester tester, {
  required Widget child,
  required List<Override> overrides,
  Size size = const Size(1200, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: buildLightTheme(),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MotionScope(enabled: false, child: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
