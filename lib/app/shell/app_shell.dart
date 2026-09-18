import 'dart:async';
import 'dart:io' show Platform;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pepo_core/pepo_core.dart' show DeviceView, TransferRecord, TransferState;

import '../../shared/i18n/l10n.dart';
import '../../shared/motion/motion.dart';
import '../../shared/motion/pressable.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/device_icon.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/flyout.dart';
import '../../shared/widgets/status_pill.dart';
import '../../state/app_settings.dart';
import '../../state/engine_providers.dart';
import 'activity_panel_frame.dart';
import 'bottom_nav.dart';
import 'hub_button.dart';
import 'hub_menu.dart';
import 'nav_rail.dart';
import 'transfer_status_bar.dart';

typedef ContextCallback = void Function(BuildContext context);

/// Hooks the shell calls out to. Everything is optional: the shell falls
/// back to navigation (`/pair`, `/settings`) and to updating settings.
@immutable
class ShellActions {
  const ShellActions({
    this.onRefresh,
    this.onOpenDownloads,
    this.onAddDevice,
    this.onManageDevices,
    this.onRenamePc,
    this.onSelectDevice,
    this.onClearActivity,
    this.activityPanelBuilder,
    this.systemName,
  });

  /// F5.
  final ContextCallback? onRefresh;

  /// "Descargas" in the rail.
  final ContextCallback? onOpenDownloads;

  /// "Añadir dispositivo" (default: go to `/pair`).
  final ContextCallback? onAddDevice;

  /// "Gestionar dispositivos" (default: go to `/settings`).
  final ContextCallback? onManageDevices;

  /// Called after `settings.deviceName` is updated with the new name.
  final void Function(BuildContext context, String name)? onRenamePc;

  /// A device row in the hub menu (default: select it and go to `/gallery`).
  final void Function(BuildContext context, String deviceId)? onSelectDevice;

  /// "Borrar todo" in the activity panel.
  final ContextCallback? onClearActivity;

  /// Content of the activity panel (the list). Empty state when null.
  final WidgetBuilder? activityPanelBuilder;

  /// Host name under the PC name in the hub menu (default: local host name).
  final String? systemName;
}

/// Layout class by logical width.
enum ShellLayout {
  compact,
  medium,
  expanded;

  static ShellLayout of(double width) {
    if (width < 600) return ShellLayout.compact;
    if (width < 900) return ShellLayout.medium;
    return ShellLayout.expanded;
  }
}

