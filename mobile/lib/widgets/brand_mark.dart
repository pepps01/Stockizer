import 'package:flutter/material.dart';

import '../theme.dart';

/// The Algizer "A™" tile — same as frontend/src/components/layout/BrandMark.tsx.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 34, this.inverted = false});

  final double size;

  /// White tile with an indigo letter, for use on brand-coloured backgrounds.
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final background = inverted ? Colors.white : p.brand;
    final foreground = inverted ? p.brand : p.brandForeground;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [BoxShadow(color: p.brand.withValues(alpha: 0.3), blurRadius: size * 0.3, offset: Offset(0, size * 0.08))],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text('A', style: TextStyle(color: foreground, fontSize: size * 0.5, fontWeight: FontWeight.w700, height: 1)),
          Positioned(
            right: size * 0.12,
            top: size * 0.08,
            child: Text('™', style: TextStyle(color: foreground, fontSize: size * 0.15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
