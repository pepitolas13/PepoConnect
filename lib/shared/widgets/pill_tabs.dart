import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../motion/pressable.dart';
import '../theme/tokens.dart';

/// Segmented pills like Unison's "Fotos | Vídeos | Todo". All pills share
/// the width of the widest label; the selected pill slides between
/// positions with the emphasized curve.
class PillTabs extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
    this.height = 32,
  });

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final motion = Motion.of(context);
    final radius = BorderRadius.circular(height / 2);
    final count = tabs.length;
    final selected = index.clamp(0, count - 1);
    final alignX = count <= 1 ? 0.0 : -1 + 2 * selected / (count - 1);
    final boldWidths = [
      for (final label in tabs)
        (TextPainter(
          text: TextSpan(text: label, style: text.bodyStrong),
          textDirection: Directionality.of(context),
          maxLines: 1,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout()).width,
    ];
    return Container(
      height: height,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colors.controlFill,
        borderRadius: radius,
        border: Border.all(color: colors.controlStroke),
      ),
      child: IntrinsicWidth(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedAlign(
                duration: motion.normal,
                curve: Motion.emphasized,
                alignment: Alignment(alignX, 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / count,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.isDark ? const Color(0x14FFFFFF) : const Color(0xFFFFFFFF),
                      borderRadius: radius,
                      border: Border.all(color: colors.cardStroke),
                      boxShadow: const [
                        BoxShadow(color: Color(0x0F000000), offset: Offset(0, 1), blurRadius: 2),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < count; i++)
                  Expanded(
                    child: Semantics(
                      selected: i == selected,
                      child: Pressable(
                        onTap: () => onChanged(i),
                        borderRadius: radius,
                        showHoverFill: i != selected,
                        showPressedOverlay: false,
                        scaleOnPress: false,
                        semanticLabel: tabs[i],
                        builder: (context, states, _) => Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: Space.l),
                          // Reserve the bold width so the control does not
                          // grow when the selection moves to another tab.
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: boldWidths[i]),
                            child: AnimatedDefaultTextStyle(
                              duration: motion.fast,
                              textAlign: TextAlign.center,
                              style: (i == selected ? text.bodyStrong : text.body).copyWith(
                                color: i == selected
                                    ? colors.textPrimary
                                    : states.pressed
                                    ? colors.textTertiary
                                    : colors.textSecondary,
                              ),
                              child: Text(
                                tabs[i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
