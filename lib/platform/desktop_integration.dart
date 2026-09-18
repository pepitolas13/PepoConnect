import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

/// Window, tray and single-instance behaviour on Windows/Linux.
class DesktopIntegration with WindowListener, TrayListener {
  DesktopIntegration._();

  static final DesktopIntegration instance = DesktopIntegration._();

  bool _initialized = false;
  bool minimizeToTray = true;
  int _activeTransfers = 0;
  Timer? _boundsTimer;

  /// Called with the window bounds whenever the user moves/resizes it.
  void Function(Rect bounds)? onBoundsChanged;

  /// Tray menu actions.
  VoidCallback? onQuit;
  VoidCallback? onPauseAll;
  VoidCallback? onOpenDownloads;

  /// Labels (localized by the app).
  String labelOpen = 'Abrir PepoConnect';
  String labelPauseAll = 'Pausar transferencias';
  String labelDownloads = 'Abrir carpeta de descargas';
  String labelQuit = 'Salir';

  static bool get isSupported => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Makes sure only one instance runs (Windows). A second launch focuses
  /// the running window instead.
  static Future<void> ensureSingleInstance(List<String> args) async {
    if (!Platform.isWindows) return;
    try {
      await WindowsSingleInstance.ensureSingleInstance(
        args,
        'pepoconnect',
        onSecondWindow: (_) async {
          await windowManager.show();
          await windowManager.focus();
        },
      );
    } catch (_) {}
  }

  Future<void> init({
    required String title,
    Rect? bounds,
    bool startHidden = false,
  }) async {
    if (_initialized || !isSupported) return;
    _initialized = true;
    await windowManager.ensureInitialized();
    final options = WindowOptions(
      size: bounds?.size ?? const Size(1100, 700),
      minimumSize: const Size(720, 480),
      center: bounds == null,
      title: title,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      if (bounds != null) {
        try {
          await windowManager.setBounds(bounds);
        } catch (_) {}
      }
      if (!startHidden) {
        await windowManager.show();
        await windowManager.focus();
      }
    });
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    await _initTray();
  }

  Future<void> _initTray() async {
    try {
      trayManager.addListener(this);
      await trayManager.setIcon(_trayIconAsset());
      await trayManager.setToolTip('PepoConnect');
      await _rebuildMenu();
    } catch (_) {
      // Tray is optional (no status area on Phosh, for example).
    }
  }

  String _trayIconAsset() {
    if (Platform.isWindows) return 'assets/icon/favicon.ico';
    return 'assets/icon/pepoconnect-256.png';
  }

  Future<void> _rebuildMenu() async {
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'open', label: labelOpen),
      if (_activeTransfers > 0) MenuItem(key: 'pause', label: '$labelPauseAll ($_activeTransfers)'),
      MenuItem(key: 'downloads', label: labelDownloads),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: labelQuit),
    ]));
  }

  /// Updates the tooltip/menu with the number of active transfers.
  Future<void> setActiveTransfers(int count) async {
    if (count == _activeTransfers) return;
    _activeTransfers = count;
    try {
      await trayManager.setToolTip(count > 0 ? 'PepoConnect · $count en curso' : 'PepoConnect');
      await _rebuildMenu();
    } catch (_) {}
  }

  Future<void> setLabels({
    required String open,
    required String pauseAll,
    required String downloads,
    required String quit,
  }) async {
    labelOpen = open;
    labelPauseAll = pauseAll;
    labelDownloads = downloads;
    labelQuit = quit;
    try {
      await _rebuildMenu();
    } catch (_) {}
  }

  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> hideWindow() => windowManager.hide();

  Future<void> setTitle(String title) => windowManager.setTitle(title);

  /// Really quits (bypasses minimize-to-tray).
  Future<void> quit() async {
    try {
      await trayManager.destroy();
    } catch (_) {}
    await windowManager.setPreventClose(false);
    await windowManager.close();
    exit(0);
  }

  // WindowListener --------------------------------------------------------

  @override
  void onWindowClose() async {
    if (minimizeToTray) {
      await windowManager.hide();
    } else {
      onQuit?.call();
      await quit();
    }
  }

  @override
  void onWindowMoved() => _scheduleBounds();

  @override
  void onWindowResized() => _scheduleBounds();

  void _scheduleBounds() {
    _boundsTimer?.cancel();
    _boundsTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final b = await windowManager.getBounds();
        if (b.width >= 200 && b.height >= 200) onBoundsChanged?.call(b);
      } catch (_) {}
    });
  }

  // TrayListener ----------------------------------------------------------

  @override
  void onTrayIconMouseDown() => showWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open':
        showWindow();
      case 'pause':
        onPauseAll?.call();
      case 'downloads':
        onOpenDownloads?.call();
      case 'quit':
        onQuit?.call();
        quit();
    }
  }
}
