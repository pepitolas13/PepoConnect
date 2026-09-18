import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/i18n/l10n.dart';
import '../../../shared/motion/toast.dart';
import '../../../shared/theme/tokens.dart';
import '../../../shared/widgets/device_icon.dart';
import '../../../shared/widgets/dropdown_button_fluent.dart';
import '../../../shared/widgets/toggle_switch.dart';
import '../../../state/app_settings.dart';
import '../../../state/engine_providers.dart';
import '../permissions.dart';
import '../settings_providers.dart';
import '../settings_widgets.dart';

/// Rows that only make sense on the phone: automatic sending, the
/// background service, the main PC and the permission state.
class PhoneSection extends ConsumerWidget {
  const PhoneSection({super.key});

  Future<void> _toggleAutoSend(BuildContext context, WidgetRef ref, bool value) async {
    final t = context.t;
    final settings = ref.read(settingsProvider);
    final devices = ref.read(devicesProvider);
    final hub = settings.defaultHubId ?? (devices.length == 1 ? devices.single.deviceId : null);
    if (hub == null) {
      ToastService.maybeOf(context)
          ?.show(ToastData(title: t.setDefaultHubRequired, severity: ToastSeverity.caution));
      return;
    }
    await ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(autoSendPhotos: value, defaultHubId: hub));
    ref.read(settingsActionsProvider).setAutoSend(hub, value);
  }

  Future<void> _setHub(WidgetRef ref, String hubId) async {
    final settings = ref.read(settingsProvider);
    final previous = settings.defaultHubId;
    if (previous == hubId) return;
    await ref.read(settingsProvider.notifier).update((s) => s.copyWith(defaultHubId: hubId));
    if (settings.autoSendPhotos) {
      final actions = ref.read(settingsActionsProvider);
      if (previous != null) actions.setAutoSend(previous, false);
      actions.setAutoSend(hubId, true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(settingsProvider);
    final devices = ref.watch(devicesProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final hubKnown = devices.any((d) => d.deviceId == settings.defaultHubId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          header: t.setThisPhone,
          children: [
            SettingsRow(
              title: t.setAutoSendPhotos,
              description: t.setAutoSendPhotosBody,
              trailing: ToggleSwitch(
                value: settings.autoSendPhotos,
                onChanged: (v) => _toggleAutoSend(context, ref, v),
              ),
            ),
            SettingsRow(
              title: t.setBackgroundService,
              description: t.setBackgroundServiceBody,
              trailing: ToggleSwitch(
                value: settings.backgroundService,
                onChanged: (v) => notifier.update((s) => s.copyWith(backgroundService: v)),
              ),
            ),
            SettingsRow(
              title: t.setDefaultHub,
              description: t.setDefaultHubBody,
              trailing: DropdownButtonFluent<String>(
                value: hubKnown ? settings.defaultHubId : null,
                hint: t.setDefaultHubNone,
                items: [
                  for (final d in devices)
                    DropdownItem(
                      value: d.deviceId,
                      label: d.device.name,
                      icon: DeviceIcon.iconFor(
                        DeviceKind.fromPlatform(d.device.platform, model: d.device.model),
                        20,
                      ),
                    ),
                ],
                onChanged: devices.isEmpty ? null : (id) => _setHub(ref, id),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        SettingsGroup(header: t.setPermissions, children: const [PermissionRows()]),
      ],
    );
  }
}