/// The responsive frame around the four sections. Reads settings, devices,
/// transfers and unread activity; everything under it stays pure.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell, this.actions = const ShellActions()});

  final StatefulNavigationShell navigationShell;
  final ShellActions actions;

  /// Branch order in the router.
  static const int transfersIndex = 0;
  static const int galleryIndex = 1;
  static const int activityIndex = 2;
  static const int settingsIndex = 3;

  /// Width from which the activity panel is docked open by default.
  static const double wideBreakpoint = 1280;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  bool _statusCollapsed = true;

  /// Panel state between 900 and 1280 px, where it is closed by default.
  bool? _panelOverride;

  StatefulNavigationShell get _shell => widget.navigationShell;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A branch switch arrives as a new [StatefulNavigationShell]; moving away
  /// from the gallery is what clears its "new" marks.
  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final was = oldWidget.navigationShell.currentIndex;
    if (was == AppShell.galleryIndex && _shell.currentIndex != was) _galleryLeft();
  }

  /// The shell itself is replaced (pairing, onboarding) while the gallery
  /// was on screen. `ref` is still usable here, unlike in [dispose].
  @override
  void deactivate() {
    if (_shell.currentIndex == AppShell.galleryIndex) _galleryLeft();
    super.deactivate();
  }

  /// Minimised, hidden to the tray or sent to the background with the
  /// gallery on screen counts as leaving it too.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.hidden && state != AppLifecycleState.paused) return;
    if (_shell.currentIndex == AppShell.galleryIndex) _galleryLeft();
  }

  /// What the gallery was showing has been seen: it stops being new. The
  /// marks are gallery state, so they change once this build pass is over.
  void _galleryLeft() {
    final scope = ref.read(selectedDeviceProvider);
    final gallery = ref.read(galleryProvider(scope).notifier);
    scheduleMicrotask(() => unawaited(gallery.markSeen()));
  }

  void _goBranch(int index) {
    _shell.goBranch(index, initialLocation: index == _shell.currentIndex);
  }

  bool _panelOpen(double width, AppSettings settings) {
    if (width < 900) return false;
    if (width >= AppShell.wideBreakpoint) return settings.activityPanelOpen;
    return _panelOverride ?? false;
  }

  void _togglePanel(double width, AppSettings settings) {
    final open = _panelOpen(width, settings);
    if (width >= AppShell.wideBreakpoint) {
      ref.read(settingsProvider.notifier).update((s) => s.copyWith(activityPanelOpen: !open));
    } else {
      setState(() => _panelOverride = !open);
    }
  }

  void _openHubMenu(BuildContext anchorContext) {
    final selected = ref.read(selectedDeviceProvider);
    final systemName = widget.actions.systemName ?? _hostName();
    showFlyout<void>(
      anchorContext,
      placement: FlyoutPlacement.bottomStart,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final live = ref.watch(devicesProvider);
          final liveSettings = ref.watch(settingsProvider);
          return HubMenu(
            pcName: liveSettings.deviceName ?? systemName,
            systemName: systemName,
            devices: [
              for (final d in live)
                HubDevice(
                  id: d.deviceId,
                  name: d.device.name,
                  kind: DeviceKind.fromPlatform(d.device.platform, model: d.device.model),
                  connected: d.connected,
                  connecting: d.connecting,
                  lastSeen: d.connectedAt ?? d.device.lastSeen,
                  battery: d.status.battery,
                  charging: d.status.charging ?? false,
                ),
            ],
            selectedDeviceId: selected,
            doNotDisturb: !liveSettings.notifications,
            onDoNotDisturbChanged: (v) =>
                ref.read(settingsProvider.notifier).update((s) => s.copyWith(notifications: !v)),
            onRename: (name) {
              ref.read(settingsProvider.notifier).update((s) => s.copyWith(deviceName: name));
              widget.actions.onRenamePc?.call(this.context, name);
            },
            onAddDevice: () {
              final action = widget.actions.onAddDevice;
              if (action != null) {
                action(this.context);
              } else {
                this.context.go('/pair');
              }
            },
            onManageDevices: () {
              final action = widget.actions.onManageDevices;
              if (action != null) {
                action(this.context);
              } else {
                _goBranch(AppShell.settingsIndex);
              }
            },
            onSelectDevice: (id) {
              final action = widget.actions.onSelectDevice;
              if (action != null) {
                action(this.context, id);
              } else {
                ref.read(selectedDeviceProvider.notifier).select(id);
                _goBranch(AppShell.galleryIndex);
              }
            },
          );
        },
      ),
    );
  }

  String _hostName() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'PC';
    }
  }

  List<TransferRow> _transferRows(List<TransferRecord> active, List<DeviceView> devices) {
    final t = context.t;
    final sorted = active.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [
      for (final r in sorted)
        TransferRow(
          id: r.id,
          label: r.isIncoming
              ? t.receivedFrom((r.progress * 100).round(), deviceLabel(devices, r.deviceId))
              : t.sentTo((r.progress * 100).round(), deviceLabel(devices, r.deviceId)),
          progress: r.state == TransferState.queued ? null : r.progress,
          paused: r.state == TransferState.paused,
          onCancel: () => ref.read(transfersProvider.notifier).cancel(r.id),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final settings = ref.watch(settingsProvider);
    final unread = ref.watch(unreadActivityProvider);
    final transfers = ref.watch(transfersProvider);
    final devices = ref.watch(devicesProvider);
    final anyConnected = devices.any((d) => d.connected);
    final current = _shell.currentIndex;

    final mainItems = [
      NavItem(
        icon: FluentIcons.arrow_swap_20_regular,
        selectedIcon: FluentIcons.arrow_swap_20_filled,
        label: t.navTransfers,
        tooltip: t.navTransfers,
        shortcut: t.navShortcutHint(1),
      ),
      NavItem(
        icon: FluentIcons.image_20_regular,
        selectedIcon: FluentIcons.image_20_filled,
        label: t.navGallery,
        tooltip: t.navGallery,
        shortcut: t.navShortcutHint(2),
      ),
      NavItem(
        icon: FluentIcons.alert_20_regular,
        selectedIcon: FluentIcons.alert_20_filled,
        label: t.navActivity,
        tooltip: t.navActivity,
        shortcut: t.navShortcutHint(3),
        badge: unread,
      ),
    ];
    final settingsItem = NavItem(
      icon: FluentIcons.settings_20_regular,
      selectedIcon: FluentIcons.settings_20_filled,
      label: t.navSettings,
      tooltip: t.navSettings,
      shortcut: 'Ctrl+,',
    );
    final downloadsItem = NavItem(
      icon: FluentIcons.folder_20_regular,
      selectedIcon: FluentIcons.folder_20_filled,
      label: t.navDownloads,
      tooltip: t.openDownloadsFolder,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final layout = ShellLayout.of(width);
        final panelOpen = _panelOpen(width, settings);

        // Section changes dissolve inside the shell's branch container
        // (BranchCrossFade, set up in the router).
        final content = Theme(
          data: Theme.of(context).copyWith(scaffoldBackgroundColor: Colors.transparent),
          child: _shell,
        );

        final statusBar = transfers.active.isEmpty
            ? null
            : TransferStatusBar(
                rows: _transferRows(transfers.active, devices),
                collapsed: _statusCollapsed,
                onToggleCollapsed: () => setState(() => _statusCollapsed = !_statusCollapsed),
              );

        Widget body;
        if (layout == ShellLayout.compact) {
          body = Column(
            children: [
              _CompactHeader(devices: devices, onTap: _openHubMenu),
              Expanded(child: content),
              ?statusBar,
            ],
          );
          body = Scaffold(
            body: SafeArea(bottom: false, child: body),
            bottomNavigationBar: BottomNav(
              items: [...mainItems, settingsItem],
              selectedIndex: current,
              onSelected: _goBranch,
            ),
          );
        } else {
          final panelCapable = layout == ShellLayout.expanded;
          final rail = NavRail(
            header: Builder(
              builder: (anchor) => HubButton(
                tooltip: t.hubTooltip,
                connected: anyConnected,
                onPressed: () => _openHubMenu(anchor),
              ),
            ),
            items: mainItems,
            selected: {
              if (current < mainItems.length &&
                  !(panelCapable && current == AppShell.activityIndex))
                current,
              if (panelCapable && panelOpen) AppShell.activityIndex,
            },
            onSelected: (i) {
              if (panelCapable && i == AppShell.activityIndex) {
                _togglePanel(width, settings);
              } else {
                _goBranch(i);
              }
            },
            footer: [settingsItem, downloadsItem],
            footerSelectedIndex: current == AppShell.settingsIndex ? 0 : null,
            onFooterSelected: (i) {
              if (i == 0) {
                _goBranch(AppShell.settingsIndex);
              } else {
                widget.actions.onOpenDownloads?.call(context);
              }
            },
          );
          body = Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                rail,
                Expanded(
                  child: _ContentLayer(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(child: content),
                              ?statusBar,
                            ],
                          ),
                        ),
                        if (panelCapable && panelOpen)
                          ActivityPanelFrame(
                            unread: unread,
                            onClearAll: widget.actions.onClearActivity == null
                                ? null
                                : () => widget.actions.onClearActivity!(context),
                            onClose: () => _togglePanel(width, settings),
                            child:
                                widget.actions.activityPanelBuilder?.call(context) ??
                                EmptyState(
                                  icon: FluentIcons.alert_24_regular,
                                  title: t.activityEmpty,
                                  compact: true,
                                ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return _ShellShortcuts(
          onSection: _goBranch,
          onSettings: () => _goBranch(AppShell.settingsIndex),
          onRefresh: () => widget.actions.onRefresh?.call(context),
          child: body,
        );
      },
    );
  }
}

/// WinUI content layer: rounded top-left corner over the Mica base, with a
/// 1 px stroke on the top and left edges only.
class _ContentLayer extends StatelessWidget {
  const _ContentLayer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    const radius = BorderRadius.only(topLeft: Radius.circular(Radii.card));
    return CustomPaint(
      painter: _LayerPainter(fill: colors.bgLayer, stroke: colors.cardStroke),
      child: ClipRRect(borderRadius: radius, child: child),
    );
  }
}

class _LayerPainter extends CustomPainter {
  const _LayerPainter({required this.fill, required this.stroke});

  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndCorners(rect, topLeft: const Radius.circular(Radii.card));
    canvas.drawRRect(rrect, Paint()..color = fill);
    final path = Path()
      ..moveTo(0.5, size.height)
      ..lineTo(0.5, Radii.card)
      ..arcToPoint(const Offset(Radii.card, 0.5), radius: const Radius.circular(Radii.card - 0.5))
      ..lineTo(size.width, 0.5);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_LayerPainter old) => old.fill != fill || old.stroke != stroke;
}

