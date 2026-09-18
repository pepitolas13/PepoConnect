import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../shared/i18n/l10n.dart';
import '../../shared/motion/pressable.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/util/format.dart';
import '../../shared/widgets/device_icon.dart';
import '../../shared/widgets/fluent_button.dart';
import '../../shared/widgets/flyout.dart';
import '../../shared/widgets/pill_tabs.dart';
import '../../shared/widgets/status_pill.dart';
import '../../state/app_settings.dart';

/// A device as listed in the gallery's device menu.
@immutable
class GalleryDeviceOption {
  const GalleryDeviceOption({
    required this.id,
    required this.name,
    required this.kind,
    required this.connected,
  });

  final String id;
  final String name;
  final DeviceKind kind;
  final bool connected;
}

/// Width from which the header and the selection bar use labelled buttons
/// on one row.
const double galleryWideHeader = 760;

const EdgeInsets _headerPadding = EdgeInsets.fromLTRB(Space.xl, Space.m, Space.xl, Space.s);

/// "Galería de Pixel 8 ▾ | Fotos Vídeos Todo | … Vista ▾ Sesión".
class GalleryHeader extends StatelessWidget {
  const GalleryHeader({
    super.key,
    required this.devices,
    required this.selectedDeviceId,
    required this.onDeviceChanged,
    required this.filterIndex,
    required this.onFilterChanged,
    required this.tileSize,
    required this.square,
    required this.onTileSizeChanged,
    required this.onSquareChanged,
    required this.onRefresh,
    required this.onSession,
    this.summary,
  });

  final List<GalleryDeviceOption> devices;

  /// Null = all devices.
  final String? selectedDeviceId;
  final ValueChanged<String?> onDeviceChanged;

  /// 0 photos, 1 videos, 2 all.
  final int filterIndex;
  final ValueChanged<int> onFilterChanged;
  final GalleryTileSize tileSize;
  final bool square;
  final ValueChanged<GalleryTileSize> onTileSizeChanged;
  final ValueChanged<bool> onSquareChanged;
  final VoidCallback? onRefresh;
  final VoidCallback? onSession;

  /// "1.240 elementos · 3 fotos nuevas".
  final String? summary;

  GalleryDeviceOption? get _selected {
    for (final d in devices) {
      if (d.id == selectedDeviceId) return d;
    }
    return null;
  }

  void _openDevices(BuildContext anchor) {
    showFlyout<void>(
      anchor,
      builder: (_) => _DeviceMenu(
        devices: devices,
        selectedDeviceId: selectedDeviceId,
        onChanged: onDeviceChanged,
      ),
    );
  }

