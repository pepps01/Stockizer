import 'package:flutter/material.dart';

import '../format.dart';
import '../models/market.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../widgets/action_buttons.dart';
import '../widgets/price_chart.dart';

class TickerDetailScreen extends StatefulWidget {
  final String symbol;
  const TickerDetailScreen({super.key, required this.symbol});

  @override
  State<TickerDetailScreen> createState() => _TickerDetailScreenState();
}

class _TickerDetailScreenState extends State<TickerDetailScreen> {
  final _api = ApiClient();
  late Future<Ticker> _tickerFuture;
  late Future<List<PricePoint>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _tickerFuture = _api.getTicker(widget.symbol);
    _historyFuture = _api.getTickerHistory(widget.symbol, period: '3mo');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.symbol)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<Ticker>(
              future: _tickerFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final ticker = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ticker.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(formatPrice(ticker.price, ticker.currency ?? 'USD'), style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(width: 8),
                        Text(
                          formatPercent(ticker.changePercent),
                          style: TextStyle(color: changeColor(context, ticker.changePercent), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (ticker.description != null) ...[
                      const SizedBox(height: 8),
                      Text(ticker.description!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                    const SizedBox(height: 8),
                    Wrap(spacing: 12, children: [
                      if (ticker.sector != null) Text('Sector: ${ticker.sector}', style: Theme.of(context).textTheme.bodySmall),
                      if (ticker.country != null) Text('Country: ${ticker.country}', style: Theme.of(context).textTheme.bodySmall),
                    ]),
                    const SizedBox(height: 12),
                    ActionButtons(symbol: ticker.symbol),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: FutureBuilder<List<PricePoint>>(
                future: _historyFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()));
                  }
                  return PriceChart(points: snapshot.data!, height: 240);
                },
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<Ticker>(
              future: _tickerFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final t = snapshot.data!;
                return _FinancialsGrid(ticker: t);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FinancialsGrid extends StatelessWidget {
  final Ticker ticker;
  const _FinancialsGrid({required this.ticker});

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('P/E ratio', ticker.peRatio?.toStringAsFixed(2) ?? '—'),
      ('Market cap', formatCompact(ticker.marketCap)),
      ('EPS', formatPrice(ticker.eps)),
      ('Dividend yield', formatPercent(ticker.dividendYield)),
      ('52w high', formatPrice(ticker.fiftyTwoWeekHigh)),
      ('52w low', formatPrice(ticker.fiftyTwoWeekLow)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 3,
      children: stats
          .map((s) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.$1, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  Text(s.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ))
          .toList(),
    );
  }
}
