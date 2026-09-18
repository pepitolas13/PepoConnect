import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pepo_core/pepo_core.dart' show DeviceView, PairedDevice;

import '../../app/bootstrap.dart';
import '../../app/router.dart';
import '../../state/app_settings.dart';
import '../../state/engine_providers.dart';
import 'desktop_pairing.dart';
import 'mobile_pairing.dart';
import 'pairing_done.dart';

/// `/pair`: the hub shows a QR or code (desktop), the phone scans it. Ends
/// on "Paired" as soon as a new device shows up in the device list, or when
/// the initiating side gets the device back directly.
class PairingPage extends ConsumerStatefulWidget {
  const PairingPage({super.key, this.mobile});

  /// Forces the phone or desktop variant (defaults to the running platform).
  final bool? mobile;

  @override
  ConsumerState<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends ConsumerState<PairingPage> {
  late final bool _mobile = widget.mobile ?? !isDesktop;
  final DateTime _openedAt = DateTime.now();
  late final Set<String> _known;
  PairedDevice? _paired;

  @override
  void initState() {
    super.initState();
    _known = ref.read(devicesProvider).map((d) => d.deviceId).toSet();
  }

  /// A device that was not there when the page opened, and was paired
  /// recently, is the one we were waiting for. The time check guards
  /// against the list still loading when the page opened.
  void _onDevices(List<DeviceView>? previous, List<DeviceView> next) {
    if (_paired != null) return;
    final threshold = _openedAt.subtract(const Duration(minutes: 1));
    for (final d in next) {
      if (_known.contains(d.deviceId)) continue;
      _known.add(d.deviceId);
      if (d.device.pairedAt.isAfter(threshold)) {
        _onPaired(d.device);
        return;
      }
    }
  }

  void _onPaired(PairedDevice device) {
    if (_paired != null) return;
    _known.add(device.deviceId);
    setState(() => _paired = device);
  }

  Future<void> _finish() async {
    final device = _paired;
    if (device == null) return;
    await ref
        .read(settingsProvider.notifier)
        .update(
          (s) => s.copyWith(
            onboarded: true,
            defaultHubId: _mobile && s.defaultHubId == null ? device.deviceId : null,
          ),
        );
    if (!mounted) return;
    context.go(_mobile ? AppRoutes.transfers : AppRoutes.gallery);
  }

  /// Drops the invitation this PC is showing. Called from user actions
  /// (never from dispose: providers must not change during teardown).
  void _cancelInvite() {
    if (ref.read(pairingProvider) != null) ref.read(pairingProvider.notifier).cancel();
  }

  void _leave() {
    _cancelInvite();
    if (context.canPop()) {
      context.pop();
      return;
    }
    final done = ref.read(settingsProvider).onboarded || ref.read(devicesProvider).isNotEmpty;
    context.go(done ? AppRoutes.transfers : AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<DeviceView>>(devicesProvider, _onDevices);
    final paired = _paired;
    final Widget body;
    if (paired != null) {
      body = PairingDoneView(device: paired, onStart: _finish);
    } else if (_mobile) {
      body = MobilePairingView(onPaired: _onPaired, onClose: _leave);
    } else {
      body = DesktopPairingView(onPaired: _onPaired, onClose: _leave);
    }
    // System back / Esc: the invitation goes with the page.
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _cancelInvite();
      },
      child: body,
    );
  }
}
