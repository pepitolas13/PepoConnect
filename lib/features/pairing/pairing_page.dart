import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../shared/i18n/l10n.dart';
import '../../shared/widgets/empty_state.dart';

/// Placeholder; replaced by the real pairing flow.
class PairingPage extends StatelessWidget {
  const PairingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      body: EmptyState(
        icon: FluentIcons.qr_code_20_regular,
        title: t.pairTitle,
        message: t.pairSubtitle,
        actionLabel: t.back,
        onAction: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}
