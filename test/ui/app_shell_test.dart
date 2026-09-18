import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pepoconnect/app/router.dart';
import 'package:pepoconnect/app/shell/activity_panel_frame.dart';
import 'package:pepoconnect/app/shell/app_shell.dart';
import 'package:pepoconnect/app/shell/bottom_nav.dart';
import 'package:pepoconnect/app/shell/nav_rail.dart';
import 'package:pepoconnect/app/shell/transfer_status_bar.dart';
import 'package:pepoconnect/app/theme.dart';
import 'package:pepoconnect/dev/fakes.dart';
import 'package:pepoconnect/features/activity/activity_page.dart';
import 'package:pepoconnect/features/gallery/gallery_page.dart';
import 'package:pepoconnect/features/transfers/transfers_page.dart';
import 'package:pepoconnect/shared/i18n/l10n.dart';
import 'package:pepoconnect/shared/motion/branch_cross_fade.dart';
import 'package:pepoconnect/shared/motion/motion_scope.dart';
import 'package:pepoconnect/state/app_settings.dart';
import 'package:pepoconnect/state/engine_providers.dart';

Future<void> pumpShell(
  WidgetTester tester,
  Size size, {
  AppSettings settings = const AppSettings(animations: false),
  TransfersState transfers = const TransfersState(),
  bool settle = true,
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(seconds: 1));
  }
}

/// Opacity the branch container gives branch [index].
double branchAlpha(WidgetTester tester, int index) => tester
    .widget<FadeTransition>(
      find
          .descendant(
            of: find.byKey(branchSlotKey(index), skipOffstage: false),
            matching: find.byType(FadeTransition, skipOffstage: false),
          )
          .first,
    )
    .opacity
    .value;

/// Paint order of the branch slots (last paints on top).
List<int> branchOrder(WidgetTester tester) {
  final stack = tester.widget<Stack>(
    find
        .ancestor(
          of: find.byKey(branchSlotKey(0), skipOffstage: false),
          matching: find.byType(Stack, skipOffstage: false),
        )
        .first,
  );
  return [
    for (final child in stack.children)
      for (var i = 0; i < 4; i++)
        if (child.key == branchSlotKey(i)) i,
  ];
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
    // With motion off the swap is instant: the old section is offstage but kept.
    expect(find.byType(TransfersPage), findsNothing);
    expect(find.byType(TransfersPage, skipOffstage: false), findsOneWidget);
  });

  testWidgets('sections dissolve: the old one stays painted under the new one', (tester) async {
    await pumpShell(
      tester,
      const Size(1000, 800),
      settings: const AppSettings(animations: true),
      settle: false,
    );
    await tester.tap(find.widgetWithText(NavRailItem, 'Galería'));
    await tester.pump();
    // First frame: the gallery is on top at 0, the transfers intact below.
    expect(find.byType(TransfersPage), findsOneWidget);
    expect(find.byType(GalleryPage), findsOneWidget);
    expect(branchAlpha(tester, AppShell.transfersIndex), 1);
    expect(branchAlpha(tester, AppShell.galleryIndex), 0);
    expect(branchOrder(tester).last, AppShell.galleryIndex);
    expect(branchOrder(tester).indexOf(AppShell.transfersIndex), 2);

    for (var elapsed = 0; elapsed < 180; elapsed += 20) {
      await tester.pump(const Duration(milliseconds: 20));
      final gallery = branchAlpha(tester, AppShell.galleryIndex);
      final transfers = branchAlpha(tester, AppShell.transfersIndex);
      expect((1 - gallery) * (1 - transfers), lessThanOrEqualTo(0.11), reason: '$elapsed ms');
      // The old section dims linearly (1 - t over 180 ms); the new one leads.
      expect(transfers, closeTo(1 - (elapsed + 20) / 180, 0.001), reason: '$elapsed ms');
      // Crossover a third of the way in: from then on the new section leads.
      if (elapsed + 20 >= 80) expect(gallery, greaterThan(transfers), reason: '$elapsed ms');
    }
    await tester.pump(const Duration(milliseconds: 50));
    expect(branchAlpha(tester, AppShell.galleryIndex), 1);
    expect(find.byType(GalleryPage), findsOneWidget);
    expect(find.byType(TransfersPage), findsNothing);
    expect(find.byType(TransfersPage, skipOffstage: false), findsOneWidget);
  });

  testWidgets('a switch mid-dissolve drops the covered section and fades the half-shown one', (
    tester,
  ) async {
    // Compact layout: the bottom bar reaches every branch directly (560 px:
    // the gallery header still fits on one line).
    await pumpShell(
      tester,
      const Size(560, 800),
      settings: const AppSettings(animations: true),
      settle: false,
    );
    Finder tab(String label) =>
        find.descendant(of: find.byType(BottomNav), matching: find.text(label));
    await tester.tap(tab('Galería'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(tab('Actividad'));
    await tester.pump();
    expect(find.byType(ActivityPage), findsOneWidget);
    expect(find.byType(GalleryPage), findsOneWidget);
    expect(find.byType(TransfersPage), findsNothing);
    expect(branchOrder(tester).last, AppShell.activityIndex);
    expect(branchAlpha(tester, AppShell.galleryIndex), 1);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(ActivityPage), findsOneWidget);
    expect(find.byType(GalleryPage), findsNothing);
    expect(find.byType(GalleryPage, skipOffstage: false), findsOneWidget);
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
