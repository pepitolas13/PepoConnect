import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../shared/i18n/l10n.dart';
import '../../shared/widgets/empty_state.dart';

/// Placeholder; replaced by the real activity page.
class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: EmptyState(icon: FluentIcons.alert_48_regular, title: t.activityEmpty),
    );
  }
}
