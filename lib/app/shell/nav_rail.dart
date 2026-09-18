import 'package:flutter/material.dart';

import '../../shared/motion/motion.dart';
import '../../shared/motion/pressable.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/fluent_tooltip.dart';
import '../../shared/widgets/pepo_badge.dart';

/// One entry of the rail or the bottom bar.
@immutable
class NavItem {
  const NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badge = 0,
    this.tooltip,
    this.shortcut,
  });

  /// 20 px regular glyph.
  final IconData icon;

  /// 20 px filled glyph for the active entry.
  final IconData selectedIcon;
  final String label;
  final int badge;
  final String? tooltip;

  /// Shown after the tooltip, e.g. `Ctrl+1`.
  final String? shortcut;
}

/// Unison-style left rail: 64 px wide, 20 px icon with an 11 px label
/// under it, accent for the active entry, separators around the hub and
/// the footer.
class NavRail extends StatelessWidget {
  const NavRail({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.header,
    this.footer = const [],
    this.footerSelectedIndex,
    this.onFooterSelected,
    this.width = Sizes.railWidth,
  });

  final List<NavItem> items;

  /// Indices of the active main entries (the section, plus "Actividad"
  /// while the side panel is open).
  final Set<int> selected;
  final ValueChanged<int> onSelected;

  /// Hub button slot.
  final Widget? header;
  final List<NavItem> footer;
  final int? footerSelectedIndex;
  final ValueChanged<int>? onFooterSelected;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    return SizedBox(
      width: width,
      child: Column(
        children: [
          if (header != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: Space.s, bottom: Space.xs),
              child: header,
            ),
            _RailDivider(color: colors.divider),
          ],
          const SizedBox(height: Space.xs),
          for (var i = 0; i < items.length; i++)
            NavRailItem(item: items[i], selected: selected.contains(i), onTap: () => onSelected(i)),
          const Spacer(),
          if (footer.isNotEmpty) ...[
            _RailDivider(color: colors.divider),
            const SizedBox(height: Space.xs),
            for (var i = 0; i < footer.length; i++)
              NavRailItem(
                item: footer[i],
                selected: i == footerSelectedIndex,
                onTap: () => onFooterSelected?.call(i),
              ),
            const SizedBox(height: Space.xs),
          ],
        ],
      ),
    );
  }
}

class _RailDivider extends StatelessWidget {
  const _RailDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.m),
    child: Container(height: 1, color: color),
  );
}

/// 56×52 tile: icon on top, label below.
class NavRailItem extends StatelessWidget {
  const NavRailItem({super.key, required this.item, required this.selected, required this.onTap});

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final motion = Motion.of(context);
    final tile = Semantics(
      selected: selected,
      child: Pressable(
        onTap: onTap,
        semanticLabel: item.label,
        builder: (context, states, _) {
          final color = selected
              ? colors.accent
              : states.pressed
              ? colors.textTertiary
              : colors.textSecondary;
          return SizedBox(
            width: 60,
            height: 52,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Badged(
                  count: item.badge,
                  child: AnimatedSwitcher(
                    duration: motion.fast,
                    child: Icon(
                      selected ? item.selectedIcon : item.icon,
                      key: ValueKey(selected),
                      size: Sizes.railIcon,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: Space.xs),
                // Long labels ("Transferencias") shrink a little instead of
                // being cut with an ellipsis.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.label,
                      style: context.text.railLabel.copyWith(color: color),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: item.tooltip == null
          ? tile
          : FluentTooltip(
              message: item.tooltip!,
              shortcut: item.shortcut,
              preferBelow: false,
              child: tile,
            ),
    );
  }
}
