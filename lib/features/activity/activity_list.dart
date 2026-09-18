import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_services.dart';
import '../../app/router.dart';
import '../../platform/open_helper.dart';
import '../../shared/i18n/l10n.dart';
import '../../shared/motion/pressable.dart';
import '../../shared/motion/toast.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/util/format.dart';
import '../../shared/widgets/pepo_badge.dart';
import '../../shared/widgets/section_header.dart';
import '../../state/activity.dart';
import '../gallery/thumbnail_lookup.dart';

/// Activity entries of one calendar day, newest first.
@immutable
class ActivityDayGroup {
  const ActivityDayGroup({required this.day, required this.entries});

  /// Midnight (local) of the day.
  final DateTime day;
  final List<ActivityEntry> entries;
}

/// Groups [entries] (expected newest first) by local day, keeping order.
List<ActivityDayGroup> groupActivityByDay(List<ActivityEntry> entries) {
  final order = <DateTime>[];
  final buckets = <DateTime, List<ActivityEntry>>{};
  for (final e in entries) {
    final at = e.at.toLocal();
    final day = DateTime(at.year, at.month, at.day);
    buckets
        .putIfAbsent(day, () {
          order.add(day);
          return <ActivityEntry>[];
        })
        .add(e);
  }
  return [for (final day in order) ActivityDayGroup(day: day, entries: buckets[day]!)];
}

/// "Hoy", "Ayer" or the date.
String activityDayTitle(BuildContext context, DateTime day, {DateTime? now}) {
  final t = context.t;
  final n = now ?? DateTime.now();
  if (day == DateTime(n.year, n.month, n.day)) return t.galleryGroupToday;
  if (day == DateTime(n.year, n.month, n.day - 1)) return t.galleryGroupYesterday;
  return formatDate(day, locale: Localizations.localeOf(context).toString(), now: n);
}

IconData activityIcon(ActivityKind kind) => switch (kind) {
  ActivityKind.newPhoto => FluentIcons.image_20_regular,
  ActivityKind.newVideo => FluentIcons.video_clip_20_regular,
  ActivityKind.received => FluentIcons.arrow_download_20_regular,
  ActivityKind.sent => FluentIcons.arrow_upload_20_regular,
  ActivityKind.failed => FluentIcons.error_circle_20_regular,
  ActivityKind.connected => FluentIcons.plug_connected_20_regular,
  ActivityKind.disconnected => FluentIcons.plug_disconnected_20_regular,
  ActivityKind.paired => FluentIcons.link_20_regular,
  ActivityKind.forgotten => FluentIcons.link_dismiss_20_regular,
  ActivityKind.clipboard => FluentIcons.clipboard_20_regular,
};

/// "Foto nueva en Pixel 8", "Recibido IMG_0142.jpg de Pixel 8"…
String activityText(AppLocalizations t, ActivityEntry e) => switch (e.kind) {
  ActivityKind.newPhoto => t.activityNewPhoto(e.deviceName),
  ActivityKind.newVideo => t.activityNewVideo(e.deviceName),
  ActivityKind.received => t.activityReceived(e.fileName ?? '', e.deviceName),
  ActivityKind.sent => t.activitySent(e.fileName ?? '', e.deviceName),
  ActivityKind.failed => t.activityFailed(e.fileName ?? ''),
  ActivityKind.connected => t.activityConnected(e.deviceName),
  ActivityKind.disconnected => t.activityDisconnected(e.deviceName),
  ActivityKind.paired => t.activityPaired(e.deviceName),
  ActivityKind.forgotten => t.activityForgotten(e.deviceName),
  ActivityKind.clipboard => t.activityClipboard(e.deviceName),
};

/// Second line: file name of a new photo, the error, the copied text.
String? activityDetail(ActivityEntry e) => switch (e.kind) {
  ActivityKind.newPhoto || ActivityKind.newVideo => e.fileName,
  ActivityKind.failed || ActivityKind.clipboard => e.text,
  _ => null,
};

sealed class _Item {
  const _Item();
}

class _Header extends _Item {
  const _Header(this.day);

  final DateTime day;
}

class _Row extends _Item {
  const _Row(this.entry);

  final ActivityEntry entry;
}

/// The activity list grouped by day; [compact] fits the 320 px panel.
class ActivityList extends ConsumerWidget {
  const ActivityList({super.key, required this.entries, this.compact = false});

