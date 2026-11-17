import 'package:flutter/material.dart';

import '../format.dart';
import '../models/market.dart';
import '../models/strategy.dart';
import '../theme.dart';

/// "SIMULATED" pill for markets without a free live feed. Renders nothing for
/// real data — every synthetic price in the app must carry this badge.
class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.source});

  final String? source;

  @override
  Widget build(BuildContext context) {
    if (!isSimulated(source)) return const SizedBox.shrink();
    final p = context.palette;
    return Tooltip(
      message: 'No free live feed covers this market, so prices are simulated by a deterministic model. Do not trade on them.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: p.holdSoft, borderRadius: BorderRadius.circular(99)),
        child: Text('SIMULATED', style: TextStyle(color: p.hold, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      ),
    );
  }
}

enum BadgeSize { sm, md, lg }

/// Colour-coded BUY (green) / SELL (red) / HOLD (orange).
class SignalBadge extends StatelessWidget {
  const SignalBadge({super.key, required this.type, this.size = BadgeSize.md});

  final SignalType? type;
  final BadgeSize size;

  static (Color, Color) colors(AppPalette p, SignalType type) => switch (type) {
        SignalType.buy => (p.gain, p.gainSoft),
        SignalType.sell => (p.loss, p.lossSoft),
        SignalType.hold => (p.hold, p.holdSoft),
      };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = type;
    if (t == null) return Text('—', style: TextStyle(color: p.mutedForeground));
    final (fg, bg) = colors(p, t);
    final (padding, fontSize) = switch (size) {
      BadgeSize.sm => (const EdgeInsets.symmetric(horizontal: 8, vertical: 2), 11.0),
      BadgeSize.md => (const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 12.0),
      BadgeSize.lg => (const EdgeInsets.symmetric(horizontal: 16, vertical: 6), 16.0),
    };
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(t.wire, style: TextStyle(color: fg, fontSize: fontSize, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
    );
  }
}

/// TradingView-style technical rating: "Strong buy", "Buy", "Neutral", "Sell", "Strong sell".
class RatingLabel extends StatelessWidget {
  const RatingLabel({super.key, required this.label, this.fontSize = 13});

  final String? label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = label;
    if (text == null) return Text('—', style: TextStyle(color: p.mutedForeground, fontSize: fontSize));
    final lower = text.toLowerCase();
    final color = lower.contains('buy') ? p.gain : (lower.contains('sell') ? p.loss : p.mutedForeground);
    // Icons rather than ⇈/⇊ glyphs, which common mobile fonts lack.
    final arrow = switch (text) {
      'Strong buy' => Icons.keyboard_double_arrow_up,
      'Buy' => Icons.arrow_upward,
      'Strong sell' => Icons.keyboard_double_arrow_down,
      'Sell' => Icons.arrow_downward,
      _ => Icons.drag_handle,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(arrow, size: fontSize + 1, color: color),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

/// Signed percent change coloured green / red.
class ChangeText extends StatelessWidget {
  const ChangeText(this.percent, {super.key, this.change, this.style});

  final double? percent;
  final double? change;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final color = context.palette.change(percent ?? change);
    final text = change == null ? formatPercent(percent) : '${formatSigned(change)}  (${formatPercent(percent)})';
    return Text(
      text,
      style: (style ?? const TextStyle(fontSize: 13)).copyWith(color: color, fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}

/// Small grey pill holding a display symbol, e.g. "RY" or "DANGCEM".
class SymbolChip extends StatelessWidget {
  const SymbolChip(this.symbol, {super.key});

  final String symbol;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: p.surfaceMuted, borderRadius: BorderRadius.circular(4)),
      child: Text(symbol, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: p.foreground)),
    );
  }
}
