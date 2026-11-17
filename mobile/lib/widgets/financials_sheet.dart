import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models/financials.dart';
import '../navigation.dart';
import '../services/api_client.dart';
import '../state/ticker_marks.dart';
import '../theme.dart';
import 'badges.dart';
import 'common.dart';
import 'flag.dart';
import 'motion.dart';
import 'ticker_menu.dart';

/// Opens the Financials panel for an index: it slides in from the right over a
/// dimmed screen (web: FinancialsDrawer) with Growth / Value / Equity accordions.
Future<void> showFinancialsSheet(BuildContext context, {required String symbol, required String indexName, required TickerMarks marks}) {
  final api = context.read<ApiClient>();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close financials',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 480),
    pageBuilder: (context, _, _) => Provider<ApiClient>.value(
      value: api,
      child: _FinancialsPanel(symbol: symbol, indexName: indexName, marks: marks),
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
        child: child,
      );
    },
  );
}

class _FinancialsPanel extends StatefulWidget {
  const _FinancialsPanel({required this.symbol, required this.indexName, required this.marks});

  final String symbol;
  final String indexName;
  final TickerMarks marks;

  @override
  State<_FinancialsPanel> createState() => _FinancialsPanelState();
}

class _FinancialsPanelState extends State<_FinancialsPanel> {
  late final Future<IndexFinancials> _data = context.read<ApiClient>().indexFinancials(widget.symbol);
  String? _expanded = 'growth';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final width = MediaQuery.sizeOf(context).width;
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: p.surface,
        elevation: 16,
        child: SizedBox(
          width: width < 560 ? width * 0.94 : 520,
          height: double.infinity,
          child: SafeArea(
            child: FutureBuilder<IndexFinancials>(
              future: _data,
              builder: (context, snapshot) {
                final data = snapshot.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: p.border)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('FINANCIALS', style: labelCaps(p)),
                                const SizedBox(height: 2),
                                Text(
                                  widget.indexName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  data == null
                                      ? 'Sorting the market into stock types…'
                                      : '${data.total} stocks, sorted into the three stock types.',
                                  style: TextStyle(fontSize: 13, color: p.mutedForeground),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Close financials',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: snapshot.hasError
                          ? ListView(padding: const EdgeInsets.all(20), children: [ErrorNote(errorMessage(snapshot.error))])
                          : data == null
                          ? ListView(
                              padding: const EdgeInsets.all(20),
                              children: const [
                                Skeleton(height: 72),
                                SizedBox(height: 12),
                                Skeleton(height: 72),
                                SizedBox(height: 12),
                                Skeleton(height: 72),
                              ],
                            )
                          : ListenableBuilder(
                              listenable: widget.marks,
                              builder: (context, _) => ListView(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                                children: [
                                  if (widget.marks.error != null) ErrorNote(widget.marks.error),
                                  for (var i = 0; i < data.segments.length; i++) ...[
                                    FadeSlideIn(
                                      delay: Duration(milliseconds: 160 + 70 * i),
                                      offset: 24,
                                      child: _Segment(
                                        segment: data.segments[i],
                                        open: _expanded == data.segments[i].key,
                                        onToggle: () =>
                                            setState(() => _expanded = _expanded == data.segments[i].key ? null : data.segments[i].key),
                                        marks: widget.marks,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  Text(
                                    'Growth and value are judged against the other stocks on the same exchange, from P/E, price-to-book, dividend yield and revenue and earnings growth. The middle third is neither, so it appears only under Equity.',
                                    style: TextStyle(fontSize: 12, height: 1.5, color: p.mutedForeground),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.segment, required this.open, required this.onToggle, required this.marks});

  final FinancialSegment segment;
  final bool open;
  final VoidCallback onToggle;
  final TickerMarks marks;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dot = switch (segment.key) {
      'growth' => p.gain,
      'value' => p.brand,
      _ => p.foreground,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: open ? p.surface : p.surfaceMuted.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: open ? p.foreground.withValues(alpha: 0.15) : p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(segment.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                    decoration: BoxDecoration(color: p.surfaceMuted, borderRadius: BorderRadius.circular(99)),
                    child: Text(
                      '${segment.stocks.length}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.mutedForeground),
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 260),
                    child: Icon(Icons.expand_more_rounded, color: p.mutedForeground),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(segment.definition, style: TextStyle(fontSize: 13.5, height: 1.5, color: p.mutedForeground)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final t in segment.traits)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: p.surfaceMuted, borderRadius: BorderRadius.circular(99)),
                                child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (segment.stocks.isEmpty)
                          Text(
                            'No stocks in this market fit this type right now.',
                            style: TextStyle(fontSize: 13, color: p.mutedForeground),
                          )
                        else
                          for (final stock in segment.stocks) _StockRow(stock: stock, showStyle: segment.key == 'equity', marks: marks),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.stock, required this.showStyle, required this.marks});

  final FinancialStock stock;
  final bool showStyle;
  final TickerMarks marks;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final q = stock.quote;
    final growth = stock.revenueGrowth == null
        ? '—'
        : '${stock.revenueGrowth! >= 0 ? '+' : ''}${(stock.revenueGrowth! * 100).toStringAsFixed(1)}%';
    final meta = TextStyle(fontSize: 11.5, color: p.mutedForeground, fontFeatures: priceFeatures);
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InkWell(
              onTap: () => openSymbol(context, stock.symbol),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flag(code: stock.info.countryCode, size: 18),
                      const SizedBox(width: 8),
                      Text(stock.info.displaySymbol, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          stock.info.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: p.mutedForeground),
                        ),
                      ),
                      Text(formatNumber(q?.price), style: const TextStyle(fontSize: 13, fontFeatures: priceFeatures)),
                      const SizedBox(width: 8),
                      ChangeText(q?.changePercent, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('P/E ${formatNumber(stock.peRatio, 1)}', style: meta),
                        Text('P/B ${formatNumber(stock.priceToBook, 1)}', style: meta),
                        Text('Div ${stock.dividendYield == null ? '—' : '${stock.dividendYield!.toStringAsFixed(2)}%'}', style: meta),
                        Text('Rev $growth', style: meta),
                        Text('Cap ${formatCompact(stock.marketCap)}', style: meta),
                        if (showStyle && stock.style != null) Text(stock.style!.toUpperCase(), style: labelCaps(p).copyWith(fontSize: 9.5)),
                        SourceBadge(source: stock.info.dataSource),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          TickerMenu(
            symbol: stock.symbol,
            displaySymbol: stock.info.displaySymbol,
            name: stock.info.name,
            quote: q,
            marks: marks,
            dots: true,
          ),
        ],
      ),
    );
  }
}
