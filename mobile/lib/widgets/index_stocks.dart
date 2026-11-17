import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models/financials.dart';
import '../models/market.dart';
import '../navigation.dart';
import '../services/api_client.dart';
import '../state/auth_provider.dart';
import '../state/ticker_marks.dart';
import '../theme.dart';
import 'badges.dart';
import 'common.dart';
import 'financials_sheet.dart';
import 'flag.dart';
import 'live_quotes.dart';
import 'ticker_menu.dart';

/// On an index's page: the stocks Stockiser covers in its market, with highs,
/// lows and volume, a menu per stock, and the "Get Financials" button.
class IndexStocks extends StatefulWidget {
  const IndexStocks({super.key, required this.symbol, this.onCount});

  final String symbol;

  /// Reports how many stocks loaded (shown on the "Stocks" tab).
  final ValueChanged<int>? onCount;

  @override
  State<IndexStocks> createState() => _IndexStocksState();
}

class _IndexStocksState extends State<IndexStocks> {
  late final TickerMarks _marks = TickerMarks(context.read<ApiClient>(), context.read<AuthProvider>().token);
  late Future<IndexMembers> _members = _load();
  _Sort _sort = _Sort.symbol;

  Future<IndexMembers> _load() => context.read<ApiClient>().indexMembers(widget.symbol).then((m) {
    widget.onCount?.call(m.stocks.length);
    return m;
  });

  @override
  void dispose() {
    _marks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AsyncView<IndexMembers>(
      future: _members,
      onRetry: () => setState(() {
        _members = _load();
      }),
      loading: const Column(children: [Skeleton(height: 48), SizedBox(height: 12), SkeletonList(count: 6)]),
      builder: (context, data) {
        if (data.stocks.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: EmptyState(
              title: 'No member stocks',
              message: '${data.index.name} measures market volatility rather than a basket of companies.',
              icon: Icons.show_chart,
            ),
          );
        }
        final multiCountry = data.countries.length > 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'The companies Stockiser covers in this index’s market${multiCountry ? ' (${data.countries.join(', ')})' : ''}. It is not the index’s full membership list.',
              style: TextStyle(fontSize: 13, height: 1.45, color: p.mutedForeground),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: brandForest,
                foregroundColor: brandMint,
                overlayColor: brandMint,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size.fromHeight(50),
                textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 15),
              ),
              onPressed: () => showFinancialsSheet(context, symbol: data.index.symbol, indexName: data.index.name, marks: _marks),
              icon: const Icon(Icons.bar_chart_rounded, size: 20),
              label: const Text('Get Financials'),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Text('${data.stocks.length} STOCKS COVERED', style: labelCaps(p))),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: p.mutedForeground, visualDensity: VisualDensity.compact),
                  onPressed: () => setState(() => _sort = _Sort.values[(_sort.index + 1) % _Sort.values.length]),
                  icon: const Icon(Icons.swap_vert_rounded, size: 18),
                  label: Text(_sort.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            ListenableBuilder(
              listenable: _marks,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_marks.error != null) ErrorNote(_marks.error),
                  LiveQuotes(
                    symbols: data.stocks.map((r) => r.symbol),
                    builder: (context, live) => Column(
                      children: [
                        for (final row in _sort.apply(data.stocks, live))
                          _StockLine(
                            symbol: row.symbol,
                            displaySymbol: row.info.displaySymbol,
                            name: row.info.name,
                            countryCode: multiCountry ? row.info.countryCode : null,
                            rating: row.technicals.label,
                            quote: live[row.symbol] ?? row.quote,
                            marks: _marks,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _Sort {
  symbol('A–Z'),
  change('Day %'),
  volume('Volume');

  const _Sort(this.label);
  final String label;

  List<MarketRow> apply(List<MarketRow> rows, Map<String, Quote> live) {
    Quote? q(MarketRow r) => live[r.symbol] ?? r.quote;
    final sorted = [...rows];
    switch (this) {
      case _Sort.symbol:
        sorted.sort((a, b) => a.info.displaySymbol.compareTo(b.info.displaySymbol));
      case _Sort.change:
        sorted.sort((a, b) => (q(b)?.changePercent ?? -1e9).compareTo(q(a)?.changePercent ?? -1e9));
      case _Sort.volume:
        sorted.sort((a, b) => (q(b)?.volume ?? -1).compareTo(q(a)?.volume ?? -1));
    }
    return sorted;
  }
}

/// One stock: monogram, symbol over name, price over change, then highs,
/// lows, volume and the technical rating on a quiet line, and the call chip.
class _StockLine extends StatelessWidget {
  const _StockLine({
    required this.symbol,
    required this.displaySymbol,
    required this.name,
    required this.countryCode,
    required this.rating,
    required this.quote,
    required this.marks,
  });

  final String symbol;
  final String displaySymbol;
  final String name;
  final String? countryCode;
  final String? rating;
  final Quote? quote;
  final TickerMarks marks;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final q = quote;
    final meta = TextStyle(fontSize: 11.5, color: p.mutedForeground, fontFeatures: priceFeatures);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => openSymbol(context, symbol),
              child: Row(
                children: [
                  SymbolAvatar(displaySymbol, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displaySymbol,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (countryCode != null) ...[const SizedBox(width: 6), Flag(code: countryCode!, size: 14)],
                          ],
                        ),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: p.mutedForeground),
                        ),
                        const SizedBox(height: 3),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: 'H ${formatNumber(q?.high)}  L ${formatNumber(q?.low)}  Vol ${formatCompact(q?.volume)}'),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: meta,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatNumber(q?.price),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w300, fontFeatures: priceFeatures),
                      ),
                      ChangeText(q?.changePercent, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      RatingLabel(label: rating, fontSize: 11),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          TickerMenu(symbol: symbol, displaySymbol: displaySymbol, name: name, quote: q, marks: marks),
        ],
      ),
    );
  }
}
