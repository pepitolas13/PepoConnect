import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart';

import '../../platform/desktop_integration.dart';
import '../../shared/i18n/l10n.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/fluent_button.dart';
import '../../shared/widgets/pepo_checkbox.dart';
import '../../shared/widgets/pepo_dialog.dart';
import '../../state/app_settings.dart';
import 'update_controller.dart';
import 'update_controls.dart';
import 'update_providers.dart';

/// Runs checks for the whole app and only offers an update in a visible,
/// foreground window after onboarding, without stacking over another dialog.
class UpdatePromptHost extends ConsumerStatefulWidget {
  const UpdatePromptHost({super.key, required this.navigatorKey, required this.child});
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  @override
  ConsumerState<UpdatePromptHost> createState() => _UpdatePromptHostState();
}

class _UpdatePromptHostState extends ConsumerState<UpdatePromptHost>
    with WidgetsBindingObserver, WindowListener {
  late final UpdateController _controller;
  Timer? _offerTimer;
  bool _scheduled = false;
  bool _presenting = false;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(updateControllerProvider);
    _controller.addListener(_considerOffer);
    WidgetsBinding.instance.addObserver(this);
    if (DesktopIntegration.isSupported) windowManager.addListener(this);
    ref.listenManual(settingsProvider, (_, _) => _considerOffer());
    _offerTimer = Timer.periodic(const Duration(minutes: 1), (_) => _considerOffer());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.start();
      _considerOffer();
    });
  }

  bool get _eligible {
    if (!mounted || _presenting) return false;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return false;
    final settings = ref.read(settingsProvider);
    return settings.onboarded &&
        _controller.shouldPrompt(notificationsEnabled: settings.updateNotifications);
  }

  void _considerOffer() {
    if (_scheduled || !_eligible) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_eligible) unawaited(_showOffer());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _showOffer() async {
    final foreground = ref.read(updateForegroundProvider);
    _presenting = true;
    try {
      if (!await foreground() || !mounted) return;
      final settings = ref.read(settingsProvider);
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if ((lifecycle != null && lifecycle != AppLifecycleState.resumed) ||
          !settings.onboarded ||
          !_controller.shouldPrompt(notificationsEnabled: settings.updateNotifications)) {
        return;
      }
      final navigator = widget.navigatorKey.currentState;
      final dialogContext = navigator?.overlay?.context;
      if (navigator == null ||
          dialogContext == null ||
          !dialogContext.mounted ||
          navigator.canPop()) {
        return;
      }
      final offeredVersion = _controller.state.release!.latest;
      final closed = showPepoDialog<void>(
        dialogContext,
        builder: (_) => const _UpdateOfferDialog(),
      );
      // Persist only after pushing the route, with no asynchronous gap between
      // the visibility/modal checks and the push itself.
      unawaited(_controller.markNotified(offeredVersion));
      await closed;
    } catch (error) {
      Logger('Updates').fine('Foreground update offer deferred', error);
    } finally {
      _presenting = false;
    }
  }

  void _resumed() {
    unawaited(_controller.resumed());
    _considerOffer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _resumed();
  }

  @override
  void onWindowFocus() => _resumed();

  @override
  void onWindowRestore() => _resumed();

  @override
  void dispose() {
    _offerTimer?.cancel();
    _controller.stop();
    _controller.removeListener(_considerOffer);
    WidgetsBinding.instance.removeObserver(this);
    if (DesktopIntegration.isSupported) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _UpdateOfferDialog extends ConsumerWidget {
  const _UpdateOfferDialog();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final controller = ref.watch(updateControllerProvider);
    final notifications = ref.watch(settingsProvider).updateNotifications;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.l),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => PepoDialog(
          title: t.setUpdateAvailable(controller.state.release!.latest),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const UpdateControls(offer: true),
              const SizedBox(height: Space.l),
              Row(
                children: [
                  PepoCheckbox(
                    value: !notifications,
                    semanticLabel: t.updateDontNotify,
                    onChanged: (value) => ref
                        .read(settingsProvider.notifier)
                        .update((s) => s.copyWith(updateNotifications: !value)),
                  ),
                  const SizedBox(width: Space.s),
                  Expanded(child: Text(t.updateDontNotify)),
                ],
              ),
            ],
          ),
          actions: [
            FluentButton(
              label: controller.state.isInstalling ? t.close : t.updateLater,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
