import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../shared/i18n/l10n.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fluent_button.dart';

/// Placeholder; replaced by the real photo/video viewer.
class ViewerPage extends StatelessWidget {
  const ViewerPage({super.key, required this.deviceId, required this.id});

  final String deviceId;
  final String id;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = context.pepo;
    return Scaffold(
      backgroundColor: colors.viewerBackdrop,
      body: Stack(
        children: [
          Theme(
            data: Theme.of(context).copyWith(extensions: [PepoColors.dark, context.text]),
            child: EmptyState(
              icon: FluentIcons.image_48_regular,
              title: t.viewerTitle,
              message: id,
            ),
          ),
          Positioned(
            top: Space.s,
            right: Space.s,
            child: FluentIconButton(
              icon: FluentIcons.dismiss_20_regular,
              tooltip: t.close,
              color: Colors.white,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}
