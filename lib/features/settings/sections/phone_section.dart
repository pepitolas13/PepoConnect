import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/ios_background.dart';
import '../../../shared/i18n/l10n.dart';
import '../../../shared/motion/toast.dart';
import '../../../shared/theme/tokens.dart';
import '../../../shared/util/format.dart';
import '../../../shared/widgets/device_icon.dart';
import '../../../shared/widgets/dropdown_button_fluent.dart';
import '../../../shared/widgets/toggle_switch.dart';
import '../../../state/app_settings.dart';
import '../../../state/engine_providers.dart';
import '../permissions.dart';
import '../settings_widgets.dart';

/// Polls the iOS background engine, so the phone can show on its own screen
/// how long the process has been alive. Without it there is no way to tell a
/// working keep-alive from a silently suspended app short of a Mac.
final iosBackgroundProvider = StreamProvider.autoDispose<IosBackgroundState>((ref) async* {
  if (!IosBackground.isSupported) return;
  yield await IosBackground.status();
  yield* Stream<void>.periodic(const Duration(seconds: 5)).asyncMap((_) => IosBackground.status());
});

/// Rows that only make sense on the phone: automatic sending, the
/// background engine, the main PC and the permission state.
class PhoneSection extends ConsumerWidget {
  const PhoneSection({super.key});

  /// Only the setting is written here: `AppServices` owns applying it to the
  /// engine, so it lands the same way at every start and not just when the
  /// switch is touched.
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
  }

  Future<void> _setHub(WidgetRef ref, String hubId) async {
    final settings = ref.read(settingsProvider);
    if (settings.defaultHubId == hubId) return;
    await ref.read(settingsProvider.notifier).update((s) => s.copyWith(defaultHubId: hubId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(settingsProvider);
    final devices = ref.watch(devicesProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final hubKnown = devices.any((d) => d.deviceId == settings.defaultHubId);
    final onIos = IosBackground.isSupported;
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
              description: onIos ? t.setBackgroundServiceBodyIos : t.setBackgroundServiceBody,
              trailing: ToggleSwitch(
                value: settings.backgroundService,
                onChanged: (v) => notifier.update((s) => s.copyWith(backgroundService: v)),
              ),
            ),
            if (onIos)
              SettingsRow(
                title: t.setBackgroundEngine,
                description: t.setBackgroundEngineBody,
                trailing: const _BackgroundEngineState(),
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

/// "Activo desde hace 47 min" and the two ways it can fall short of that.
class _BackgroundEngineState extends ConsumerWidget {
  const _BackgroundEngineState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = context.pepo;
    final state = ref.watch(iosBackgroundProvider).value ?? IosBackgroundState.off;
    final String label;
    final Color color;
    final started = state.startedAt;
    if (!state.running) {
      label = t.setBackgroundEngineOff;
      color = colors.textSecondary;
    } else if (!state.playing) {
      // The session was taken away (a call, another app) and the watchdog
      // has not won it back yet.
      label = t.setBackgroundEngineRecovering;
      color = colors.caution;
    } else if (started == null) {
      label = t.setBackgroundEngineStarting;
      color = colors.success;
    } else {
      label = t.setBackgroundEngineOn(formatShortDuration(DateTime.now().difference(started)));
      color = colors.success;
    }
    return Text(label, style: context.text.caption.copyWith(color: color));
  }
}
