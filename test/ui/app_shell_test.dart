import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepoconnect/app/router.dart';
import 'package:pepoconnect/app/shell/activity_panel_frame.dart';
import 'package:pepoconnect/app/shell/bottom_nav.dart';
import 'package:pepoconnect/app/shell/nav_rail.dart';
import 'package:pepoconnect/app/shell/transfer_status_bar.dart';
import 'package:pepoconnect/app/theme.dart';
import 'package:pepoconnect/dev/fakes.dart';
import 'package:pepoconnect/features/gallery/gallery_page.dart';
import 'package:pepoconnect/features/transfers/transfers_page.dart';
import 'package:pepoconnect/shared/i18n/l10n.dart';
import 'package:pepoconnect/shared/motion/motion_scope.dart';
import 'package:pepoconnect/state/app_settings.dart';
import 'package:pepoconnect/state/engine_providers.dart';

Future<void> pumpShell(
  WidgetTester tester,
  Size size, {
  AppSettings settings = const AppSettings(animations: false),
  TransfersState transfers = const TransfersState(),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: fakeOverrides(settings: settings, unread: 2, transfers: transfers),
      child: MaterialApp.router(
        routerConfig: buildRouter(),
        theme: buildLightTheme(),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MotionScope(enabled: settings.animations, child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('compact width shows the bottom bar and no rail', (tester) async {
    await pumpShell(tester, const Size(400, 800));
    expect(find.byType(BottomNav), findsOneWidget);
    expect(find.byType(NavRail), findsNothing);
    expect(find.byType(ActivityPanelFrame), findsNothing);
    expect(find.byType(TransfersPage), findsOneWidget);
    expect(find.text('Transferencias'), findsWidgets);
  });

  testWidgets('medium width shows the rail and no side panel', (tester) async {
    await pumpShell(tester, const Size(1000, 800));
    expect(find.byType(NavRail), findsOneWidget);
    expect(find.byType(BottomNav), findsNothing);
    expect(find.byType(ActivityPanelFrame), findsNothing);
  });

  testWidgets('wide width docks the activity panel by default', (tester) async {
    await pumpShell(tester, const Size(1400, 900));
    expect(find.byType(NavRail), findsOneWidget);
    expect(find.byType(ActivityPanelFrame), findsOneWidget);
    expect(find.text('Actividad'), findsWidgets);
  });

  testWidgets('rail navigates between sections', (tester) async {
    await pumpShell(tester, const Size(1000, 800));
    await tester.tap(find.widgetWithText(NavRailItem, 'Galería'));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryPage), findsOneWidget);
  });

  testWidgets('active transfers show the bottom status bar', (tester) async {
    await pumpShell(
      tester,
      const Size(1000, 800),
      transfers: TransfersState(
        active: [
          fakeTransfer(id: 1, deviceId: 'pixel8', name: 'IMG_1.jpg', bytesDone: 6 * 1024 * 1024),
        ],
      ),
    );
    expect(find.byType(TransferStatusBar), findsOneWidget);
    expect(find.textContaining('enviado a Pixel 8'), findsOneWidget);
  });
}
