import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../shared/i18n/l10n.dart';
import '../../shared/widgets/empty_state.dart';

/// Placeholder; replaced by the real settings page.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: EmptyState(icon: FluentIcons.settings_48_regular, title: t.settingsTitle),
    );
  }
}
