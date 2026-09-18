import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pepo_core/pepo_core.dart' show DeviceView;

import '../../../app/router.dart';
import '../../../shared/i18n/l10n.dart';
import '../../../shared/motion/motion.dart';
import '../../../shared/motion/pressable.dart';
import '../../../shared/theme/tokens.dart';
import '../../../shared/util/format.dart';
import '../../../shared/widgets/device_icon.dart';
import '../../../shared/widgets/fluent_button.dart';
import '../../../shared/widgets/pepo_card.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../../shared/widgets/toggle_switch.dart';
import '../../../state/app_settings.dart';
import '../../../state/engine_providers.dart';
import '../settings_widgets.dart';

/// Paired devices with their per-device options, plus "Add device".
class DevicesSection extends ConsumerWidget {
  const DevicesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = context.pepo;
    final text = context.text;
    final devices = ref.watch(devicesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(t.myDevices, style: text.bodyStrong)),
            FluentButton(
              icon: FluentIcons.add_16_regular,
              label: t.addDevice,
              onPressed: () => context.push(AppRoutes.pair),
            ),
          ],
        ),
        const SizedBox(height: Space.s),
        if (devices.isEmpty)
          PepoCard(
            child: Row(
              children: [
                Icon(FluentIcons.phone_desktop_24_regular, size: 24, color: colors.textTertiary),
                const SizedBox(width: Space.l),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.noDevicesYet, style: text.body),
                      Text(
                        t.pairFirstDevice,
                        style: text.caption.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          PepoCard(
            padding: EdgeInsets.zero,
            clip: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < devices.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: colors.divider),
                  DeviceTile(key: ValueKey(devices[i].deviceId), view: devices[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// One paired device: header row (icon, name, model, status, last
/// connection, "Remove") and an expandable panel with its options.
class DeviceTile extends ConsumerStatefulWidget {
  const DeviceTile({super.key, required this.view});

  final DeviceView view;

  /// Window width under which the status pill is a dot only.
  static const double compactWidth = 600;

  @override
  ConsumerState<DeviceTile> createState() => _DeviceTileState();
}

class _DeviceTileState extends ConsumerState<DeviceTile> {
  bool _expanded = false;

  Future<void> _forget() async {
    final t = context.t;
    final device = widget.view.device;
    final ok = await showConfirmDialog(
      context,
      title: t.setForgetConfirm(device.name),
      body: t.setForgetBody,
      confirmLabel: t.forgetDevice,
    );
    if (!ok) return;
    await ref.read(devicesProvider.notifier).forget(device.deviceId);
  }

  Future<void> _rename() async {
    final t = context.t;
    final device = widget.view.device;
    final value = await showRenameDialog(
      context,
      title: t.setRenameDeviceTitle,
      initial: device.name,
      placeholder: t.deviceNamePlaceholder,
    );
    if (value == null || value == device.name) return;
    await ref.read(devicesProvider.notifier).rename(device.deviceId, value);
  }

  Future<void> _setShareClipboard(bool value) async {
    final notifier = ref.read(devicesProvider.notifier);
    await notifier.setShareClipboard(widget.view.deviceId, value);
    // Per-device sharing only works while the global switch is on.
    if (value && !ref.read(settingsProvider).clipboardSharing) {
      await ref.read(settingsProvider.notifier).update((s) => s.copyWith(clipboardSharing: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = context.pepo;
    final text = context.text;
    final motion = Motion.of(context);
    final view = widget.view;
    final device = view.device;
    final locale = Localizations.localeOf(context).toString();
    final status = view.connected
        ? ConnectionStatus.connected
        : view.connecting
        ? ConnectionStatus.connecting
        : ConnectionStatus.offline;
    final statusLabel = switch (status) {
      ConnectionStatus.connected => t.statusConnected,
      ConnectionStatus.connecting => t.statusConnecting,
      ConnectionStatus.offline => t.statusOffline,
    };
    final lastSeen = view.connectedAt ?? device.lastSeen;
    final detail = [
      ?device.model,
      lastSeen == null
          ? t.neverSynced
          : t.setLastConnection(
              formatDayTime(lastSeen, today: t.today, yesterday: t.yesterday, locale: locale),
            ),
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Pressable(
                onTap: () => setState(() => _expanded = !_expanded),
                scaleOnPress: false,
                semanticLabel: t.deviceOptions(device.name),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.s, Space.m),
                  child: Row(
                    children: [
                      DeviceIcon.fromPlatform(device.platform, model: device.model, size: 24),
                      const SizedBox(width: Space.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name,
                              style: text.bodyStrong,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              detail,
                              style: text.caption.copyWith(color: colors.textSecondary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.s),
                      // Phone widths only have room for the dot.
                      StatusPill(
                        status: status,
                        label: statusLabel,
                        compact: MediaQuery.sizeOf(context).width < DeviceTile.compactWidth,
                      ),
                      const SizedBox(width: Space.s),
                      Icon(
                        _expanded
                            ? FluentIcons.chevron_up_20_regular
                            : FluentIcons.chevron_down_20_regular,
                        size: 16,
                        color: colors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: Space.l),
              child: FluentButton(label: t.forgetDevice, onPressed: _forget),
            ),
          ],
        ),
        AnimatedSize(
          duration: motion.normal,
          curve: Motion.standard,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Divider(height: 1, color: colors.divider),
                    SettingsRow(
                      title: t.autoDownloadPhotos,
                      description: t.autoDownloadPhotosBody,
                      trailing: ToggleSwitch(
                        value: device.autoDownload,
                        onChanged: (v) =>
                            ref.read(devicesProvider.notifier).setAutoDownload(device.deviceId, v),
                      ),
                    ),
                    Divider(height: 1, color: colors.divider),
                    SettingsRow(
                      title: t.convertHeic,
                      description: t.convertHeicBody,
                      trailing: ToggleSwitch(
                        value: device.convertHeic,
                        onChanged: (v) =>
                            ref.read(devicesProvider.notifier).setConvertHeic(device.deviceId, v),
                      ),
                    ),
                    Divider(height: 1, color: colors.divider),
                    SettingsRow(
                      title: t.sharedClipboard,
                      description: t.sharedClipboardBody,
                      trailing: ToggleSwitch(
                        value: device.shareClipboard,
                        onChanged: _setShareClipboard,
                      ),
                    ),
                    Divider(height: 1, color: colors.divider),
                    SettingsRow(
                      icon: FluentIcons.edit_16_regular,
                      title: t.changeName,
                      minHeight: 48,
                      trailing: Icon(
                        FluentIcons.chevron_right_16_regular,
                        size: 12,
                        color: colors.textTertiary,
                      ),
                      onTap: _rename,
                    ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
