import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models/market.dart';
import '../models/strategy.dart';
import '../navigation.dart';
import '../services/api_client.dart';
import '../state/auth_provider.dart';
import '../state/settings_controller.dart';
import '../state/shell_controller.dart';
import '../theme.dart';
import '../widgets/badges.dart';
import '../widgets/brand_mark.dart';
import '../widgets/common.dart';
import '../widgets/live_quotes.dart';
import '../widgets/market_widgets.dart';
import '../widgets/motion.dart';
import '../widgets/ticker_logo.dart';

/// Home (approved minimalist design): the headline index with an edge-to-edge
/// line, two more markets, the latest signals, the Adviser's state and the
/// watchlist. Everything else lives on its own tab.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<MarketRow>> _indices;
  late Future<List<SignalEvent>> _signals;
  late Future<List<MarketRow>> _watchlist;
  late Future<List<AdviserSession>> _sessions;
  Future<List<Bar>>? _headlineBars;
  String? _headlineSymbol;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = context.read<ApiClient>();
    final token = context.read<AuthProvider>().token!;
    _indices = api.indices();
    _signals = api.signals(token);
    _watchlist = api.watchlist(token);
    _sessions = api.sessions(token);
    _headlineBars = null;
    _headlineSymbol = null;
  }

  Future<List<Bar>> _barsFor(String symbol) {
    if (_headlineSymbol != symbol || _headlineBars == null) {
      _headlineSymbol = symbol;
      _headlineBars = context.read<ApiClient>().history(symbol, '1M');
    }
    return _headlineBars!;
  }

  Future<void> _refresh() async {
    Haptics.tap();
    setState(_load);
    await _indices.then<void>((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final user = context.watch<AuthProvider>().user;
    final settings = context.watch<SettingsController>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 16, 0),
                child: Row(
                  children: [
                    const BrandMark(size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: '${_greeting()}, '),
                            TextSpan(
                              text: user?.firstName ?? '',
                              style: TextStyle(fontWeight: FontWeight.w700, color: p.foreground),
                            ),
                          ],
                        ),
                        style: TextStyle(fontSize: 14, color: p.mutedForeground),
                      ),
                    ),
                    _RoundButton(icon: Icons.search, tooltip: 'Search', onTap: () => openSearch(context)),
                  ],
                ),
              ),
              AsyncView<List<MarketRow>>(
                future: _indices,
                onRetry: () => setState(_load),
                loading: const Padding(padding: EdgeInsets.fromLTRB(22, 24, 22, 0), child: Skeleton(height: 200)),
                builder: (context, rows) {
                  if (rows.isEmpty) return const SizedBox.shrink();
                  final headline = rows.first;
                  final others = [
                    if (rows.length > 1) rows[1],
                    ...rows.where((r) => r.info.countryCode != headline.info.countryCode).take(1),
                  ];
                  return LiveQuotes(
                    symbols: [headline.symbol, ...others.map((r) => r.symbol)],
                    builder: (context, live) => _Headline(
                      row: headline,
                      quote: live[headline.symbol] ?? headline.quote,
                      bars: _barsFor(headline.symbol),
                      others: [for (final r in others) (r, live[r.symbol] ?? r.quote)],
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                child: Row(
                  children: [
                    Expanded(child: Text('LATEST SIGNALS', style: labelCaps(p))),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: p.foreground),
                      onPressed: () => openSignals(context),
                      child: const Text('All →'),
                    ),
                  ],
                ),
              ),
              FutureBuilder<List<SignalEvent>>(
                future: _signals,
                builder: (context, snapshot) {
                  final signals = snapshot.data ?? const <SignalEvent>[];
                  if (!snapshot.hasData) return const Padding(padding: EdgeInsets.symmetric(horizontal: 22), child: Skeleton(height: 120));
                  if (signals.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Text(
                        'No signals yet. Monitor a stock and the Adviser’s calls appear here.',
                        style: TextStyle(fontSize: 13, color: p.mutedForeground),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(children: [for (final s in signals.take(3)) _SignalRow(signal: s)]),
                  );
                },
              ),
              FutureBuilder<List<AdviserSession>>(
                future: _sessions,
                builder: (context, snapshot) {
                  final live = snapshot.data?.where((s) => s.status == 'active').length ?? 0;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                    child: Material(
                      color: p.surfaceMuted,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => openStrategy(context, live > 0 ? const StrategyIntent.adviser() : const StrategyIntent.selector()),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: live > 0 ? p.gain : p.border, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: live > 0
                                        ? [
                                            const TextSpan(
                                              text: 'Adviser is live ',
                                              style: TextStyle(fontWeight: FontWeight.w700),
                                            ),
                                            TextSpan(
                                              text: 'on $live ticker${live == 1 ? '' : 's'}',
                                              style: TextStyle(color: p.mutedForeground),
                                            ),
                                          ]
                                        : [
                                            const TextSpan(
                                              text: 'Build your strategy ',
                                              style: TextStyle(fontWeight: FontWeight.w700),
                                            ),
                                            TextSpan(
                                              text: 'select · optimize · advise',
                                              style: TextStyle(color: p.mutedForeground),
                                            ),
                                          ],
                                  ),
                                  style: const TextStyle(fontSize: 13.5),
                                ),
                              ),
                              Text(live > 0 ? 'Strategy →' : 'Start →', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (settings.showWatchlistOnHome)
                FutureBuilder<List<MarketRow>>(
                  future: _watchlist,
                  builder: (context, snapshot) {
                    final rows = snapshot.data ?? const <MarketRow>[];
                    if (rows.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(22, 26, 22, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('WATCHLIST', style: labelCaps(p)),
                          const SizedBox(height: 4),
                          MarketList(rows: settings.sortWatchlist(rows).take(6).toList(), showViewSwitch: false),
                        ],
                      ),
                    );
                  },
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 0),
                child: Text(
                  'Stockiser recommends; it never places trades. You act through your own broker.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: p.mutedForeground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    style: IconButton.styleFrom(backgroundColor: context.palette.surfaceMuted, fixedSize: const Size(44, 44)),
    icon: Icon(icon, size: 20),
  );
}

/// The headline index: label, large light price, change, a month's line drawn
/// edge to edge, then two more markets in a hairline strip. Tap to open.
class _Headline extends StatelessWidget {
  const _Headline({required this.row, required this.quote, required this.bars, required this.others});

  final MarketRow row;
  final Quote? quote;
  final Future<List<Bar>> bars;
  final List<(MarketRow, Quote?)> others;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final change = quote?.changePercent;
    final tone = (change ?? 0) < 0 ? p.loss : p.gain;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => openSymbol(context, row.symbol),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(row.info.name.toUpperCase(), style: labelCaps(p)),
                    const SizedBox(width: 8),
                    SourceBadge(source: row.info.dataSource),
                  ],
                ),
                const SizedBox(height: 2),
                TickingPrice(
                  value: quote?.price,
                  style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w300, height: 1.1, fontFeatures: priceFeatures),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${formatSigned(quote?.change)} (${formatPercent(change)})',
                        style: TextStyle(color: tone, fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: '  today',
                        style: TextStyle(color: p.mutedForeground),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Bar>>(
          future: bars,
          builder: (context, snapshot) => SizedBox(
            height: 92,
            width: double.infinity,
            child: snapshot.hasData && snapshot.data!.length > 1
                ? CustomPaint(painter: _Sparkline(snapshot.data!.map((b) => b.close).toList(), tone))
                : null,
          ),
        ),
        if (others.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(22, 6, 22, 0),
            decoration: BoxDecoration(
              border: Border.symmetric(horizontal: BorderSide(color: p.border)),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  for (var i = 0; i < others.length; i++) ...[
                    if (i > 0) VerticalDivider(width: 1, color: p.border),
                    Expanded(
                      child: InkWell(
                        onTap: () => openSymbol(context, others[i].$1.symbol),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(i == 0 ? 0 : 14, 12, 8, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                others[i].$1.info.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.mutedForeground),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Flexible(
                                    child: Text(
                                      formatNumber(others[i].$2?.price),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w300, fontFeatures: priceFeatures),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  ChangeText(
                                    others[i].$2?.changePercent,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A month of closes as a thin line over a soft fade, full width.
class _Sparkline extends CustomPainter {
  _Sparkline(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final span = (hi - lo) == 0 ? 1 : hi - lo;
    Offset at(int i) => Offset(size.width * i / (values.length - 1), 8 + (size.height - 16) * (1 - (values[i] - lo) / span));
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.14), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _Sparkline old) => old.values != values || old.color != color;
}

/// One signal: symbol over name and time, the call as a soft pill, confidence.
class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.signal});

  final SignalEvent signal;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final time = parseApiTime(signal.emittedAt);
    return InkWell(
      onTap: () => openSymbol(context, signal.symbol),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.border)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            TickerLogo(symbol: signal.displaySymbol, logoUrl: signal.logoUrl, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(signal.displaySymbol, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(
                    '${signal.name}${time == null ? '' : ' · ${formatClock(time.toLocal())}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: p.mutedForeground),
                  ),
                ],
              ),
            ),
            SignalBadge(type: signal.signalType, size: BadgeSize.sm),
            SizedBox(
              width: 42,
              child: Text(
                '${(signal.confidence * 100).round()}%',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: p.mutedForeground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