  final List<ActivityEntry> entries;
  final bool compact;

  VoidCallback? _tapFor(BuildContext context, WidgetRef ref, ActivityEntry e) {
    switch (e.kind) {
      case ActivityKind.newPhoto:
      case ActivityKind.newVideo:
        final id = e.mediaId;
        if (id == null) return null;
        return () => context.push(AppRoutes.viewer(e.deviceId, id));
      case ActivityKind.received:
      case ActivityKind.sent:
        final path = e.path;
        if (path == null) return null;
        return () => OpenHelper.showInFolder(path);
      case ActivityKind.clipboard:
        final text = e.text;
        if (text == null || text.isEmpty) return null;
        return () {
          final toasts = ref.read(toastServiceProvider);
          final title = context.t.toastCopied;
          Clipboard.setData(ClipboardData(text: text)).then((_) {
            toasts.show(ToastData(title: title));
          });
        };
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookup = ref.watch(thumbnailLookupProvider);
    final items = <_Item>[];
    for (final g in groupActivityByDay(entries)) {
      items.add(_Header(g.day));
      items.addAll(g.entries.map(_Row.new));
    }
    return ListView.builder(
      padding: compact
          ? const EdgeInsets.fromLTRB(Space.s, Space.xs, Space.s, Space.l)
          : const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return switch (item) {
          _Header(:final day) => SectionHeader(
            title: activityDayTitle(context, day),
            padding: compact
                ? const EdgeInsets.fromLTRB(Space.s, Space.m, Space.s, Space.xs)
                : const EdgeInsets.fromLTRB(Space.s, Space.l, Space.s, Space.s),
          ),
          _Row(:final entry) => _ActivityRow(
            key: ValueKey(entry.id),
            entry: entry,
            compact: compact,
            thumbnail: entry.mediaId == null ? null : lookup(entry.deviceId, entry.mediaId!),
            onTap: _tapFor(context, ref, entry),
          ),
        };
      },
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    super.key,
    required this.entry,
    required this.compact,
    required this.thumbnail,
    required this.onTap,
  });

  final ActivityEntry entry;
  final bool compact;
  final Uint8List? thumbnail;
  final VoidCallback? onTap;

  /// "hoy, 15:51" / "ayer, 09:12" / "12 de marzo, 20:00": the day header
  /// already names the day, so older rows keep their time too.
  static String _when(BuildContext context, DateTime at, String locale) {
    final t = context.t;
    final local = at.toLocal();
    final now = DateTime.now();
    final day = DateTime(local.year, local.month, local.day);
    final today = DateTime(now.year, now.month, now.day);
    if (day == today || day == DateTime(now.year, now.month, now.day - 1)) {
      return formatDayTime(local, today: t.today, yesterday: t.yesterday, locale: locale, now: now);
    }
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return '${formatDate(local, locale: locale, now: now)}, $time';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final t = context.t;
    final locale = Localizations.localeOf(context).toString();
    final title = activityText(t, entry);
    final detail = activityDetail(entry);
    final when = _when(context, entry.at, locale);
    final critical = entry.kind == ActivityKind.failed;
    final leadingSize = compact ? 32.0 : 40.0;
    final bytes = thumbnail;
    final Widget leading = bytes != null
        ? ClipRRect(
            borderRadius: Radii.controlRadius,
            child: Image.memory(
              bytes,
              width: leadingSize,
              height: leadingSize,
              fit: BoxFit.cover,
              cacheWidth: (leadingSize * 2).round(),
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
          )
        : SizedBox.square(
            dimension: leadingSize,
            child: Center(
              child: Icon(
                activityIcon(entry.kind),
                size: 20,
                color: critical ? colors.critical : colors.textSecondary,
              ),
            ),
          );
    return Pressable(
      onTap: onTap,
      enabled: onTap != null,
      scaleOnPress: false,
      showFocusRing: onTap != null,
      semanticLabel: title,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leading,
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.body.copyWith(color: critical ? colors.critical : null),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (detail != null && detail.isNotEmpty)
                    Text(
                      detail,
                      style: text.caption.copyWith(color: colors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(when, style: text.caption.copyWith(color: colors.textTertiary)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: Space.s, top: 6),
              child: PepoBadge(count: entry.read ? 0 : 1, dot: true),
            ),
          ],
        ),
      ),
    );
  }
}
