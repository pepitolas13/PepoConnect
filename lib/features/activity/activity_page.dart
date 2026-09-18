import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../shared/i18n/l10n.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fluent_button.dart';
import '../../state/engine_providers.dart';
import 'activity_list.dart';

/// Activity as a full section (phone, and desktop widths where the side
/// panel is not docked). Marks everything read shortly after being shown.
class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});

  /// Unread dots stay visible this long before everything is marked read.
  static const Duration markReadDelay = Duration(milliseconds: 1500);

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage> {
  GoRouter? _router;
  Timer? _readTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleMarkRead());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (!identical(router, _router)) {
      _router?.routerDelegate.removeListener(_onRoute);
      _router = router;
      router?.routerDelegate.addListener(_onRoute);
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRoute);
    _readTimer?.cancel();
    super.dispose();
  }

  /// The branch lives in an indexed stack, so "visible" means the router is
  /// on `/activity` (or there is no router at all).
  bool get _visible {
    final router = _router;
    if (router == null) return true;
    return router.state.uri.path == AppRoutes.activity;
  }

  void _onRoute() => _scheduleMarkRead();

  void _scheduleMarkRead() {
    if (!mounted || !_visible) return;
    if (ref.read(activityProvider).every((a) => a.read)) return;
    _readTimer ??= Timer(ActivityPage.markReadDelay, () {
      _readTimer = null;
      if (mounted && _visible) ref.read(activityProvider.notifier).markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final t = context.t;
    final entries = ref.watch(activityProvider);
    ref.listen(activityProvider, (_, _) => _scheduleMarkRead());
    final notifier = ref.read(activityProvider.notifier);
    final anyUnread = entries.any((a) => !a.read);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xl, Space.l, Space.l, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.activityTitle,
                    style: text.subtitle.copyWith(color: colors.textPrimary),
                  ),
                ),
                if (anyUnread)
                  FluentButton.subtle(
                    label: t.markAllRead,
                    size: FluentButtonSize.small,
                    onPressed: notifier.markAllRead,
                  ),
                if (entries.isNotEmpty) ...[
                  const SizedBox(width: Space.xs),
                  FluentButton.subtle(
                    label: t.clearAll,
                    size: FluentButtonSize.small,
                    onPressed: notifier.clear,
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? EmptyState(icon: FluentIcons.alert_24_regular, title: t.activityEmpty)
                : ActivityList(entries: entries),
          ),
        ],
      ),
    );
  }
}
