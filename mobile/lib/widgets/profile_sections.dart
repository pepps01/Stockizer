import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models/financials.dart';
import '../models/market.dart';
import '../navigation.dart';
import '../services/api_client.dart';
import '../state/auth_provider.dart';
import '../state/settings_controller.dart';
import '../state/ticker_marks.dart';
import '../theme.dart';
import 'badges.dart';
import 'common.dart';
import 'flag.dart';
import 'live_quotes.dart';
import 'ticker_menu.dart';

/// Investor profile: buy / hold / sell calls assumed from Financials or a
/// symbol page, with the price then → now and the move since (web: AssumedPositions).
class AssumedPositionsSection extends StatefulWidget {
  const AssumedPositionsSection({super.key, this.onChanged});

  /// Called after a call changes, so the journal counts can refresh.
  final VoidCallback? onChanged;

  @override
  State<AssumedPositionsSection> createState() => _AssumedPositionsSectionState();
}

class _AssumedPositionsSectionState extends State<AssumedPositionsSection> {
  late final ApiClient _api = context.read<ApiClient>();
  late final String _token = context.read<AuthProvider>().token!;
  late Future<List<Assumption>> _rows = _api.assumptions(_token);
  late final TickerMarks _marks = TickerMarks(_api, _token)..addListener(_changed);

  void _changed() {
    setState(() {
      _rows = _api.assumptions(_token);
    });
    widget.onChanged?.call();
  }

  @override
  void dispose() {
    _marks.removeListener(_changed);
    _marks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FutureBuilder<List<Assumption>>(
      future: _rows,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <Assumption>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('ASSUMED POSITIONS', style: labelCaps(p))),
                for (final s in const ['buy', 'hold', 'sell'])
                  if (rows.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _Pill('${rows.where((r) => r.stance == s).length} $s', TickerMenu.styleOf(p, s)),
                    ),
              ],
            ),
            const SizedBox(height: 8),
            if (!snapshot.hasData)
              const Skeleton(height: 64)
            else if (rows.isEmpty)
              _EmptyLine('No calls yet. Open an index, choose Get Financials, and use Assume on a stock to track it here.')
            else
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: p.border)),
                ),
                child: Column(
                  children: [
                    for (final a in rows)
                      _Line(
                        countryCode: a.info.countryCode,
                        symbol: a.symbol,
                        displaySymbol: a.info.displaySymbol,
                        name: a.info.name,
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${formatNumber(a.price)} → ${formatNumber(a.quote?.price)}',
                              style: TextStyle(fontSize: 12, color: p.mutedForeground, fontFeatures: priceFeatures),
                            ),
                            ChangeText(a.changeSincePercent, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        menu: TickerMenu(
                          symbol: a.symbol,
                          displaySymbol: a.info.displaySymbol,
                          name: a.info.name,
                          quote: a.quote,
                          marks: _marks,
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

/// Investor profile: the watchlist with live prices, in the order chosen in Settings.
class WatchlistSection extends StatefulWidget {
  const WatchlistSection({super.key});

  @override
  State<WatchlistSection> createState() => _WatchlistSectionState();
}

class _WatchlistSectionState extends State<WatchlistSection> {
  late final ApiClient _api = context.read<ApiClient>();
  late final String _token = context.read<AuthProvider>().token!;
  late Future<List<MarketRow>> _rows = _api.watchlist(_token);

  Future<void> _remove(String symbol) async {
    try {
      await _api.removeFromWatchlist(_token, symbol);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
    if (!mounted) return;
    setState(() {
      _rows = _api.watchlist(_token);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final settings = context.watch<SettingsController>();
    return FutureBuilder<List<MarketRow>>(
      future: _rows,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <MarketRow>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('WATCHLIST${rows.isEmpty ? '' : ' · ${rows.length}'}', style: labelCaps(p)),
            const SizedBox(height: 8),
            if (!snapshot.hasData)
              const Skeleton(height: 64)
            else if (rows.isEmpty)
              _EmptyLine('Nothing on your watchlist yet. Use Add to watchlist in any ticker’s menu, or the star on a symbol page.')
            else
              LiveQuotes(
                symbols: rows.map((r) => r.symbol),
                builder: (context, live) => Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: p.border)),
                  ),
                  child: Column(
                    children: [
                      for (final row in settings.sortWatchlist(rows, live).take(8))
                        _Line(
                          countryCode: row.info.countryCode,
                          symbol: row.symbol,
                          displaySymbol: row.info.displaySymbol,
                          name: row.info.name,
                          trailing: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatNumber((live[row.symbol] ?? row.quote)?.price),
                                style: const TextStyle(fontSize: 13, fontFeatures: priceFeatures),
                              ),
                              ChangeText(
                                (live[row.symbol] ?? row.quote)?.changePercent,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          menu: IconButton(
                            tooltip: 'Remove ${row.info.displaySymbol} from your watchlist',
                            onPressed: () => _remove(row.symbol),
                            icon: Icon(Icons.star_rounded, color: p.hold),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.countryCode,
    required this.symbol,
    required this.displaySymbol,
    required this.name,
    required this.trailing,
    required this.menu,
  });

  final String countryCode;
  final String symbol;
  final String displaySymbol;
  final String name;
  final Widget trailing;
  final Widget menu;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => openSymbol(context, symbol),
              child: Row(
                children: [
                  Flag(code: countryCode, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displaySymbol, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: p.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                  trailing,
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          menu,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.style);

  final String text;
  final (String, Color, Color) style;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: style.$3, borderRadius: BorderRadius.circular(99)),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: style.$2),
    ),
  );
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: p.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(text, style: TextStyle(fontSize: 13, height: 1.45, color: p.mutedForeground)),
    );
  }
}
