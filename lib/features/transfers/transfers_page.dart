import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import 'guest_share_dialog.dart';
import 'transfers_desktop.dart';
import 'transfers_mobile.dart';

/// Transfers section. Below 600 px it is the phone's main screen (received /
/// sent lists and "Send to PC"); wider, the desktop drop zones. Arriving at
/// `/transfers?guest=1` opens "Share with anyone" straight away.
class TransfersPage extends ConsumerStatefulWidget {
  const TransfersPage({super.key});

  /// Width under which the phone layout is used.
  static const double compactBreakpoint = 600;

  @override
  ConsumerState<TransfersPage> createState() => _TransfersPageState();
}

class _TransfersPageState extends ConsumerState<TransfersPage> {
  GoRouter? _router;
  String? _handledGuestUri;
  bool _dialogOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (!identical(router, _router)) {
      _router?.routerDelegate.removeListener(_onRoute);
      _router = router;
      router?.routerDelegate.addListener(_onRoute);
      WidgetsBinding.instance.addPostFrameCallback((_) => _onRoute());
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  void _onRoute() {
    final router = _router;
    if (router == null || !mounted) return;
    final uri = router.state.uri;
    final wantsGuest = uri.path == AppRoutes.transfers && uri.queryParameters['guest'] == '1';
    if (!wantsGuest) {
      _handledGuestUri = null;
      return;
    }
    final key = uri.toString();
    if (_handledGuestUri == key || _dialogOpen) return;
    _handledGuestUri = key;
    _openGuestShare();
  }

  Future<void> _openGuestShare() async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    try {
      await GuestShareDialog.show(context);
    } finally {
      _dialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < TransfersPage.compactBreakpoint
          ? const TransfersMobile()
          : TransfersDesktop(onShareWithAnyone: _openGuestShare),
    );
  }
}
