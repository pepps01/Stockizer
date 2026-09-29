import 'package:flutter/material.dart';

import '../format.dart';
import '../models/selector_result.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../widgets/action_buttons.dart';
import 'ticker_detail_screen.dart';

class SelectorScreen extends StatefulWidget {
  const SelectorScreen({super.key});

  @override
  State<SelectorScreen> createState() => _SelectorScreenState();
}

class _SelectorScreenState extends State<SelectorScreen> {
  final _api = ApiClient();
  String _stockType = 'growth';
  late Future<List<SelectorResult>> _future;

  static const _types = [
    ('growth', 'Growth'),
    ('value', 'Value'),
    ('equity', 'Equity'),
  ];

  @override
  void initState() {
    super.initState();
    _future = _api.runSelector(_stockType);
  }

  void _select(String type) {
    setState(() {
      _stockType = type;
      _future = _api.runSelector(type);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selector')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              children: _types.map((t) {
                final (type, label) = t;
                return ChoiceChip(
                  label: Text(label),
                  selected: _stockType == type,
                  onSelected: (_) => _select(type),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<SelectorResult>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final results = snapshot.data!;
                if (results.isEmpty) {
                  return const Center(child: Text('No tickers currently match this category.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _SelectorCard(result: results[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectorCard extends StatelessWidget {
  final SelectorResult result;
  const _SelectorCard({required this.result});

  Color _actionColor(BuildContext context) {
    if (result.recommendedAction == 'buy') return AppColors.gain;
    if (result.recommendedAction == 'sell') return AppColors.loss;
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => TickerDetailScreen(symbol: result.symbol)),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: result.symbol,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.brand),
                        ),
                        TextSpan(text: '  ${result.name}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatPrice(result.price)),
                  Text(formatPercent(result.changePercent), style: TextStyle(color: changeColor(context, result.changePercent), fontSize: 12)),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: _actionColor(context).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      result.recommendedAction.toUpperCase(),
                      style: TextStyle(color: _actionColor(context), fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (result.description != null) ...[
            const SizedBox(height: 6),
            Text(result.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 8),
          ActionButtons(symbol: result.symbol),
        ],
      ),
    );
  }
}
