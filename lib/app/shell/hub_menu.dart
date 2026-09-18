import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../shared/i18n/l10n.dart';
import '../../shared/motion/pressable.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/util/format.dart';
import '../../shared/widgets/battery_indicator.dart';
import '../../shared/widgets/device_icon.dart';
import '../../shared/widgets/fluent_button.dart';
import '../../shared/widgets/flyout.dart';
import '../../shared/widgets/pepo_text_field.dart';
import '../../shared/widgets/status_pill.dart';
import '../../shared/widgets/toggle_switch.dart';

/// Device row data for the hub menu (pure; the shell maps providers to it).
@immutable
class HubDevice {
  const HubDevice({
    required this.id,
    required this.name,
    required this.kind,
    this.connected = false,
    this.connecting = false,
    this.lastSeen,
    this.battery,
    this.charging = false,
  });

  final String id;
  final String name;
  final DeviceKind kind;
  final bool connected;
  final bool connecting;
  final DateTime? lastSeen;
  final int? battery;
  final bool charging;
}

/// The floating menu under the hub button: editable PC name, paired
/// devices with last sync and battery, add / manage, do not disturb.
class HubMenu extends StatefulWidget {
  const HubMenu({
    super.key,
    required this.pcName,
    required this.systemName,
    required this.devices,
    required this.onRename,
    required this.onAddDevice,
    required this.onManageDevices,
    required this.onSelectDevice,
    required this.doNotDisturb,
    required this.onDoNotDisturbChanged,
    this.selectedDeviceId,
    this.width = 320,
  });

  final String pcName;

  /// Host name shown under the editable name.
  final String systemName;
  final List<HubDevice> devices;
  final String? selectedDeviceId;
  final ValueChanged<String> onRename;
  final VoidCallback onAddDevice;
  final VoidCallback onManageDevices;
  final ValueChanged<String> onSelectDevice;
  final bool doNotDisturb;
  final ValueChanged<bool> onDoNotDisturbChanged;
  final double width;

  @override
  State<HubMenu> createState() => _HubMenuState();
}

class _HubMenuState extends State<HubMenu> {
  bool _editing = false;
  late final TextEditingController _name = TextEditingController(text: widget.pcName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _commit() {
    final value = _name.text.trim();
    setState(() => _editing = false);
    if (value.isNotEmpty && value != widget.pcName) widget.onRename(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final t = context.t;
    final locale = Localizations.localeOf(context).toString();
    return FlyoutSurface(
      width: widget.width,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // PC name.
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.s, Space.m),
            child: Row(
              children: [
                Icon(FluentIcons.desktop_24_regular, size: 24, color: colors.textPrimary),
                const SizedBox(width: Space.m),
                Expanded(
                  child: _editing
                      ? PepoTextField(
                          controller: _name,
                          autofocus: true,
                          placeholder: t.pcNamePlaceholder,
                          maxLength: 40,
                          onSubmitted: (_) => _commit(),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.pcName,
                              style: text.bodyStrong,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.systemName,
                              style: text.caption.copyWith(color: colors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: Space.xs),
                FluentIconButton(
                  icon: _editing ? FluentIcons.checkmark_16_regular : FluentIcons.edit_16_regular,
                  tooltip: _editing ? t.save : t.editPcName,
                  onPressed: _editing ? _commit : () => setState(() => _editing = true),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.divider),
          // Devices.
          if (widget.devices.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.l, Space.m),
              child: Text(
                t.noDevicesPaired,
                style: text.body.copyWith(color: colors.textSecondary),
              ),
            )
          else
            for (final d in widget.devices)
              _DeviceRow(
                device: d,
                selected: d.id == widget.selectedDeviceId,
                locale: locale,
                onTap: () => widget.onSelectDevice(d.id),
              ),
          Divider(height: 1, color: colors.divider),
          _MenuRow(icon: FluentIcons.add_16_regular, label: t.addDevice, onTap: widget.onAddDevice),
          _MenuRow(
            icon: FluentIcons.phone_desktop_20_regular,
            label: t.manageDevices,
            onTap: widget.onManageDevices,
          ),
          Divider(height: 1, color: colors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, Space.s),
            child: Row(
              children: [
                Icon(FluentIcons.alert_off_20_regular, size: 16, color: colors.textPrimary),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.doNotDisturb, style: text.body),
                      Text(
                        t.doNotDisturbBody,
                        style: text.caption.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.s),
                ToggleSwitch(value: widget.doNotDisturb, onChanged: widget.onDoNotDisturbChanged),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.selected,
    required this.locale,
    required this.onTap,
  });

  final HubDevice device;
  final bool selected;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final t = context.t;
    final status = device.connected
        ? ConnectionStatus.connected
        : device.connecting
        ? ConnectionStatus.connecting
        : ConnectionStatus.offline;
    final statusLabel = switch (status) {
      ConnectionStatus.connected => t.statusConnected,
      ConnectionStatus.connecting => t.statusConnecting,
      ConnectionStatus.offline => t.statusOffline,
    };
    final sync = device.lastSeen == null
        ? t.neverSynced
        : t.lastSync(
            formatDayTime(device.lastSeen!, today: t.today, yesterday: t.yesterday, locale: locale),
          );
    return Pressable(
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      semanticLabel: '${device.name}, $statusLabel',
      scaleOnPress: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, Space.s),
        child: Row(
          children: [
            DeviceIcon(
              kind: device.kind,
              size: 24,
              color: selected ? colors.accent : colors.textPrimary,
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          device.name,
                          style: text.bodyStrong.copyWith(
                            color: selected ? colors.accent : colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Space.s),
                      StatusPill(status: status, label: statusLabel, compact: true),
                    ],
                  ),
                  Text(
                    sync,
                    style: text.caption.copyWith(color: colors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (device.battery != null) ...[
              const SizedBox(width: Space.s),
              BatteryIndicator(level: device.battery, charging: device.charging),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    return Pressable(
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      semanticLabel: label,
      scaleOnPress: false,
      child: SizedBox(
        height: 36,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.l),
          child: Row(
            children: [
              Icon(icon, size: 16, color: colors.textPrimary),
              const SizedBox(width: Space.m),
              Expanded(child: Text(label, style: context.text.body)),
              Icon(FluentIcons.chevron_right_16_regular, size: 12, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
