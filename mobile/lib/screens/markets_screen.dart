import 'package:flutter/material.dart';

import '../models/market.dart';
import '../services/api_client.dart';
import '../widgets/exchange_status_badge.dart';
import 'exchange_tickers_screen.dart';

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  final _api = ApiClient();
  late Future<List<Exchange>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.listExchanges();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exchanges')),
      body: FutureBuilder<List<Exchange>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final exchanges = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: exchanges.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final exchange = exchanges[i];
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  title: Text(exchange.name),
                  subtitle: Text(exchange.country),
                  trailing: ExchangeStatusBadge(isOpen: exchange.isOpen),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ExchangeTickersScreen(exchangeCode: exchange.code)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
