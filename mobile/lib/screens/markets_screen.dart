import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/market.dart';
import '../navigation.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/flag.dart';
import '../widgets/market_widgets.dart';
import '../widgets/paged_list.dart';

/// World or single-country market page: indices, movers and every covered
/// exchange (frontend /markets?country=…). Used as the Markets tab and as a
/// pushed page when a country is picked elsewhere.
class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key, this.country});

  final String? country;

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  late String? _country = widget.country?.toUpperCase();
  late final Future<List<Country>> _countries = context.read<ApiClient>().countries();
  late Future<List<MarketRow>> _indices;
  late Future<Movers> _movers;
  late Future<List<Exchange>> _exchanges;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = context.read<ApiClient>();
    _indices = api.indices(country: _country);
    _movers = api.movers(country: _country, limit: 6);
    _exchanges = api.exchanges(country: _country);
  }

  void _setCountry(String? code) => setState(() {
    _country = code;
    _load();
  });

  Future<void> _pickCountry(List<Country> countries) async {
    final picked = await showModalBottomSheet<_CountryPick>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CountrySheet(countries: countries, selected: _country),
    );
    if (picked != null) _setCountry(picked.code);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FutureBuilder<List<Country>>(
      future: _countries,
      builder: (context, snapshot) {
        final countries = snapshot.data ?? const <Country>[];
        final country = countries.where((c) => c.code == _country).firstOrNull;
        final title = _country == null ? 'World markets' : '${country?.name ?? _country} market';
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                if (_country != null) ...[Flag(code: _country!, size: 30), const SizedBox(width: 10)],
                Expanded(child: Text(title, overflow: TextOverflow.ellipsis)),
              ],
            ),
            actions: [IconButton(tooltip: 'Search', onPressed: () => openSearch(context), icon: const Icon(Icons.search))],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              setState(_load);
              await _indices.then<void>((_) {}, onError: (_) {});
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                Text(
                  'Major indices, the day’s movers and every covered exchange. Prices stream live; markets without a free feed are marked Simulated.',
                  style: TextStyle(color: p.mutedForeground, fontSize: 13.5),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: countries.isEmpty ? null : () => _pickCountry(countries),
                  icon: Text(_country == null ? '🌐' : Flag.emoji(_country!), style: const TextStyle(fontSize: 18)),
                  label: Row(
                    children: [
                      Expanded(child: Text(_country == null ? 'All countries' : (country?.name ?? _country!))),
                      const Icon(Icons.expand_more, size: 20),
                    ],
                  ),
                ),
                SectionHeader(_country == null ? 'Major world indices' : 'Indices'),
                AsyncView<List<MarketRow>>(
                  future: _indices,
                  onRetry: () => setState(_load),
                  builder: (context, rows) => rows.isEmpty
                      ? const SectionCard(
                          child: EmptyState(title: 'No index tracked for this country yet', icon: Icons.show_chart),
                        )
                      : SectionCard(
                          // Keyed by country so picking another country starts on page 1.
                          child: PagedList<MarketRow>(
                            key: ValueKey(_country),
                            items: rows,
                            noun: 'indices',
                            builder: (context, page) => MarketList(rows: page, showCountry: _country == null),
                          ),
                        ),
                ),
                const SectionHeader('Movers'),
                AsyncView<Movers>(
                  future: _movers,
                  onRetry: () => setState(_load),
                  builder: (context, movers) => MoversBoard(movers: movers),
                ),
                const SectionHeader('Exchanges', subtitle: 'Tap an exchange to browse its tickers and rank them with the Selector.'),
                AsyncView<List<Exchange>>(
                  future: _exchanges,
                  onRetry: () => setState(_load),
                  // Keyed by country so picking another country starts on page 1.
                  builder: (context, exchanges) => PagedExchanges(key: ValueKey(_country), exchanges: exchanges),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CountryPick {
  const _CountryPick(this.code);
  final String? code;
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.countries, required this.selected});

  final List<Country> countries;
  final String? selected;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final q = _query.toLowerCase();
    final matches = widget.countries.where((c) => q.isEmpty || '${c.name} ${c.code} ${c.region}'.toLowerCase().contains(q)).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search country or region'),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const Text('🌐', style: TextStyle(fontSize: 24)),
                  title: const Text('All countries'),
                  trailing: widget.selected == null ? Icon(Icons.check, color: p.brand) : null,
                  onTap: () => Navigator.pop(context, const _CountryPick(null)),
                ),
                for (final c in matches)
                  ListTile(
                    leading: Flag(code: c.code, size: 32),
                    title: Text(c.name),
                    subtitle: Text('${c.region} · ${c.exchangeCount} exchange${c.exchangeCount == 1 ? '' : 's'} · ${c.currency}'),
                    trailing: c.code == widget.selected ? Icon(Icons.check, color: p.brand) : null,
                    onTap: () => Navigator.pop(context, _CountryPick(c.code)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The exchanges six at a time.
class PagedExchanges extends StatelessWidget {
  const PagedExchanges({super.key, required this.exchanges});

  final List<Exchange> exchanges;

  @override
  Widget build(BuildContext context) {
    if (exchanges.isEmpty) {
      return const SectionCard(
        child: EmptyState(title: 'No exchange covered here yet', icon: Icons.account_balance),
      );
    }
    return PagedList<Exchange>(
      items: exchanges,
      noun: 'exchanges',
      builder: (context, page) => Column(
        children: [
          for (final e in page)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ExchangeTile(exchange: e),
            ),
        ],
      ),
    );
  }
}
