import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/i18n/l10n.dart';
import '../../../shared/widgets/toggle_switch.dart';
import '../../../state/app_settings.dart';
import '../settings_widgets.dart';

/// System notifications and sounds.
class NotificationsSection extends ConsumerWidget {
  const NotificationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return SettingsGroup(
      header: t.settingsNotifications,
      children: [
        SettingsRow(
          title: t.notifications,
          description: t.notificationsBody,
          trailing: ToggleSwitch(
            value: settings.notifications,
            onChanged: (v) => notifier.update((s) => s.copyWith(notifications: v)),
          ),
        ),
        SettingsRow(
          title: t.sounds,
          description: t.soundsBody,
          trailing: ToggleSwitch(
            value: settings.sounds,
            onChanged: (v) => notifier.update((s) => s.copyWith(sounds: v)),
          ),
        ),
      ],
    );
  }
}
