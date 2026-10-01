import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/market.dart';
import '../models/strategy.dart';
import '../navigation.dart';
import '../services/api_client.dart';
import '../state/auth_provider.dart';
import '../state/shell_controller.dart';
import '../theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/common.dart';
import '../widgets/flag.dart';
import '../widgets/market_widgets.dart';
import '../widgets/signal_tile.dart';

/// Home: headline indices, the Selector → Optimizer → Adviser pipeline, the
/// user's latest signals, then markets → exchanges → tickers to explore.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<MarketRow>> _indices;
  late Future<List<Country>> _countries;
  late Future<List<Exchange>> _exchanges;
  late Future<Movers> _movers;
  late Future<List<SignalEvent>> _signals;
  late Future<List<MarketRow>> _watchlist;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = context.read<ApiClient>();
    final token = context.read<AuthProvider>().token!;
    _indices = api.indices();
    _countries = api.countries();
    _exchanges = api.exchanges();
    _movers = api.movers(limit: 5);
    _signals = api.signals(token);
    _watchlist = api.watchlist(token);
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait<Object>([_indices, _exchanges, _movers]).then<void>((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  children: [
                    const BrandMark(size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_greeting()}, ${user?.firstName ?? ''}'.trim(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                          Text('Evalucre Capital · algebraic adviser', style: TextStyle(fontSize: 12.5, color: p.brand, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    IconButton(tooltip: 'Search', onPressed: () => openSearch(context), icon: const Icon(Icons.search)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: _SearchBarButton(onTap: () => openSearch(context)),
              ),
              AsyncView<List<MarketRow>>(
                future: _indices,
                onRetry: () => setState(_load),
                loading: SizedBox(
                  height: 104,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 4,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, _) => const Skeleton(width: 170, height: 104, radius: 16),
                  ),
                ),
                builder: (context, rows) => IndexStrip(rows: rows.take(10).toList()),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader('Strategy pipeline', subtitle: 'Rank → tune → monitor. Tap a stage to start.'),
                    const _PipelineCards(),
                    FutureBuilder<List<SignalEvent>>(
                      future: _signals,
                      builder: (context, snapshot) {
                        final signals = snapshot.data ?? const [];
                        if (signals.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SectionHeader(
                              'Latest signals',
                              action: TextButton(
                                onPressed: () => openStrategy(context, const StrategyIntent.adviser()),
                                child: const Text('Adviser →'),
                              ),
                            ),
                            SectionCard(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              child: Column(
                                children: [
                                  for (var i = 0; i < signals.length && i < 3; i++) ...[
                                    if (i > 0) const Divider(),
                                    SignalEventTile(signal: signals[i]),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    SectionHeader(
                      'Markets',
                      subtitle: 'Pick a country to see its indices, movers and exchanges.',
                      action: TextButton(onPressed: () => context.read<ShellController>().select(ShellTab.markets), child: const Text('World →')),
                    ),
                  ],
                ),
              ),
              AsyncView<List<Country>>(
                future: _countries,
                onRetry: () => setState(_load),
                loading: const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Skeleton(height: 44)),
                builder: (context, countries) => _CountryStrip(countries: countries),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      'Exchanges',
                      subtitle: 'Open markets first. Tap one to browse its listed tickers.',
                      action: TextButton(onPressed: () => context.read<ShellController>().select(ShellTab.markets), child: const Text('All →')),
                    ),
                    AsyncView<List<Exchange>>(
                      future: _exchanges,
                      onRetry: () => setState(_load),
                      builder: (context, exchanges) {
                        final sorted = [...exchanges]..sort((a, b) => (b.isOpen ? 1 : 0) - (a.isOpen ? 1 : 0));
                        return Column(
                          children: [
                            for (final e in sorted.take(5)) Padding(padding: const EdgeInsets.only(bottom: 8), child: ExchangeTile(exchange: e)),
                          ],
                        );
                      },
                    ),
                    const SectionHeader('Today’s movers', subtitle: 'Across every covered exchange.'),
                    AsyncView<Movers>(
                      future: _movers,
                      onRetry: () => setState(_load),
                      builder: (context, movers) => MoversBoard(movers: movers, compact: true),
                    ),
                    FutureBuilder<List<MarketRow>>(
                      future: _watchlist,
                      builder: (context, snapshot) {
                        final rows = snapshot.data ?? const [];
                        if (rows.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SectionHeader('Your watchlist'),
                            SectionCard(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: MarketList(rows: rows, showViewSwitch: false),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    const Notice(
                      'Key principle: the Adviser never executes trades — it emits signals, which you can act on through your own broker.',
                      icon: Icons.shield_outlined,
                    ),
                  ],
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

class _SearchBarButton extends StatelessWidget {
  const _SearchBarButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surfaceMuted,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(Icons.search, color: p.mutedForeground, size: 20),
              const SizedBox(width: 10),
              Text('Search tickers, e.g. Dangote, SHOP, 005930', style: TextStyle(color: p.mutedForeground)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PipelineCards extends StatelessWidget {
  const _PipelineCards();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final modules = [
      (
        'Selector',
        'Rank an exchange’s stocks over a period and keep the top N.',
        Icons.filter_alt_outlined,
        p.brand,
        p.brandSoft,
        const StrategyIntent.selector(),
      ),
      (
        'Optimizer',
        'Tune the signal on a training period; test it out-of-sample.',
        Icons.tune,
        p.hold,
        p.holdSoft,
        const StrategyIntent.optimizer(),
      ),
      (
        'Adviser',
        'Monitor tickers and get BUY / SELL / HOLD in real time.',
        Icons.notifications_active_outlined,
        p.gain,
        p.gainSoft,
        const StrategyIntent.adviser(),
      ),
    ];
    return Column(
      children: [
        for (var i = 0; i < modules.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => openStrategy(context, modules[i].$6),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: modules[i].$5, borderRadius: BorderRadius.circular(14)),
                        child: Icon(modules[i].$3, color: modules[i].$4),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${i + 1} · ${modules[i].$1}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(modules[i].$2, style: TextStyle(fontSize: 13, color: p.mutedForeground)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: p.mutedForeground),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CountryStrip extends StatelessWidget {
  const _CountryStrip({required this.countries});

  final List<Country> countries;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: countries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = countries[i];
          return ActionChip(
            avatar: Text(Flag.emoji(c.code)),
            label: Text.rich(TextSpan(children: [
              TextSpan(text: c.name),
              TextSpan(text: '  ${c.exchangeCount}', style: TextStyle(color: p.mutedForeground, fontSize: 12)),
            ])),
            onPressed: () => openCountry(context, c.code),
          );
        },
      ),
    );
  }
}
