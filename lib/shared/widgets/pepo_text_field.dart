import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/motion.dart';
import '../theme/tokens.dart';

/// Fluent text box: 32 px, radius 4, bottom stroke that turns accent
/// (2 px) while focused.
class PepoTextField extends StatefulWidget {
  const PepoTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.label,
    this.leading,
    this.trailing,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
    this.style,
    this.width,
    this.errorText,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? placeholder;

  /// Small caption above the box.
  final String? label;
  final Widget? leading;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int? maxLines;
  final TextAlign textAlign;
  final TextStyle? style;
  final double? width;
  final String? errorText;

  @override
  State<PepoTextField> createState() => _PepoTextFieldState();
}

class _PepoTextFieldState extends State<PepoTextField> {
  FocusNode? _ownNode;
  bool _focused = false;
  bool _hovered = false;

  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(PepoTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownNode)?.removeListener(_onFocus);
      _node.addListener(_onFocus);
    }
  }

  void _onFocus() {
    if (_focused != _node.hasFocus) setState(() => _focused = _node.hasFocus);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    _ownNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pepo;
    final text = context.text;
    final motion = Motion.of(context);
    final enabled = widget.enabled;
    final hasError = widget.errorText != null;
    final fill = !enabled
        ? (colors.isDark ? const Color(0x0BFFFFFF) : const Color(0x7FF9F9F9))
        : _focused
        ? colors.bgLayerAlt
        : _hovered
        ? colors.controlHover
        : colors.controlFill;
    final bottom = hasError
        ? colors.critical
        : _focused
        ? colors.accent
        : (colors.isDark ? const Color(0x8BFFFFFF) : const Color(0x72000000));
    final field = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: enabled ? SystemMouseCursors.text : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: motion.fast,
        curve: Motion.standard,
        width: widget.width,
        constraints: BoxConstraints(minHeight: widget.maxLines == 1 ? Sizes.buttonHeight : 0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: Radii.controlRadius,
          border: Border.all(color: colors.controlStroke),
        ),
        // The Fluent bottom stroke is a separate line: a rounded border must
        // use one colour on every side.
        foregroundDecoration: _BottomLine(color: bottom, thickness: _focused || hasError ? 2 : 1),
        child: Row(
          crossAxisAlignment: widget.maxLines == 1
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            if (widget.leading != null)
              Padding(
                padding: const EdgeInsets.only(left: Space.s),
                child: IconTheme.merge(
                  data: IconThemeData(size: 16, color: colors.textSecondary),
                  child: widget.leading!,
                ),
              ),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _node,
                autofocus: widget.autofocus,
                enabled: enabled,
                readOnly: widget.readOnly,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                inputFormatters: widget.inputFormatters,
                maxLength: widget.maxLength,
                maxLines: widget.maxLines,
                textAlign: widget.textAlign,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                cursorColor: colors.accent,
                cursorWidth: 1,
                style: (widget.style ?? text.body).copyWith(
                  color: enabled ? colors.textPrimary : colors.textDisabled,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  isCollapsed: true,
                  border: InputBorder.none,
                  counterText: '',
                  hintText: widget.placeholder,
                  hintStyle: text.body.copyWith(color: colors.textTertiary),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: widget.leading == null ? Space.m - 1 : Space.s,
                    vertical: widget.maxLines == 1 ? 5 : Space.s,
                  ),
                ),
              ),
            ),
            if (widget.trailing != null)
              Padding(
                padding: const EdgeInsets.only(right: Space.xs),
                child: widget.trailing,
              ),
          ],
        ),
      ),
    );
    if (widget.label == null && !hasError) {
      return field;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.xs),
            child: Text(widget.label!, style: text.body),
          ),
        field,
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(widget.errorText!, style: text.caption.copyWith(color: colors.critical)),
          ),
      ],
    );
  }
}

/// Bottom stroke of the text box, clipped to the rounded rect.
class _BottomLine extends Decoration {
  const _BottomLine({required this.color, required this.thickness});

  final Color color;
  final double thickness;

  @override
  Decoration? lerpFrom(Decoration? a, double t) {
    if (a is _BottomLine) {
      return _BottomLine(
        color: Color.lerp(a.color, color, t) ?? color,
        thickness: lerpValue(a.thickness, thickness, t),
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  Decoration? lerpTo(Decoration? b, double t) {
    if (b is _BottomLine) return b.lerpFrom(this, t);
    return super.lerpTo(b, t);
  }

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _BottomLinePainter(this);
}

class _BottomLinePainter extends BoxPainter {
  _BottomLinePainter(this.line);

  final _BottomLine line;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = offset & size;
    canvas.save();
    canvas.clipRRect(Radii.controlRadius.toRRect(rect));
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.bottom - line.thickness, rect.width, line.thickness),
      Paint()..color = line.color,
    );
    canvas.restore();
  }
}
