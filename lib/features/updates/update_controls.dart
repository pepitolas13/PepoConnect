import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/open_helper.dart';
import '../../shared/i18n/l10n.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/fluent_button.dart';
import '../../shared/widgets/info_bar.dart';
import 'update_controller.dart';
import 'update_installer.dart';
import 'update_providers.dart';

/// The same update state and actions in Settings and in the foreground offer.
class UpdateControls extends ConsumerStatefulWidget {
  const UpdateControls({super.key, this.offer = false});
  final bool offer;
  @override
  ConsumerState<UpdateControls> createState() => _UpdateControlsState();
}

class _UpdateControlsState extends ConsumerState<UpdateControls> {
  bool _openFailed = false;

  Future<void> _open(String url) async {
    final ok = await OpenHelper.openUrl(url);
    if (mounted) setState(() => _openFailed = !ok);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(updateControllerProvider);
    final canInstall = ref.watch(updateCanInstallProvider);
    final t = context.t;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        final release = state.release;
        final available = release?.isNewer == true;
        final external =
            state.support == UpdateSupport.ios || state.support == UpdateSupport.unavailable;
        final error = switch (state.errorCode) {
          'check' => t.setUpdateFailedBody,
          'download' => t.updateDownloadFailed,
          'verification' => t.updateVerificationFailed,
          'permission' => t.updatePermissionFailed,
          'unsupported' => t.updateUnavailableBody,
          'busy' => t.updateBusyBody,
          null => null,
          _ => t.updateGenericFailed,
        };
        final description = switch (state.support) {
          UpdateSupport.direct => t.updateDesktopBody,
          UpdateSupport.android => t.updateAndroidBody,
          UpdateSupport.flatpak => t.updateFlatpakBody,
          UpdateSupport.ios => t.updateIosBody,
          UpdateSupport.unavailable => t.updateUnavailableBody,
        };
        final progressLabel = switch (state.phase) {
          UpdatePhase.verifying => t.updateVerifying,
          UpdatePhase.installing => t.updateInstalling,
          _ => t.updateDownloading,
        };
        final fraction = state.progress?.fraction;
        return Padding(
          padding: widget.offer ? EdgeInsets.zero : const EdgeInsets.all(Space.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.offer) ...[
                Text(t.setCheckUpdates, style: context.text.bodyStrong),
                const SizedBox(height: Space.s),
                Text(t.updateDailyBody, style: context.text.caption),
                const SizedBox(height: Space.m),
              ],
              if (available) ...[
                if (!widget.offer)
                  Text(t.setUpdateAvailable(release!.latest), style: context.text.bodyStrong),
                Text(description, style: context.text.body),
                const SizedBox(height: Space.m),
              ] else if (state.phase == UpdatePhase.upToDate) ...[
                InfoBar(severity: InfoBarSeverity.success, title: t.setUpToDate),
                const SizedBox(height: Space.m),
              ],
              if (error != null || _openFailed) ...[
                InfoBar(
                  severity: InfoBarSeverity.critical,
                  title: state.errorCode == 'check' ? t.setUpdateFailed : t.updateInstallFailed,
                  message: _openFailed ? t.updateOpenFailed : error,
                ),
                const SizedBox(height: Space.m),
              ],
              if (state.phase == UpdatePhase.permissionRequired ||
                  state.phase == UpdatePhase.installerOpened) ...[
                InfoBar(
                  title: state.phase == UpdatePhase.permissionRequired
                      ? t.updatePermissionBody
                      : t.updateInstallerOpened,
                ),
                const SizedBox(height: Space.m),
              ],
              if (state.isInstalling) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    state.phase == UpdatePhase.downloading && fraction != null
                        ? '$progressLabel ${(fraction * 100).floor()} %'
                        : progressLabel,
                  ),
                ),
                const SizedBox(height: Space.s),
                LinearProgressIndicator(
                  value: state.phase == UpdatePhase.downloading ? fraction : null,
                ),
                const SizedBox(height: Space.m),
              ],
              if (available && !canInstall && !external && !state.isInstalling) ...[
                Text(t.updateBusyBody, style: context.text.caption),
                const SizedBox(height: Space.m),
              ],
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  if (!widget.offer)
                    FluentButton(
                      label: t.setCheckUpdates,
                      loading: state.phase == UpdatePhase.checking,
                      onPressed: state.busy || state.phase == UpdatePhase.permissionRequired
                          ? null
                          : controller.checkNow,
                    ),
                  if (available && !state.isInstalling)
                    FluentButton.primary(
                      label: external
                          ? t.updateInstructions
                          : state.phase == UpdatePhase.permissionRequired
                          ? t.updateContinue
                          : t.updateInstall,
                      onPressed: state.busy || (!external && !canInstall)
                          ? null
                          : external
                          ? () => _open(release!.url)
                          : controller.install,
                    ),
                  if (state.canCancel)
                    FluentButton(
                      label: state.phase == UpdatePhase.permissionRequired
                          ? t.cancel
                          : t.updateCancelDownload,
                      onPressed: controller.cancelDownload,
                    ),
                  if (available && !external)
                    FluentButton.subtle(
                      label: t.updateDetails,
                      onPressed: () => _open(release!.url),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
