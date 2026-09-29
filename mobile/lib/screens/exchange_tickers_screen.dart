import 'package:flutter/material.dart';

import '../format.dart';
import '../models/market.dart';
import '../services/api_client.dart';
import '../theme.dart';
import 'ticker_detail_screen.dart';

class ExchangeTickersScreen extends StatefulWidget {
  final String exchangeCode;
  const ExchangeTickersScreen({super.key, required this.exchangeCode});

  @override
  State<ExchangeTickersScreen> createState() => _ExchangeTickersScreenState();
}

class _ExchangeTickersScreenState extends State<ExchangeTickersScreen> {
  final _api = ApiClient();
  late Future<(Exchange, List<Ticker>)> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getExchangeTickers(widget.exchangeCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.exchangeCode)),
      body: FutureBuilder<(Exchange, List<Ticker>)>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final (_, tickers) = snapshot.data!;
          return ListView.separated(
            itemCount: tickers.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final ticker = tickers[i];
              return ListTile(
                title: Text(ticker.symbol, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(ticker.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatPrice(ticker.price)),
                    Text(
                      formatPercent(ticker.changePercent),
                      style: TextStyle(color: changeColor(context, ticker.changePercent), fontSize: 12),
                    ),
                  ],
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TickerDetailScreen(symbol: ticker.symbol)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
