import 'package:flutter/material.dart';

/// The Stockiser mark (approved option V6, "Signal through noise"): the forest
/// S, the signal, cutting through four deeper-mint market bars on a mint tile.
/// Same drawing as frontend/src/components/layout/BrandMark.tsx and the app icon.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 34, this.inverted = false});

  final double size;

  /// Kept for existing call sites; the mint tile reads on light and dark grounds.
  final bool inverted;

  static const mint = Color(0xFF4EE478);
  static const forest = Color(0xFF114325);
  static const bars = Color(0xFF25B356);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Stockiser',
      image: true,
      child: SizedBox.square(dimension: size, child: const CustomPaint(painter: _MarkPainter())),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn in the same 200-unit box as the SVG, then scaled to fit.
    final unit = size.width / 200;
    canvas.scale(unit);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 200, 200), const Radius.circular(46)),
      Paint()..color = BrandMark.mint,
    );
    canvas.translate(100, 100);
    canvas.scale(1.12);

    Paint stroke(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final bar = stroke(BrandMark.bars);
    for (final (x, y1, y2) in const [(0.0, -64.0, -40.0), (29.0, -46.0, -22.0), (-29.0, 22.0, 46.0), (0.0, 40.0, 64.0)]) {
      canvas.drawLine(Offset(x, y1), Offset(x, y2), bar);
    }
    final s = Path()
      ..moveTo(-29, -36)
      ..lineTo(-29, -31)
      ..cubicTo(-29, -12, 29, 12, 29, 31)
      ..lineTo(29, 36);
    canvas.drawPath(s, stroke(BrandMark.forest));
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) => false;
}
