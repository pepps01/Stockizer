import 'package:flutter/material.dart';

import '../format.dart';
import '../models/strategy.dart';
import '../navigation.dart';
import '../theme.dart';
import 'badges.dart';

/// One emitted Adviser signal: time · symbol and price · reason · badge,
/// divided from its neighbours by a hairline.
class SignalEventTile extends StatelessWidget {
  const SignalEventTile({super.key, required this.signal, this.showDate = true});

  final SignalEvent signal;

  /// False when the list is already grouped by day, so only the time shows.
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final time = parseApiTime(signal.emittedAt);
    final when = time == null ? '—' : (showDate ? formatDateTime(signal.emittedAt) : formatClock(time));
    return InkWell(
      onTap: () => openSymbol(context, signal.symbol),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: showDate ? 84 : 44,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(when, style: TextStyle(fontSize: 13, color: p.mutedForeground, fontFeatures: priceFeatures)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: signal.displaySymbol, style: const TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(
                          text: '  ${formatPrice(signal.price, signal.currency)}',
                          style: TextStyle(color: p.mutedForeground, fontFeatures: priceFeatures),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    signal.reason.isNotEmpty ? signal.reason : signal.name,
                    style: TextStyle(fontSize: 13, height: 1.4, color: p.mutedForeground),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SignalBadge(type: signal.signalType, size: BadgeSize.sm),
                const SizedBox(height: 4),
                Text(
                  '${(signal.confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, color: p.mutedForeground, fontFeatures: priceFeatures),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
