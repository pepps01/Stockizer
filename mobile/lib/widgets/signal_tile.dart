import 'package:flutter/material.dart';

import '../format.dart';
import '../models/strategy.dart';
import '../navigation.dart';
import '../theme.dart';
import 'badges.dart';

/// One emitted Adviser signal with its colour-coded left edge.
class SignalEventTile extends StatelessWidget {
  const SignalEventTile({super.key, required this.signal});

  final SignalEvent signal;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (color, _) = SignalBadge.colors(p, signal.signalType);
    return InkWell(
      onTap: () => openSymbol(context, signal.symbol),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(signal.displaySymbol, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(signal.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: p.mutedForeground)),
                        ),
                        SignalBadge(type: signal.signalType, size: BadgeSize.sm),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${formatPrice(signal.price, signal.currency)} · ${(signal.confidence * 100).toStringAsFixed(0)}% · ${formatDateTime(signal.emittedAt)}',
                      style: TextStyle(fontSize: 12, color: p.mutedForeground),
                    ),
                    if (signal.reason.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(signal.reason, style: const TextStyle(fontSize: 12.5)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
