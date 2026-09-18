import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../../shared/i18n/l10n.dart';
import '../../shared/motion/motion.dart';
import '../../shared/motion/pressable.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/fluent_button.dart';
import '../../shared/widgets/thin_progress_bar.dart';

/// One line of the bottom transfer bar.
@immutable
class TransferRow {
  const TransferRow({
    required this.id,
    required this.label,
    required this.progress,
    this.paused = false,
    this.onCancel,
  });

  final int id;

  /// "68 % enviado a GeorGY".
  final String label;

  /// 0..1, or null while queued.
  final double? progress;
  final bool paused;
  final VoidCallback? onCancel;
}

/// Thin progress strip docked under the content, like Unison's
/// "100 % enviado a GeorGY" bar. Collapsed it shows the newest row; the
/// chevron expands the rest.
class TransferStatusBar extends StatelessWidget {
  const TransferStatusBar({
    super.key,
    required this.rows,
    required this.collapsed,
    required this.onToggleCollapsed,
  });

  final List<TransferRow> rows;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final motion = Motion.of(context);
    final t = context.t;
    if (rows.isEmpty) return const SizedBox.shrink();
    final visible = collapsed ? rows.take(1).toList() : rows;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bgLayerAlt,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: AnimatedSize(
        duration: motion.normal,
        curve: Motion.standard,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < visible.length; i++)
              _Row(
                row: visible[i],
                trailing: i == 0 && rows.length > 1
                    ? Pressable(
                        onTap: onToggleCollapsed,
                        semanticLabel: collapsed ? t.transfersActiveCount(rows.length) : t.close,
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (collapsed)
                                Text(
                                  '+${rows.length - 1}',
                                  style: context.text.caption.copyWith(color: colors.textSecondary),
                                ),
                              Icon(
                                collapsed
                                    ? FluentIcons.chevron_up_16_regular
                                    : FluentIcons.chevron_down_16_regular,
                                size: 12,
                                color: colors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row, this.trailing});

  final TransferRow row;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.s, Space.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.paused ? '${row.label} · ${t.transferPaused}' : row.label,
                  style: context.text.caption.copyWith(color: colors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (row.onCancel != null)
                FluentIconButton(
                  icon: FluentIcons.dismiss_12_regular,
                  tooltip: t.cancelTransfer,
                  onPressed: row.onCancel,
                  size: 24,
                  iconSize: 12,
                ),
              ?trailing,
            ],
          ),
          const SizedBox(height: Space.xs),
          Padding(
            padding: const EdgeInsets.only(right: Space.s),
            child: row.progress == null
                ? const ThinProgressBar(value: null)
                : SmoothThinProgressBar(value: row.progress!, collapseOnComplete: false),
          ),
        ],
      ),
    );
  }
}
