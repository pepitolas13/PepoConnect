import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pepo_core/pepo_core.dart' show PairedDevice, QrPayload;

import '../../platform/pepo_native.dart';
import '../../shared/i18n/l10n.dart';
import '../../shared/motion/progress_ring.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/fluent_button.dart';
import '../../shared/widgets/info_bar.dart';
import '../../shared/widgets/pepo_dialog.dart';
import '../../shared/widgets/pepo_text_field.dart';
import '../../state/engine_providers.dart';
import 'pairing_helpers.dart';

/// Phone side: full-screen camera with a square window, torch, and a way to
/// paste the link by hand. Only built on Android/iOS.
class MobilePairingView extends ConsumerStatefulWidget {
  const MobilePairingView({super.key, required this.onPaired, required this.onClose});

  final ValueChanged<PairedDevice> onPaired;
  final VoidCallback onClose;

  @override
  ConsumerState<MobilePairingView> createState() => _MobilePairingViewState();
}

class _MobilePairingViewState extends ConsumerState<MobilePairingView> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy || _error != null) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.startsWith('${QrPayload.scheme}://')) {
        unawaited(_pair(value));
        return;
      }
    }
  }

  Future<void> _pair(String text) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final device = await ref.read(pairingProvider.notifier).pairWithText(text);
      if (!mounted) return;
      widget.onPaired(device);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = describePairingError(e, context.t);
      });
    }
  }

  Future<void> _enterManually() async {
    final text = await showPepoDialog<String>(context, builder: (_) => const _PasteLinkDialog());
    if (text == null || text.trim().isEmpty || !mounted) return;
    await _pair(text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = context.pepo;
    final text = context.text;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraError(
              error: error,
              onRetry: () => _controller.start(),
              onManual: _enterManually,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ScanWindowPainter(accent: colors.accent)),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Space.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      FluentIconButton(
                        icon: FluentIcons.arrow_left_20_regular,
                        tooltip: t.back,
                        color: Colors.white,
                        iconSize: 20,
                        onPressed: widget.onClose,
                      ),
                      const Spacer(),
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: _controller,
                        builder: (context, state, _) {
                          if (state.torchState == TorchState.unavailable) {
                            return const SizedBox.shrink();
                          }
                          final on = state.torchState == TorchState.on;
                          return FluentIconButton(
                            icon: on
                                ? FluentIcons.flash_off_24_regular
                                : FluentIcons.flash_24_regular,
                            tooltip: t.pairTorch,
                            color: Colors.white,
                            iconSize: 24,
                            selected: on,
                            onPressed: () => _controller.toggleTorch(),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xl),
                  Text(
                    t.pairScanTitle,
                    style: text.subtitle.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    t.pairScanHint,
                    style: text.body.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  if (_error != null)
                    InfoBar(
                      severity: InfoBarSeverity.critical,
                      title: t.pairFailed,
                      message: _error,
                      action: FluentButton.subtle(
                        label: t.retry,
                        size: FluentButtonSize.small,
                        onPressed: () => setState(() => _error = null),
                      ),
                      onClose: () => setState(() => _error = null),
                    )
                  else if (_busy)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xCC1F1F1F),
                        borderRadius: Radii.cardRadius,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(Space.m),
                        child: Row(
                          children: [
                            const ProgressRing(size: 20, color: Colors.white),
                            const SizedBox(width: Space.m),
                            Text(t.pairPairing, style: text.body.copyWith(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: Space.l),
                  FluentButton(
                    icon: FluentIcons.clipboard_paste_20_regular,
                    label: t.pairEnterManually,
                    expand: true,
                    onPressed: _busy ? null : _enterManually,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Camera unavailable: permission help (with a shortcut to the app
/// settings on Android) or a generic retry.
class _CameraError extends StatelessWidget {
  const _CameraError({required this.error, required this.onRetry, required this.onManual});

  final MobileScannerException error;
  final VoidCallback onRetry;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final text = context.text;
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(FluentIcons.camera_24_regular, size: 48, color: Colors.white70),
            const SizedBox(height: Space.l),
            Text(
              denied ? t.pairCameraDenied : t.errorGeneric,
              style: text.subtitle.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.xs),
            Text(
              denied ? t.pairCameraPermission : (error.errorDetails?.message ?? t.errorTryAgain),
              style: text.body.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.xl),
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              alignment: WrapAlignment.center,
              children: [
                if (denied && Platform.isAndroid)
                  FluentButton.primary(
                    label: t.errorPermissionAction,
                    onPressed: () => PepoNative.openAppSettings(),
                  )
                else
                  FluentButton.primary(label: t.retry, onPressed: onRetry),
                FluentButton(label: t.pairEnterManually, onPressed: onManual),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Paste a `pepoconnect://pair/...` link.
class _PasteLinkDialog extends StatefulWidget {
  const _PasteLinkDialog();

  @override
  State<_PasteLinkDialog> createState() => _PasteLinkDialogState();
}

class _PasteLinkDialogState extends State<_PasteLinkDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return PepoDialog(
      title: t.pairEnterManually,
      content: PepoTextField(
        controller: _controller,
        autofocus: true,
        placeholder: t.pairPasteLink,
        keyboardType: TextInputType.url,
        maxLines: 3,
      ),
      actions: [
        FluentButton(label: t.cancel, onPressed: () => Navigator.of(context).pop()),
        FluentButton.primary(
          label: t.pairConnect,
          onPressed: () => Navigator.of(context).pop(_controller.text),
        ),
      ],
    );
  }
}

/// Dark scrim with a square window and accent corners over the camera.
class _ScanWindowPainter extends CustomPainter {
  const _ScanWindowPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height) * 0.68;
    final center = Offset(size.width / 2, size.height * 0.45);
    final window = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: side, height: side),
      const Radius.circular(16),
    );
    final scrim = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(window)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(scrim, Paint()..color = const Color(0x99000000));

    final paint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const length = 28.0;
    final rect = window.outerRect;
    void corner(Offset origin, double dx, double dy) {
      canvas.drawLine(origin, origin + Offset(dx * length, 0), paint);
      canvas.drawLine(origin, origin + Offset(0, dy * length), paint);
    }

    corner(rect.topLeft, 1, 1);
    corner(rect.topRight, -1, 1);
    corner(rect.bottomLeft, 1, -1);
    corner(rect.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(_ScanWindowPainter old) => old.accent != accent;
}