  void _openView(BuildContext anchor) {
    final t = anchor.t;
    showFlyout<void>(
      anchor,
      builder: (_) => ContextMenu(
        items: [
          MenuHeader(t.galTileSize),
          MenuItem(
            label: t.viewLarge,
            checked: tileSize == GalleryTileSize.large,
            onTap: () => onTileSizeChanged(GalleryTileSize.large),
          ),
          MenuItem(
            label: t.viewMedium,
            checked: tileSize == GalleryTileSize.medium,
            onTap: () => onTileSizeChanged(GalleryTileSize.medium),
          ),
          MenuItem(
            label: t.viewSmall,
            checked: tileSize == GalleryTileSize.small,
            onTap: () => onTileSizeChanged(GalleryTileSize.small),
          ),
          const MenuDivider(),
          MenuItem(label: t.squareThumbnails, checked: square, onTap: () => onSquareChanged(true)),
          MenuItem(
            label: t.galFullThumbnails,
            checked: !square,
            onTap: () => onSquareChanged(false),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final t = context.t;
    final selected = _selected;
    // Narrow layouts show just the device name ("Galería de" would not fit).
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final deviceButton = Builder(
      builder: (anchor) => FluentButton(
        label: selected == null
            ? t.allDevices
            : (narrow ? selected.name : t.galleryOf(selected.name)),
        icon: selected == null
            ? FluentIcons.phone_desktop_20_regular
            : DeviceIcon.iconFor(selected.kind, 20),
        trailingIcon: FluentIcons.chevron_down_12_regular,
        onPressed: devices.isEmpty ? null : () => _openDevices(anchor),
      ),
    );
    final tabs = PillTabs(
      tabs: [t.photos, t.videos, t.all],
      index: filterIndex,
      onChanged: onFilterChanged,
    );
    final refresh = FluentIconButton(
      icon: FluentIcons.arrow_sync_20_regular,
      tooltip: t.galleryRefreshTooltip,
      onPressed: onRefresh,
    );
    final view = Builder(
      builder: (anchor) => FluentButton(
        label: t.view,
        icon: FluentIcons.grid_20_regular,
        trailingIcon: FluentIcons.chevron_down_12_regular,
        onPressed: () => _openView(anchor),
      ),
    );
    // Narrow rows keep the width for the device name.
    final viewCompact = Builder(
      builder: (anchor) => FluentIconButton(
        icon: FluentIcons.grid_20_regular,
        tooltip: t.view,
        onPressed: () => _openView(anchor),
      ),
    );
    final summaryText = summary == null
        ? null
        : Text(
            summary!,
            style: text.caption.copyWith(color: colors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );

    return Padding(
      padding: _headerPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= galleryWideHeader;
          final session = FluentButton(
            label: t.galSession,
            icon: FluentIcons.camera_20_regular,
            tooltip: t.galSessionTooltip,
            onPressed: onSession,
          );
          if (wide) {
            // The controls on the right keep their place whatever the tabs or
            // the summary do: only the leading group flexes.
            return Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(child: deviceButton),
                      const SizedBox(width: Space.m),
                      tabs,
                      if (summaryText != null) ...[
                        const SizedBox(width: Space.m),
                        Flexible(child: summaryText),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Space.s),
                refresh,
                const SizedBox(width: Space.xs),
                view,
                const SizedBox(width: Space.xs),
                session,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Flexible(child: deviceButton),
                  const Spacer(),
                  refresh,
                  const SizedBox(width: Space.xs),
                  viewCompact,
                  const SizedBox(width: Space.xs),
                  FluentIconButton(
                    icon: FluentIcons.camera_20_regular,
                    tooltip: t.galSessionTooltip,
                    onPressed: onSession,
                  ),
                ],
              ),
              const SizedBox(height: Space.s),
              Row(
                children: [
                  tabs,
                  if (summaryText != null) ...[
                    const SizedBox(width: Space.m),
                    Flexible(child: summaryText),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Flyout listing the paired devices ("Your phone" / "Your PC") and "All
/// devices".
class _DeviceMenu extends StatelessWidget {
  const _DeviceMenu({
    required this.devices,
    required this.selectedDeviceId,
    required this.onChanged,
  });

  final List<GalleryDeviceOption> devices;
  final String? selectedDeviceId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final t = context.t;
    return FlyoutSurface(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final d in devices)
            _DeviceMenuRow(
              option: d,
              subtitle: switch (d.kind) {
                DeviceKind.phone => t.galYourPhone,
                DeviceKind.tablet => t.galYourTablet,
                _ => t.galYourPc,
              },
              selected: d.id == selectedDeviceId,
              onTap: () => onChanged(d.id),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xs, horizontal: Space.xs),
            child: Divider(height: 1, color: colors.divider),
          ),
          _DeviceMenuRow(
            option: null,
            subtitle: null,
            selected: selectedDeviceId == null,
            onTap: () => onChanged(null),
          ),
        ],
      ),
    );
  }
}

class _DeviceMenuRow extends StatelessWidget {
  const _DeviceMenuRow({
    required this.option,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  /// Null = "All devices".
  final GalleryDeviceOption? option;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final t = context.t;
    final d = option;
    final color = selected ? colors.accent : colors.textPrimary;
    return Pressable(
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      scaleOnPress: false,
      semanticLabel: d?.name ?? t.allDevices,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
        child: Row(
          children: [
            if (d == null)
              Icon(FluentIcons.phone_desktop_24_regular, size: 24, color: color)
            else
              DeviceIcon(kind: d.kind, size: 24, color: color),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d?.name ?? t.allDevices,
                    style: text.bodyStrong.copyWith(color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: text.caption.copyWith(color: colors.textSecondary)),
                ],
              ),
            ),
            if (d != null) ...[
              const SizedBox(width: Space.s),
              StatusPill(
                status: d.connected ? ConnectionStatus.connected : ConnectionStatus.offline,
                label: d.connected ? t.statusConnected : t.statusOffline,
                compact: true,
              ),
            ],
            if (selected) ...[
              const SizedBox(width: Space.s),
              Icon(FluentIcons.checkmark_16_regular, size: 16, color: colors.accent),
            ],
          ],
        ),
      ),
    );
  }
}

/// Replaces the header while something is selected: count and size, the
/// main actions and a "more" menu.
class GallerySelectionBar extends StatelessWidget {
  const GallerySelectionBar({
    super.key,
    required this.count,
    required this.bytes,
    required this.onClear,
    required this.onDownload,
    required this.onSaveAs,
    required this.onDelete,
    required this.menuItems,
  });

  final int count;
  final int bytes;
  final VoidCallback onClear;
  final VoidCallback? onDownload;
  final VoidCallback onSaveAs;
  final VoidCallback onDelete;

  /// Entries of the "…" menu, built when it opens.
  final List<MenuEntry> Function() menuItems;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final t = context.t;
    final locale = Localizations.localeOf(context).toString();
    return Padding(
      padding: _headerPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= galleryWideHeader;
          final more = Builder(
            builder: (anchor) => FluentIconButton(
              icon: FluentIcons.more_horizontal_16_regular,
              tooltip: t.more,
              onPressed: () => showFlyout<void>(
                anchor,
                placement: FlyoutPlacement.bottomEnd,
                builder: (_) => ContextMenu(items: menuItems()),
              ),
            ),
          );
          return SizedBox(
            height: Sizes.buttonHeight,
            child: Row(
              children: [
                FluentIconButton(
                  icon: FluentIcons.dismiss_16_regular,
                  tooltip: t.deselectAll,
                  onPressed: onClear,
                ),
                const SizedBox(width: Space.s),
                Flexible(
                  child: Text(
                    t.selectedCountSize(count, formatBytes(bytes, locale: locale)),
                    style: text.bodyStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                if (wide) ...[
                  FluentButton(
                    label: t.download,
                    icon: FluentIcons.arrow_download_16_regular,
                    onPressed: onDownload,
                  ),
                  const SizedBox(width: Space.xs),
                  FluentButton(
                    label: t.saveAs,
                    icon: FluentIcons.folder_arrow_right_16_regular,
                    onPressed: onSaveAs,
                  ),
                  const SizedBox(width: Space.xs),
                  FluentButton(
                    label: t.deleteFromPhone,
                    icon: FluentIcons.delete_16_regular,
                    onPressed: onDelete,
                  ),
                ] else ...[
                  FluentIconButton(
                    icon: FluentIcons.arrow_download_16_regular,
                    tooltip: t.download,
                    onPressed: onDownload,
                  ),
                  FluentIconButton(
                    icon: FluentIcons.folder_arrow_right_16_regular,
                    tooltip: t.saveAs,
                    onPressed: onSaveAs,
                  ),
                  FluentIconButton(
                    icon: FluentIcons.delete_16_regular,
                    tooltip: t.deleteFromPhone,
                    onPressed: onDelete,
                  ),
                ],
                const SizedBox(width: Space.xs),
                more,
              ],
            ),
          );
        },
      ),
    );
  }
}
