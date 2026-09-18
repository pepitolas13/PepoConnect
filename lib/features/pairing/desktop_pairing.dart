import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pepo_core/pepo_core.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../platform/open_helper.dart';
import '../../shared/i18n/l10n.dart';
import '../../shared/motion/fade_slide_switcher.dart';
import '../../shared/motion/progress_ring.dart';
import '../../shared/motion/skeleton.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/device_icon.dart';
import '../../shared/widgets/fluent_button.dart';
import '../../shared/widgets/info_bar.dart';
import '../../shared/widgets/pepo_card.dart';
import '../../shared/widgets/pepo_text_field.dart';
import '../../shared/widgets/section_header.dart';
import '../../state/engine_providers.dart';
import '../settings/update_checker.dart' show releasesPageUrl;
import 'invite_countdown.dart';
import 'pairing_helpers.dart';

enum _Stage { qr, code, otherPc }

/// Hub side: show a QR (or a six-digit code) for a phone to scan, or dial
/// another PC that is showing its code. Pairing completes on the parent,
/// which watches the device list.
class DesktopPairingView extends ConsumerStatefulWidget {
  const DesktopPairingView({super.key, required this.onPaired, required this.onClose});

  final ValueChanged<PairedDevice> onPaired;
  final VoidCallback onClose;

  @override
  ConsumerState<DesktopPairingView> createState() => _DesktopPairingViewState();
}

class _DesktopPairingViewState extends ConsumerState<DesktopPairingView> {
  late final PairingNotifier _pairing;
  _Stage _stage = _Stage.qr;
  bool _starting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pairing = ref.read(pairingProvider.notifier);
    _starting = true;
    unawaited(_run(_pairing.startQr));
  }

  Future<void> _run(Future<PairingInvite> Function() start) async {
    Object? failure;
    try {
      await start();
    } catch (e) {
      failure = e;
    }
    if (!mounted) return;
    setState(() {
      _starting = false;
      _error = failure == null ? null : describePairingError(failure, context.t);
    });
  }

  /// A new invitation for the current stage (expired or on demand).
  void _restart() {
    if (_starting || _stage == _Stage.otherPc) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    unawaited(_run(_stage == _Stage.qr ? _pairing.startQr : _pairing.startCode));
  }

  void _switch(_Stage stage) {
    if (stage == _stage) return;
    setState(() {
      _stage = stage;
      _error = null;
    });
    if (stage == _Stage.otherPc) {
      _pairing.cancel();
      return;
    }
    _restart();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // The engine drops the invitation when it is used up (too many bad
    // attempts) and the countdown asks for a new one when it expires; in
    // between the stages show "expired" with the regenerate button.
    final invite = ref.watch(pairingProvider);
    final Widget stage = switch (_stage) {
      _Stage.qr => _QrStage(
        key: const ValueKey('qr'),
        invite: invite?.mode == PairingMode.qr ? invite : null,
        starting: _starting,
        error: _error,
        onRegenerate: _restart,
      ),
      _Stage.code => _CodeStage(
        key: const ValueKey('code'),
        invite: invite?.mode == PairingMode.manualCode ? invite : null,
        starting: _starting,
        error: _error,
        onRegenerate: _restart,
      ),
      _Stage.otherPc => OtherPcPairingView(key: const ValueKey('other'), onPaired: widget.onPaired),
    };
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Space.xl, Space.xxl, Space.xl, Space.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PageTitle(
                        title: _stage == _Stage.otherPc ? t.pairOtherPc : t.pairTitle,
                        subtitle: t.pairSubtitle,
                        padding: const EdgeInsets.only(bottom: Space.xl),
                      ),
                      FadeSlideSwitcher(child: stage),
                      const SizedBox(height: Space.xl),
                      Wrap(
                        spacing: Space.s,
                        runSpacing: Space.xs,
                        alignment: WrapAlignment.center,
                        children: [
                          if (_stage != _Stage.qr)
                            FluentButton.subtle(
                              icon: FluentIcons.qr_code_24_regular,
                              label: t.pairUseQr,
                              onPressed: () => _switch(_Stage.qr),
                            ),
                          if (_stage != _Stage.code)
                            FluentButton.subtle(
                              icon: FluentIcons.keyboard_20_regular,
                              label: t.pairUseCode,
                              onPressed: () => _switch(_Stage.code),
                            ),
                          if (_stage != _Stage.otherPc)
                            FluentButton.subtle(
                              icon: FluentIcons.desktop_20_regular,
                              label: t.pairOtherPc,
                              onPressed: () => _switch(_Stage.otherPc),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: Space.s,
              left: Space.s,
              child: FluentButton.subtle(
                icon: FluentIcons.arrow_left_20_regular,
                label: t.back,
                onPressed: widget.onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Numbered circle like Unison's steps.
class _StepNumber extends StatelessWidget {
  const _StepNumber(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
      child: Text('$number', style: context.text.bodyStrong.copyWith(color: colors.onAccent)),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.child});

  final int number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(label: t.pairStepNumber(number), child: _StepNumber(number)),
        const SizedBox(width: Space.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(title, style: context.text.bodyStrong),
              ),
              const SizedBox(height: Space.m),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

/// Step 1 (install the app) and step 2 (scan the QR), with the countdown.
class _QrStage extends StatelessWidget {
  const _QrStage({
    super.key,
    required this.invite,
    required this.starting,
    required this.error,
    required this.onRegenerate,
  });

  final PairingInvite? invite;

  /// A new invitation is on its way.
  final bool starting;
  final String? error;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final expired = invite == null && !starting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Step(
          number: 1,
          title: t.pairInstallTitle,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FluentButton(
              icon: FluentIcons.arrow_download_16_regular,
              label: t.pairDownloadApp,
              onPressed: () => OpenHelper.openUrl(releasesPageUrl),
            ),
          ),
        ),
        const SizedBox(height: Space.xl),
        _Step(
          number: 2,
          title: t.pairScanStep,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              QrFrame(
                data: invite?.qrText,
                placeholder: expired ? const _ExpiredPlaceholder() : null,
              ),
              const SizedBox(height: Space.m),
              Wrap(
                spacing: Space.m,
                runSpacing: Space.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  InviteCountdown(expiresAt: invite?.expiresAt, onExpired: onRegenerate),
                  FluentButton.subtle(
                    icon: FluentIcons.arrow_sync_16_regular,
                    label: t.pairGenerateAnother,
                    size: FluentButtonSize.small,
                    onPressed: onRegenerate,
                  ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: Space.m),
                InfoBar(severity: InfoBarSeverity.critical, title: t.pairFailed, message: error),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The QR on a white card with a rounded accent border, always dark on
/// white so any camera reads it.
class QrFrame extends StatelessWidget {
  const QrFrame({super.key, required this.data, this.placeholder, this.size = 232});

  /// Null while there is no invitation to show.
  final String? data;

  /// Shown instead of the spinner when [data] is null.
  final Widget? placeholder;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = data;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Radii.dropZone),
        border: Border.all(color: colors.accent, width: 2),
      ),
      child: text == null
          ? Center(child: placeholder ?? const ProgressRing(size: 28))
          : QrImageView(
              data: text,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF000000)),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF000000),
              ),
            ),
    );
  }
}

