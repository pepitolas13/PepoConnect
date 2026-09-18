import 'package:flutter/material.dart';

import '../../shared/motion/motion.dart';
import '../../shared/motion/pressable.dart';
import '../../shared/theme/tokens.dart';
import '../../shared/widgets/pepo_badge.dart';
import 'nav_rail.dart';

/// Compact-width navigation: four equal tiles, 24 px icon, 12 px label.
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<NavItem> items;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final motion = Motion.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bgLayerAlt,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == selectedIndex,
                    child: Pressable(
                      onTap: () => onSelected(i),
                      semanticLabel: items[i].label,
                      showHoverFill: false,
                      builder: (context, states, _) {
                        final selected = i == selectedIndex;
                        final color = selected
                            ? colors.accent
                            : states.pressed
                            ? colors.textTertiary
                            : colors.textSecondary;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Badged(
                              count: items[i].badge,
                              child: AnimatedSwitcher(
                                duration: motion.fast,
                                child: Icon(
                                  selected ? items[i].selectedIcon : items[i].icon,
                                  key: ValueKey(selected),
                                  size: Sizes.iconLarge,
                                  color: color,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              items[i].label,
                              style: context.text.caption.copyWith(color: color),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
