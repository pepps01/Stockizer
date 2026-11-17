import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/market.dart';
import '../navigation.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../widgets/badges.dart';
import '../widgets/common.dart';
import '../widgets/ticker_logo.dart';

/// Symbol search across every exchange. In [pickMode] it pops with the chosen
/// [TickerInfo] instead of opening the symbol page.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.pickMode = false, this.title});

  final bool pickMode;
  final String? title;

  static Future<TickerInfo?> pick(BuildContext context, {String title = 'Choose a ticker'}) =>
      Navigator.of(context)
          .push<TickerInfo>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => SearchScreen(pickMode: true, title: title)));

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  Timer? _debounce;
  String _query = '';
  Future<List<TickerInfo>>? _results;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      final query = text.trim();
      if (!mounted || query == _query) return;
      setState(() {
        _query = query;
        _results = query.isEmpty ? null : context.read<ApiClient>().search(query);
      });
    });
  }

  void _choose(TickerInfo ticker) {
    if (widget.pickMode) {
      Navigator.of(context).pop(ticker);
    } else {
      openSymbol(context, ticker.symbol);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Search'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Company, symbol or index — e.g. Dangote, SHOP, 005930',
              ),
            ),
          ),
        ),
      ),
      body: _results == null
          ? EmptyState(
              title: 'Search 37 exchanges',
              message: 'Stocks and indices from New York to Lagos, Nairobi, Riyadh and Tokyo.',
              icon: Icons.travel_explore,
            )
          : FutureBuilder<List<TickerInfo>>(
              future: _results,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(16), child: ErrorNote(errorMessage(snapshot.error)));
                if (!snapshot.hasData) return const LinearProgressIndicator(minHeight: 2);
                final results = snapshot.data!;
                if (results.isEmpty) return EmptyState(title: 'No matches for “$_query”', icon: Icons.search_off);
                return ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const Divider(indent: 72),
                  itemBuilder: (context, i) {
                    final t = results[i];
                    return ListTile(
                      leading: TickerLogo(symbol: t.displaySymbol, logoUrl: t.logoUrl, countryCode: t.countryCode, size: 36),
                      title: Row(
                        children: [
                          Text(t.displaySymbol, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          if (t.isIndex)
                            Text(
                              'INDEX',
                              style: TextStyle(fontSize: 10, color: p.brand, fontWeight: FontWeight.w700),
                            ),
                          const SizedBox(width: 6),
                          SourceBadge(source: t.dataSource),
                        ],
                      ),
                      subtitle: Text('${t.name} · ${t.exchange}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Icon(widget.pickMode ? Icons.add_circle_outline : Icons.chevron_right, color: p.mutedForeground),
                      onTap: () => _choose(t),
                    );
                  },
                );
              },
            ),
    );
  }
}