/// Inside the QR frame once the invitation is gone.
class _ExpiredPlaceholder extends StatelessWidget {
  const _ExpiredPlaceholder();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(FluentIcons.history_24_regular, size: 32, color: Color(0xFF616161)),
        const SizedBox(height: Space.s),
        Text(
          t.pairExpired,
          style: context.text.body.copyWith(color: const Color(0xFF616161)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Six-digit code, this PC's address and where to type it.
class _CodeStage extends StatelessWidget {
  const _CodeStage({
    super.key,
    required this.invite,
    required this.starting,
    required this.error,
    required this.onRegenerate,
  });

  final PairingInvite? invite;

  /// A new invitation is on its way.
  final bool starting;
  final String? error;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = context.pepo;
    final text = context.text;
    final code = invite?.code;
    final addresses = invite?.addresses ?? const [];
    final port = invite?.port ?? 0;
    final expired = invite == null && !starting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Step(
          number: 1,
          title: t.pairEnterCodeTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PepoCard(
                padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (expired)
                      Text(t.pairExpired, style: text.bodyLarge.copyWith(color: colors.caution))
                    else if (code == null)
                      const Skeleton(width: 220, height: 52)
                    else
                      Text(
                        groupCode(code),
                        style: text.titleLarge.copyWith(
                          letterSpacing: 6,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        semanticsLabel: code.split('').join(' '),
                      ),
                    const SizedBox(height: Space.s),
                    if (expired)
                      const SizedBox.shrink()
                    else if (addresses.isEmpty)
                      const Skeleton(width: 180, height: 14)
                    else ...[
                      Text(t.pairYourPc('${addresses.first}:$port'), style: text.body),
                      if (addresses.length > 1)
                        Text(
                          addresses.skip(1).map((a) => '$a:$port').join('  ·  '),
                          style: text.caption.copyWith(color: colors.textSecondary),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: Space.m),
              Text(t.pairCodeHint, style: text.body.copyWith(color: colors.textSecondary)),
              const SizedBox(height: Space.m),
              Wrap(
                spacing: Space.m,
                runSpacing: Space.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  InviteCountdown(expiresAt: invite?.expiresAt, onExpired: onRegenerate),
                  FluentButton.subtle(
                    icon: FluentIcons.arrow_sync_16_regular,
                    label: t.pairGenerateAnother,
                    size: FluentButtonSize.small,
                    onPressed: onRegenerate,
                  ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: Space.m),
                InfoBar(severity: InfoBarSeverity.critical, title: t.pairFailed, message: error),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Dial another PC: pick it from the network (or type its address) and
/// enter the six digits it shows.
class OtherPcPairingView extends ConsumerStatefulWidget {
  const OtherPcPairingView({super.key, required this.onPaired});

  final ValueChanged<PairedDevice> onPaired;

  @override
  ConsumerState<OtherPcPairingView> createState() => _OtherPcPairingViewState();
}

class _OtherPcPairingViewState extends ConsumerState<OtherPcPairingView> {
  final TextEditingController _address = TextEditingController();
  final TextEditingController _code = TextEditingController();
  PeerCandidate? _selected;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_busy && _code.text.length == 6 && (_selected != null || _address.text.trim().isNotEmpty);

  Future<void> _submit() async {
    final t = context.t;
    final code = _code.text.trim();
    if (!ManualCode.isValid(code)) {
      setState(() => _error = t.pairCodeInvalid);
      return;
    }
    final candidate = _selected;
    String? host;
    int? port;
    if (candidate == null) {
      final parsed = parseHostPort(_address.text);
      if (parsed == null) {
        setState(() => _error = t.pairAddressInvalid);
        return;
      }
      host = parsed.host;
      port = parsed.port;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final device = await ref
          .read(pairingProvider.notifier)
          .pairWithCode(code: code, candidate: candidate, host: host, port: port);
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onPaired(device);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = describePairingError(e, context.t, codeFlow: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = context.pepo;
    final text = context.text;
    final found = (ref.watch(discoveredDevicesProvider).value ?? const <PeerCandidate>[])
        .where((c) => c.addresses.isNotEmpty)
        .toList();
    if (_selected != null && !found.any((c) => c.deviceId == _selected!.deviceId)) {
      _selected = null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.pairSelectPc, style: text.bodyStrong),
        const SizedBox(height: Space.s),
        if (found.isEmpty)
          PepoCard(
            child: Row(
              children: [
                const ProgressRing(size: 16, strokeWidth: 2),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Text(
                    t.pairSearching,
                    style: text.body.copyWith(color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          )
        else
          for (final c in found)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: PepoCard(
                selected: c.deviceId == _selected?.deviceId,
                padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
                onTap: () => setState(() {
                  _selected = c;
                  _error = null;
                }),
                child: Row(
                  children: [
                    DeviceIcon.fromPlatform(c.platform, size: 24),
                    const SizedBox(width: Space.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name.isEmpty ? t.unknownDevice : c.name,
                            style: text.bodyStrong,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            [
                              platformLabel(c.platform),
                              '${c.addresses.first}:${c.port}',
                            ].where((s) => s.isNotEmpty).join(' · '),
                            style: text.caption.copyWith(color: colors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (c.deviceId == _selected?.deviceId)
                      Icon(FluentIcons.checkmark_circle_20_filled, size: 20, color: colors.accent),
                  ],
                ),
              ),
            ),
        const SizedBox(height: Space.m),
        PepoTextField(
          controller: _address,
          label: t.pairManual,
          placeholder: '192.168.1.20:47473',
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {
            _selected = null;
            _error = null;
          }),
        ),
        const SizedBox(height: Space.l),
        PepoTextField(
          controller: _code,
          label: t.pairEnterCode,
          placeholder: '123456',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 6,
          textAlign: TextAlign.center,
          style: text.bodyLarge.copyWith(
            letterSpacing: 8,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) {
            if (_canSubmit) _submit();
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: Space.m),
          InfoBar(
            severity: InfoBarSeverity.critical,
            title: t.pairFailed,
            message: _error,
            onClose: () => setState(() => _error = null),
          ),
        ],
        const SizedBox(height: Space.l),
        Align(
          alignment: Alignment.centerRight,
          child: FluentButton.primary(
            label: t.pairConnect,
            loading: _busy,
            onPressed: _canSubmit ? _submit : null,
          ),
        ),
      ],
    );
  }
}
