import 'package:flutter/material.dart';

import '../format.dart';
import '../models/market.dart';
import '../services/api_client.dart';

class FinancialsScreen extends StatefulWidget {
  const FinancialsScreen({super.key});

  @override
  State<FinancialsScreen> createState() => _FinancialsScreenState();
}

class _FinancialsScreenState extends State<FinancialsScreen> {
  final _api = ApiClient();
  late Future<List<Exchange>> _exchangesFuture;
  String? _selectedExchange;
  Future<(Exchange, List<Ticker>)>? _tickersFuture;

  @override
  void initState() {
    super.initState();
    _exchangesFuture = _api.listExchanges();
    // Auto-select the first exchange once loaded; the FutureBuilder below is
    // what actually renders the error/loading/data states for this future.
    _exchangesFuture.then((exchanges) {
      if (mounted && exchanges.isNotEmpty) _selectExchange(exchanges.first.code);
    }).catchError((_) {});
  }

  void _selectExchange(String code) {
    setState(() {
      _selectedExchange = code;
      _tickersFuture = _api.getExchangeTickers(code);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Financials')),
      body: Column(
        children: [
          FutureBuilder<List<Exchange>>(
            future: _exchangesFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Failed to load exchanges.'),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
              }
              final exchanges = snapshot.data!;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Wrap(
                  spacing: 8,
                  children: exchanges.map((exchange) {
                    final selected = _selectedExchange == exchange.code;
                    return ChoiceChip(
                      label: Text(exchange.code),
                      selected: selected,
                      onSelected: (_) => _selectExchange(exchange.code),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          Expanded(
            child: _tickersFuture == null
                ? const Center(child: CircularProgressIndicator())
                : FutureBuilder<(Exchange, List<Ticker>)>(
                    future: _tickersFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final (_, tickers) = snapshot.data!;
                      return ListView.builder(
                        itemCount: tickers.length,
                        itemBuilder: (context, i) => _FinancialsAccordionItem(ticker: tickers[i], api: _api),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FinancialsAccordionItem extends StatefulWidget {
  final Ticker ticker;
  final ApiClient api;
  const _FinancialsAccordionItem({required this.ticker, required this.api});

  @override
  State<_FinancialsAccordionItem> createState() => _FinancialsAccordionItemState();
}

class _FinancialsAccordionItemState extends State<_FinancialsAccordionItem> {
  Ticker? _details;
  bool _loading = false;

  Future<void> _loadDetails() async {
    if (_details != null || _loading) return;
    setState(() => _loading = true);
    final details = await widget.api.getTicker(widget.ticker.symbol);
    setState(() {
      _details = details;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text('${widget.ticker.symbol}  ${widget.ticker.name}'),
      onExpansionChanged: (expanded) {
        if (expanded) _loadDetails();
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _details == null
                  ? const SizedBox.shrink()
                  : Wrap(
                      spacing: 24,
                      runSpacing: 8,
                      children: [
                        _stat(context, 'P/E ratio', _details!.peRatio?.toStringAsFixed(2) ?? '—'),
                        _stat(context, 'Market cap', formatCompact(_details!.marketCap)),
                        _stat(context, 'EPS', formatPrice(_details!.eps)),
                        _stat(context, 'Dividend yield', formatPercent(_details!.dividendYield)),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
