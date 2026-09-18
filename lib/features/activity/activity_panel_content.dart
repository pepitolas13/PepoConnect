import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/i18n/l10n.dart';
import '../../shared/widgets/empty_state.dart';
import '../../state/engine_providers.dart';
import 'activity_list.dart';
import 'activity_page.dart';

/// The list inside the docked 320 px activity panel (the shell draws the
/// frame). It is only built while the panel is open, so being mounted means
/// being visible: everything is marked read shortly after it appears.
class ActivityPanelContent extends ConsumerStatefulWidget {
  const ActivityPanelContent({super.key});

  @override
  ConsumerState<ActivityPanelContent> createState() => _ActivityPanelContentState();
}

class _ActivityPanelContentState extends ConsumerState<ActivityPanelContent> {
  Timer? _readTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleMarkRead());
  }

  @override
  void dispose() {
    _readTimer?.cancel();
    super.dispose();
  }

  void _scheduleMarkRead() {
    if (!mounted) return;
    if (ref.read(activityProvider).every((a) => a.read)) return;
    _readTimer ??= Timer(ActivityPage.markReadDelay, () {
      _readTimer = null;
      if (mounted) ref.read(activityProvider.notifier).markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(activityProvider);
    ref.listen(activityProvider, (_, _) => _scheduleMarkRead());
    if (entries.isEmpty) {
      return EmptyState(
        icon: FluentIcons.alert_24_regular,
        title: context.t.activityEmpty,
        compact: true,
      );
    }
    return ActivityList(entries: entries, compact: true);
  }
}
