import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:pepo_core/pepo_core.dart' show PairedDevice;

import '../../shared/i18n/l10n.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/device_icon.dart';
import '../../shared/widgets/fluent_button.dart';
import '../../shared/widgets/pepo_card.dart';
import '../../shared/widgets/status_pill.dart';
import 'pairing_helpers.dart';

/// "Paired": the new device and a button to start using it.
class PairingDoneView extends StatelessWidget {
  const PairingDoneView({super.key, required this.device, required this.onStart});

  final PairedDevice device;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = context.pepo;
    final text = context.text;
    final platform = platformLabel(device.platform);
    final detail = [?device.model, if (platform.isNotEmpty) platform].join(' · ');
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      FluentIcons.checkmark_circle_24_filled,
                      size: 36,
                      color: colors.success,
                    ),
                  ),
                  const SizedBox(height: Space.l),
                  Text(t.pairDone, style: text.title, textAlign: TextAlign.center),
                  const SizedBox(height: Space.xs),
                  Text(
                    t.pairDoneBody,
                    style: text.body.copyWith(color: colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Space.xl),
                  PepoCard(
                    child: Row(
                      children: [
                        DeviceIcon.fromPlatform(device.platform, model: device.model, size: 32),
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
                              if (detail.isNotEmpty)
                                Text(
                                  detail,
                                  style: text.caption.copyWith(color: colors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: Space.s),
                        StatusPill(status: ConnectionStatus.connected, label: t.statusConnected),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.xxl),
                  FluentButton.primary(
                    label: t.onboardingStart,
                    size: FluentButtonSize.large,
                    expand: true,
                    autofocus: true,
                    onPressed: onStart,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
