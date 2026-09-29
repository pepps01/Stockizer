import 'package:flutter/material.dart';
import '../theme.dart';

class ExchangeStatusBadge extends StatelessWidget {
  final bool isOpen;
  const ExchangeStatusBadge({super.key, required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? AppColors.gain : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            isOpen ? 'Open' : 'Closed',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
