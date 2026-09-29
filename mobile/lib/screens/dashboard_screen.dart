import 'package:flutter/material.dart';

import '../format.dart';
import '../models/market.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../widgets/price_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiClient();

  static const _tiles = [
    ('^GSPC', 'S&P 500', '5d'),
    ('^IXIC', 'Nasdaq Composite', '5d'),
    ('BTC-USD', 'Bitcoin', '1mo'),
    ('DX-Y.NYB', 'US Dollar Index', '1mo'),
    ('^TNX', 'US 10Y Yield', '1mo'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Market summary')),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _tiles.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final (symbol, label, period) = _tiles[i];
            return _MarketTile(symbol: symbol, label: label, period: period, api: _api);
          },
        ),
      ),
    );
  }
}

class _MarketTile extends StatelessWidget {
  final String symbol;
  final String label;
  final String period;
  final ApiClient api;

  const _MarketTile({required this.symbol, required this.label, required this.period, required this.api});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: FutureBuilder(
        future: Future.wait([api.getTicker(symbol), api.getTickerHistory(symbol, period: period)]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return SizedBox(
              height: 140,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Text(label), const SizedBox(width: 8), const CircularProgressIndicator(strokeWidth: 2)],
              ),
            );
          }
          final ticker = snapshot.data![0] as Ticker;
          final history = snapshot.data![1] as List<PricePoint>;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(formatPrice(ticker.price), style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 8),
                  Text(
                    formatPercent(ticker.changePercent),
                    style: TextStyle(color: changeColor(context, ticker.changePercent), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              PriceChart(points: history, height: 100, compact: true),
            ],
          );
        },
      ),
    );
  }
}
