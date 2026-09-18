import 'package:flutter/material.dart';

/// The PepoConnect mark: two photo frames linked like chain links, drawn
/// with a CustomPainter so it scales to any size (onboarding, about page).
/// The brand background is the only gradient in the app.
class PepoLogo extends StatelessWidget {
  const PepoLogo({super.key, this.size = 64, this.withBackground = true, this.color});

  final double size;

  /// Rounded square with the brand gradient behind the glyph.
  final bool withBackground;

  /// Monochrome glyph colour (defaults to white; ignored with a background
  /// only for the sun, which stays amber).
  final Color? color;

  static const Color gradientStart = Color(0xFF0A3D8F);
  static const Color gradientEnd = Color(0xFF12B6D9);
  static const Color sun = Color(0xFFFFC857);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'PepoConnect',
      image: true,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(size),
          painter: PepoLogoPainter(
            withBackground: withBackground,
            glyphColor: color ?? Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Paints the mark in a 512-unit design space and scales to the canvas.
class PepoLogoPainter extends CustomPainter {
  const PepoLogoPainter({required this.withBackground, required this.glyphColor});

  final bool withBackground;
  final Color glyphColor;

  static const double _design = 512;
  static const Rect _back = Rect.fromLTWH(112, 128, 220, 176);
  static const Rect _front = Rect.fromLTWH(196, 200, 220, 176);
  static const double _frameRadius = 30;
  static const double _stroke = 28;
  static const Rect _crossing = Rect.fromLTWH(296, 178, 58, 58);

  /// Bounding box of the glyph alone (frame strokes included).
  static const Rect glyphBounds = Rect.fromLTRB(98, 114, 430, 390);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (withBackground) {
      final scale = size.width / _design;
      canvas.scale(scale, scale);
      final rrect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, _design, _design),
        const Radius.circular(112),
      );
      canvas.drawRRect(
        rrect,
        Paint()..shader = _gradient(const Rect.fromLTWH(0, 0, _design, _design)),
      );
    } else {
      // Centre the glyph and let it fill the canvas.
      final scale = size.width / glyphBounds.longestSide;
      canvas.translate(
        (size.width - glyphBounds.width * scale) / 2,
        (size.height - glyphBounds.height * scale) / 2,
      );
      canvas.scale(scale, scale);
      canvas.translate(-glyphBounds.left, -glyphBounds.top);
    }
    _paintGlyph(canvas);
    canvas.restore();
  }

  Shader _gradient(Rect rect) => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [PepoLogo.gradientStart, PepoLogo.gradientEnd],
  ).createShader(rect);

  void _paintGlyph(Canvas canvas) {
    final white = Paint()
      ..color = glyphColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeJoin = StrokeJoin.round;
    final backPath = Path()
      ..addRRect(RRect.fromRectAndRadius(_back, const Radius.circular(_frameRadius)));
    final frontPath = Path()
      ..addRRect(RRect.fromRectAndRadius(_front, const Radius.circular(_frameRadius)));

    // Without a background the "erase" must clear to transparent.
    if (!withBackground) canvas.saveLayer(glyphBounds.inflate(4), Paint());

    canvas.drawPath(backPath, white);
    // Check inside the back frame.
    canvas.drawPath(
      Path()
        ..moveTo(150, 165)
        ..lineTo(166, 181)
        ..lineTo(194, 151),
      Paint()
        ..color = glyphColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(frontPath, white);

    // Upper-right crossing: the back frame passes over the front one.
    canvas.save();
    canvas.clipRect(_crossing);
    final erase = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke + 12;
    if (withBackground) {
      erase.shader = _gradient(const Rect.fromLTWH(0, 0, _design, _design));
    } else {
      erase.blendMode = BlendMode.clear;
    }
    canvas.drawPath(backPath, erase);
    canvas.drawPath(backPath, white);
    canvas.restore();

    // Mountain and sun inside the front frame.
    final mountain = Path()
      ..moveTo(224, 346)
      ..lineTo(286, 262)
      ..lineTo(322, 300)
      ..lineTo(352, 272)
      ..lineTo(388, 346)
      ..close();
    canvas.drawPath(mountain, Paint()..color = glyphColor);
    canvas.drawPath(
      mountain,
      Paint()
        ..color = glyphColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      const Offset(372, 244),
      16,
      Paint()..color = withBackground ? PepoLogo.sun : glyphColor,
    );

    if (!withBackground) canvas.restore();
  }

  @override
  bool shouldRepaint(PepoLogoPainter old) =>
      old.withBackground != withBackground || old.glyphColor != glyphColor;
}
