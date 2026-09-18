import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap.dart';
import '../../../platform/autostart.dart';
import '../../../shared/i18n/l10n.dart';
import '../../../shared/theme/tokens.dart';
import '../../../shared/widgets/dropdown_button_fluent.dart';
import '../../../shared/widgets/toggle_switch.dart';
import '../../../state/app_settings.dart';
import '../settings_widgets.dart';

/// Background, autostart, animations, theme and language.
class GeneralSection extends ConsumerWidget {
  const GeneralSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return SettingsGroup(
      header: t.settingsGeneral,
      children: [
        if (isDesktop)
          SettingsRow(
            title: t.keepInBackground,
            description: t.keepInBackgroundBody,
            trailing: ToggleSwitch(
              value: settings.minimizeToTray,
              onChanged: (v) => notifier.update((s) => s.copyWith(minimizeToTray: v)),
            ),
          ),
        if (Autostart.isSupported)
          SettingsRow(
            title: t.setStartWithSystem,
            description: t.setStartWithSystemBody,
            trailing: ToggleSwitch(
              value: settings.startWithSystem,
              onChanged: (v) => notifier.update((s) => s.copyWith(startWithSystem: v)),
            ),
          ),
        SettingsRow(
          title: t.animations,
          description: t.animationsBody,
          trailing: ToggleSwitch(
            value: settings.animations,
            onChanged: (v) => notifier.update((s) => s.copyWith(animations: v)),
          ),
        ),
        _ThemeRow(
          value: settings.themeMode,
          onChanged: (mode) => notifier.update((s) => s.copyWith(themeMode: mode)),
        ),
        SettingsRow(
          title: t.language,
          trailing: DropdownButtonFluent<String>(
            value: settings.locale,
            items: [
              DropdownItem(value: 'system', label: t.languageSystem),
              DropdownItem(value: 'es', label: t.languageSpanish),
              DropdownItem(value: 'en', label: t.languageEnglish),
            ],
            onChanged: (v) => notifier.update((s) => s.copyWith(locale: v)),
          ),
        ),
      ],
    );
  }
}

/// Title, description and the three theme cards under them.
class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.value, required this.onChanged});

  final AppThemeMode value;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = context.pepo;
    final text = context.text;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.theme, style: text.body),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: Space.m),
            child: Text(t.setThemeBody, style: text.caption.copyWith(color: colors.textSecondary)),
          ),
          ThemePicker(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
