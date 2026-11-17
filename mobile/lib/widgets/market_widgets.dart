import 'package:flutter/material.dart';

import '../format.dart';
import '../models/market.dart';
import '../navigation.dart';
import '../theme.dart';
import 'badges.dart';
import 'common.dart';
import 'exchange_status_badge.dart';
import 'flag.dart';
import 'live_quotes.dart';
import 'motion.dart';

const _tabular = [FontFeature.tabularFigures()];

enum MarketView { overview, performance, technicals }

/// Indices / stocks list with the web table's Overview · Performance ·
/// Technicals views. Quotes stream live.
class MarketList extends StatefulWidget {
  const MarketList({super.key, required this.rows, this.showCountry = true, this.showViewSwitch = true});

  final List<MarketRow> rows;
  final bool showCountry;
  final bool showViewSwitch;

  @override
  State<MarketList> createState() => _MarketListState();
}

class _MarketListState extends State<MarketList> {
  MarketView _view = MarketView.overview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showViewSwitch) ...[
          Segmented<MarketView>(
            value: _view,
            onChanged: (v) => setState(() => _view = v),
            options: const [
              (MarketView.overview, 'Overview'),
              (MarketView.performance, 'Performance'),
              (MarketView.technicals, 'Technicals'),
            ],
          ),
          const SizedBox(height: 6),
        ],
        LiveQuotes(
          symbols: widget.rows.map((r) => r.symbol),
          builder: (context, live) => Column(
            children: [
              for (var i = 0; i < widget.rows.length; i++) ...[
                if (i > 0) const Divider(),
                FadeSlideIn(
                  key: ValueKey(widget.rows[i].symbol),
                  delay: FadeSlideIn.stagger(i),
                  child: MarketRowTile(
                    row: widget.rows[i],
                    quote: live[widget.rows[i].symbol] ?? widget.rows[i].quote,
                    view: _view,
                    showCountry: widget.showCountry,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class MarketRowTile extends StatelessWidget {
  const MarketRowTile({super.key, required this.row, required this.quote, this.view = MarketView.overview, this.showCountry = true});

  final MarketRow row;
  final Quote? quote;
  final MarketView view;
  final bool showCountry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final info = row.info;
    return InkWell(
      onTap: () => openSymbol(context, info.symbol),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Row(
              children: [
                if (showCountry) ...[Flag(code: info.countryCode, size: 30), const SizedBox(width: 10)],
                Expanded(child: TickerIdentity(info: info)),
                const SizedBox(width: 8),
                if (view == MarketView.overview)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          TickingPrice(
                            value: quote?.price,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          if (!info.isIndex) Text(currencyLabel(info.currency), style: TextStyle(fontSize: 10, color: p.mutedForeground)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      ChangeText(quote?.changePercent, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
                    ],
                  )
                else if (view == MarketView.technicals)
                  RatingLabel(label: row.technicals.label, fontSize: 12.5),
              ],
            ),
            if (view == MarketView.performance) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final entry in Performance.periods.entries)
                    Expanded(
                      child: Column(
                        children: [
                          Text(entry.value, style: TextStyle(fontSize: 10, color: p.mutedForeground)),
                          Text(
                            formatPercent(row.performance[entry.key], 1),
                            style: TextStyle(fontSize: 11.5, color: p.change(row.performance[entry.key]), fontFeatures: _tabular),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            if (view == MarketView.technicals) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('MA ', style: TextStyle(fontSize: 11, color: p.mutedForeground)),
                  RatingLabel(label: row.technicals.maLabel, fontSize: 11.5),
                  const SizedBox(width: 14),
                  Text('Oscillators ', style: TextStyle(fontSize: 11, color: p.mutedForeground)),
                  RatingLabel(label: row.technicals.oscLabel, fontSize: 11.5),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Name over "SYMBOL · EXCH · SIMULATED".
class TickerIdentity extends StatelessWidget {
  const TickerIdentity({super.key, required this.info, this.showExchange = true});

  final TickerInfo info;
  final bool showExchange;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          info.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 3),
        Wrap(
          spacing: 6,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SymbolChip(info.displaySymbol),
            if (showExchange && info.exchange.isNotEmpty)
              Text(info.exchange, style: TextStyle(fontSize: 10.5, color: context.palette.mutedForeground)),
            SourceBadge(source: info.dataSource),
          ],
        ),
      ],
    );
  }
}

/// Horizontal strip of headline index cards (home page hero).
class IndexStrip extends StatelessWidget {
  const IndexStrip({super.key, required this.rows});

  final List<MarketRow> rows;

  @override
  Widget build(BuildContext context) {
    return LiveQuotes(
      symbols: rows.map((r) => r.symbol),
      builder: (context, live) => SizedBox(
        height: 104,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: rows.length,
          itemBuilder: (context, i) => IndexCard(row: rows[i], quote: live[rows[i].symbol] ?? rows[i].quote),
        ),
      ),
    );
  }
}

/// One headline index: name, light price, coloured change — separated from the
/// next by a hairline rather than boxed in a card.
class IndexCard extends StatelessWidget {
  const IndexCard({super.key, required this.row, required this.quote});

  final MarketRow row;
  final Quote? quote;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: () => openSymbol(context, row.symbol),
      child: Container(
        width: 156,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(border: Border(right: BorderSide(color: p.border))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.info.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.mutedForeground),
                  ),
                ),
                SourceBadge(source: row.info.dataSource),
              ],
            ),
            const SizedBox(height: 6),
            TickingPrice(
              value: quote?.price,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w300, fontFeatures: priceFeatures),
            ),
            const SizedBox(height: 4),
            ChangeText(quote?.changePercent, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// Highest volume · Most volatile · Gainers · Losers, as on TradingView's market pages.
class MoversBoard extends StatefulWidget {
  const MoversBoard({super.key, required this.movers, this.compact = false});

  final Movers movers;

  /// Only the gainers/losers list (dashboard).
  final bool compact;

  @override
  State<MoversBoard> createState() => _MoversBoardState();
}

enum _MoverTab { gainers, losers, volume, volatile }

class _MoversBoardState extends State<MoversBoard> {
  _MoverTab _tab = _MoverTab.gainers;

  List<MarketRow> get _rows => switch (_tab) {
    _MoverTab.gainers => widget.movers.gainers,
    _MoverTab.losers => widget.movers.losers,
    _MoverTab.volume => widget.movers.highestVolume,
    _MoverTab.volatile => widget.movers.mostVolatile,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return LiveQuotes(
      symbols: widget.movers.symbols,
      builder: (context, live) => SectionCard(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Segmented<_MoverTab>(
              value: _tab,
              onChanged: (t) => setState(() => _tab = t),
              options: [
                (_MoverTab.gainers, 'Gainers'),
                (_MoverTab.losers, 'Losers'),
                if (!widget.compact) ...[(_MoverTab.volume, 'Highest volume'), (_MoverTab.volatile, 'Most volatile')],
              ],
            ),
            const SizedBox(height: 4),
            if (_rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('Nothing to show in this market right now.', style: TextStyle(color: p.mutedForeground)),
                ),
              ),
            for (var i = 0; i < _rows.length; i++) ...[
              if (i > 0) const Divider(),
              _MoverTile(row: _rows[i], quote: live[_rows[i].symbol] ?? _rows[i].quote, showVolume: _tab == _MoverTab.volume),
            ],
          ],
        ),
      ),
    );
  }
}

class _MoverTile extends StatelessWidget {
  const _MoverTile({required this.row, required this.quote, required this.showVolume});

  final MarketRow row;
  final Quote? quote;
  final bool showVolume;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pct = quote?.changePercent;
    return InkWell(
      onTap: () => openSymbol(context, row.symbol),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Flag(code: row.info.countryCode, size: 30),
            const SizedBox(width: 10),
            Expanded(child: TickerIdentity(info: row.info)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${formatNumber(quote?.price)} ${currencyLabel(row.info.currency)}',
                  style: const TextStyle(fontSize: 13, fontFeatures: _tabular),
                ),
                if (showVolume) Text('Vol ${formatCompact(quote?.volume)}', style: TextStyle(fontSize: 11, color: p.mutedForeground)),
              ],
            ),
            const SizedBox(width: 8),
            Container(
              width: 74,
              padding: const EdgeInsets.symmetric(vertical: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: (pct ?? 0) >= 0 ? p.gain : p.loss, borderRadius: BorderRadius.circular(6)),
              child: Text(
                formatPercent(pct),
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700, fontFeatures: _tabular),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExchangeTile extends StatelessWidget {
  const ExchangeTile({super.key, required this.exchange});

  final Exchange exchange;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final e = exchange;
    return InkWell(
        onTap: () => openExchange(context, e.code),
        child: Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flag(code: e.countryCode, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(e.code, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        SourceBadge(source: e.dataSource),
                      ],
                    ),
                    Text(
                      e.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: p.mutedForeground),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        MarketStatus(open: e.isOpen),
                        Text(
                          '${e.opensAt}–${e.closesAt} local · ${e.stockCount ?? 0} stocks',
                          style: TextStyle(fontSize: 12, color: p.mutedForeground),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: p.mutedForeground),
            ],
          ),
        ),
    );
  }
}
