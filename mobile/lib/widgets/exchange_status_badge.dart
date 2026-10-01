import 'package:flutter/material.dart';

import '../theme.dart';

/// "Market open" / "Market closed" with a status dot.
class MarketStatus extends StatelessWidget {
  const MarketStatus({super.key, required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: open ? p.gain : p.mutedForeground.withValues(alpha: 0.5), shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(open ? 'Market open' : 'Market closed', style: TextStyle(fontSize: 12, color: p.mutedForeground)),
      ],
    );
  }
}