/// Phone-width header: the connected device (or PC) with its status.
class _CompactHeader extends StatelessWidget {
  const _CompactHeader({required this.devices, required this.onTap});

  final List<DeviceView> devices;
  final void Function(BuildContext anchorContext) onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final t = context.t;
    DeviceView? shown;
    for (final d in devices) {
      if (d.connected) {
        shown = d;
        break;
      }
    }
    shown ??= devices.isEmpty ? null : devices.first;
    final status = shown == null
        ? ConnectionStatus.offline
        : shown.connected
        ? ConnectionStatus.connected
        : shown.connecting
        ? ConnectionStatus.connecting
        : ConnectionStatus.offline;
    final label = switch (status) {
      ConnectionStatus.connected => t.statusConnected,
      ConnectionStatus.connecting => t.statusConnecting,
      ConnectionStatus.offline => t.statusOffline,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Builder(
        builder: (anchor) => Pressable(
          onTap: () => onTap(anchor),
          semanticLabel: t.hubTooltip,
          scaleOnPress: false,
          child: SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.l),
              child: Row(
                children: [
                  if (shown != null)
                    DeviceIcon.fromPlatform(
                      shown.device.platform,
                      model: shown.device.model,
                      size: 24,
                    )
                  else
                    Icon(FluentIcons.desktop_24_regular, size: 24, color: colors.textPrimary),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Text(
                      shown?.device.name ?? t.noDeviceConnected,
                      style: text.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  StatusPill(status: status, label: label),
                  const SizedBox(width: Space.xs),
                  Icon(FluentIcons.chevron_down_12_regular, size: 12, color: colors.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ctrl+1..4, Ctrl+, and F5. Esc is handled by the flyout/dialog routes.
class _ShellShortcuts extends StatelessWidget {
  const _ShellShortcuts({
    required this.onSection,
    required this.onSettings,
    required this.onRefresh,
    required this.child,
  });

  final ValueChanged<int> onSection;
  final VoidCallback onSettings;
  final VoidCallback onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final meta = defaultTargetPlatform == TargetPlatform.macOS;
    SingleActivator ctrl(LogicalKeyboardKey key) =>
        SingleActivator(key, control: !meta, meta: meta);
    return CallbackShortcuts(
      bindings: {
        ctrl(LogicalKeyboardKey.digit1): () => onSection(0),
        ctrl(LogicalKeyboardKey.digit2): () => onSection(1),
        ctrl(LogicalKeyboardKey.digit3): () => onSection(2),
        ctrl(LogicalKeyboardKey.digit4): () => onSection(3),
        ctrl(LogicalKeyboardKey.numpad1): () => onSection(0),
        ctrl(LogicalKeyboardKey.numpad2): () => onSection(1),
        ctrl(LogicalKeyboardKey.numpad3): () => onSection(2),
        ctrl(LogicalKeyboardKey.numpad4): () => onSection(3),
        ctrl(LogicalKeyboardKey.comma): onSettings,
        const SingleActivator(LogicalKeyboardKey.f5): onRefresh,
      },
      child: Focus(autofocus: true, skipTraversal: true, child: child),
    );
  }
}

/// Exposes the active [Motion] for pages that want to match the shell.
extension ShellMotion on BuildContext {
  Motion get motion => Motion.of(this);
}
