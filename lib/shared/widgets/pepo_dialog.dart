import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/tokens.dart';

/// Fluent content dialog: 448 px wide, radius 8, title + content + actions.
class PepoDialog extends StatelessWidget {
  const PepoDialog({
    super.key,
    required this.title,
    this.content,
    this.actions = const [],
    this.width = 448,
    this.contentPadding = const EdgeInsets.fromLTRB(Space.xl, Space.m, Space.xl, Space.xl),
  });

  final String title;
  final Widget? content;

  /// Right-aligned, primary action last.
  final List<Widget> actions;
  final double width;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: MediaQuery.sizeOf(context).height - 48,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.dialogSurface,
              borderRadius: Radii.cardRadius,
              border: Border.all(color: colors.cardStroke),
              boxShadow: PepoShadows.dialog,
            ),
            child: ClipRRect(
              borderRadius: Radii.cardRadius,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, 0),
                    child: Text(title, style: text.subtitle),
                  ),
                  if (content != null)
                    Flexible(
                      child: SingleChildScrollView(
                        padding: contentPadding,
                        child: DefaultTextStyle(style: text.body, child: content!),
                      ),
                    )
                  else
                    const SizedBox(height: Space.xl),
                  if (actions.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(Space.xl),
                      decoration: BoxDecoration(
                        color: colors.isDark ? const Color(0xFF202020) : const Color(0xFFF3F3F3),
                        border: Border(top: BorderSide(color: colors.divider)),
                      ),
                      child: Row(
                        children: [
                          for (var i = 0; i < actions.length; i++) ...[
                            if (i > 0) const SizedBox(width: Space.s),
                            Expanded(child: actions[i]),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows [builder] as a modal dialog: scale 0.96 → 1 + fade (200 ms) over a
/// scrim that fades in 150 ms.
Future<T?> showPepoDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final motion = Motion.of(context);
  final colors = context.pepo;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: colors.isDark ? const Color(0x99000000) : const Color(0x4D000000),
    transitionDuration: motion.normal,
    pageBuilder: (context, animation, secondary) => Builder(builder: builder),
    transitionBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Motion.standard,
        reverseCurve: Motion.exit,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
