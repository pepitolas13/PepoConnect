import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Group heading inside lists: "Hoy · 12", with optional leading widget
/// (a check box in the gallery) and trailing actions.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(0, Space.l, 0, Space.s),
  });

  final String title;
  final int? count;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: Space.s)],
          Text(title, style: text.bodyStrong),
          if (count != null) ...[
            Text('  ·  ', style: text.body.copyWith(color: colors.textTertiary)),
            Text('$count', style: text.body.copyWith(color: colors.textSecondary)),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Page title block like Unison's "Transferir archivos" + grey subtitle.
class PageTitle extends StatelessWidget {
  const PageTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.centered = true,
    this.padding = const EdgeInsets.fromLTRB(Space.xl, Space.xxl, Space.xl, Space.xl),
  });

  final String title;
  final String? subtitle;
  final bool centered;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final align = centered ? TextAlign.center : TextAlign.start;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(title, style: text.title, textAlign: align),
          if (subtitle != null) ...[
            const SizedBox(height: Space.xs),
            Text(
              subtitle!,
              style: text.body.copyWith(color: colors.textSecondary),
              textAlign: align,
            ),
          ],
        ],
      ),
    );
  }
}
