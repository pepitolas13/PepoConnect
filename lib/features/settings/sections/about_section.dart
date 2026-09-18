import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/open_helper.dart';
import '../../../shared/i18n/l10n.dart';
import '../../../shared/motion/fade_slide_switcher.dart';
import '../../../shared/motion/toast.dart';
import '../../../shared/theme/tokens.dart';
import '../../../shared/widgets/fluent_button.dart';
import '../../../shared/widgets/info_bar.dart';
import '../../../shared/widgets/pepo_card.dart';
import '../../../shared/widgets/pepo_logo.dart';
import '../settings_providers.dart';
import '../settings_widgets.dart';
import '../update_checker.dart';

/// Logo, version, device id, update check, repository link and reset.
class AboutSection extends ConsumerStatefulWidget {
  const AboutSection({super.key});

  @override
  ConsumerState<AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends ConsumerState<AboutSection> {
  bool _checking = false;
  UpdateCheckResult? _result;
  bool _failed = false;

  Future<void> _copyId(String id) async {
    final t = context.t;
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    ToastService.maybeOf(context)?.show(ToastData(title: t.toastCopied, message: id));
  }

  Future<void> _check(String current) async {
    setState(() {
      _checking = true;
      _failed = false;
      _result = null;
    });
    UpdateCheckResult? result;
    var failed = false;
    try {
      result = await checkForUpdates(currentVersion: current);
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _result = result;
      _failed = failed;
    });
  }

  Future<void> _reset() async {
    final t = context.t;
    final ok = await showConfirmDialog(
      context,
      title: t.setResetConfirm,
      body: t.setResetBody,
      confirmLabel: t.resetSettings,
    );
    if (!ok || !mounted) return;
    await ref.read(settingsActionsProvider).resetAll();
    if (!mounted) return;
    ToastService.maybeOf(context)
        ?.show(ToastData(title: t.setResetDone, severity: ToastSeverity.success));
  }

  Widget? _updateBar() {
    final t = context.t;
    if (_failed) {
      return InfoBar(
        key: const ValueKey('failed'),
        severity: InfoBarSeverity.critical,
        title: t.setUpdateFailed,
        message: t.setUpdateFailedBody,
        onClose: () => setState(() => _failed = false),
      );
    }
    final r = _result;
    if (r == null) return null;
    if (r.isNewer) {
      return InfoBar(
        key: const ValueKey('newer'),
        title: t.setUpdateAvailable(r.latest),
        action: FluentButton.subtle(
          label: t.setViewOnGitHub,
          size: FluentButtonSize.small,
          trailingIcon: FluentIcons.open_16_regular,
          onPressed: () => OpenHelper.openUrl(r.url),
        ),
        onClose: () => setState(() => _result = null),
      );
    }
    return InfoBar(
      key: const ValueKey('latest'),
      severity: InfoBarSeverity.success,
      title: t.setUpToDate,
      onClose: () => setState(() => _result = null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = context.pepo;
    final text = context.text;
    final facts = ref.watch(localDeviceFactsProvider);
    final bar = _updateBar();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PepoCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PepoLogo(size: 56),
              const SizedBox(width: Space.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.appName, style: text.subtitle),
                    Text(
                      t.version(facts.appVersion),
                      style: text.caption.copyWith(color: colors.textSecondary),
                    ),
                    const SizedBox(height: Space.s),
                    Text(t.aboutBody, style: text.body.copyWith(color: colors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.m),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: FluentIcons.phone_desktop_24_regular,
              title: t.setDeviceId,
              description: facts.shortId,
              trailing: FluentIconButton(
                icon: FluentIcons.copy_20_regular,
                tooltip: t.copy,
                onPressed: () => _copyId(facts.shortId),
              ),
            ),
            SettingsRow(
              icon: FluentIcons.flash_24_regular,
              title: t.setFastLane,
              description: facts.fastLanePort > 0
                  ? t.setFastLaneOn(facts.fastLanePort)
                  : t.setFastLaneOff,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsRow(
                  icon: FluentIcons.arrow_sync_20_regular,
                  title: t.setCheckUpdates,
                  description: t.version(facts.appVersion),
                  trailing: FluentButton(
                    label: t.setCheckUpdates,
                    loading: _checking,
                    onPressed: () => _check(facts.appVersion),
                  ),
                ),
                FadeSlideSwitcher(
                  child: bar == null
                      ? const SizedBox.shrink(key: ValueKey('none'))
                      : Padding(
                          key: bar.key,
                          padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.m),
                          child: bar,
                        ),
                ),
              ],
            ),
            SettingsRow(
              icon: FluentIcons.globe_20_regular,
              title: t.setSourceCode,
              description: repositoryUrl,
              trailing: FluentButton(
                icon: FluentIcons.open_16_regular,
                label: t.open,
                onPressed: () => OpenHelper.openUrl(repositoryUrl),
              ),
            ),
            SettingsRow(
              icon: FluentIcons.arrow_reset_20_regular,
              title: t.resetSettings,
              description: t.setResetBody,
              trailing: FluentButton(label: t.resetSettings, onPressed: _reset),
            ),
          ],
        ),
      ],
    );
  }
}
