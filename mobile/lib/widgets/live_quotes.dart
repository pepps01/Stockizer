import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../models/market.dart';
import '../services/realtime_client.dart';

/// Subscribes to [symbols] on the shared socket and rebuilds with the latest
/// streamed quotes — the widget form of the web's `useLiveQuotes` hook.
/// Symbols without a streamed quote yet are simply absent from the map.
class LiveQuotes extends StatefulWidget {
  const LiveQuotes({super.key, required this.symbols, required this.builder});

  final Iterable<String> symbols;
  final Widget Function(BuildContext context, Map<String, Quote> live) builder;

  @override
  State<LiveQuotes> createState() => _LiveQuotesState();
}

class _LiveQuotesState extends State<LiveQuotes> {
  late RealtimeClient _client;
  VoidCallback? _release;
  StreamSubscription<Map<String, Quote>>? _sub;
  List<String> _symbols = const [];
  final Map<String, Quote> _live = {};

  @override
  void initState() {
    super.initState();
    _client = context.read<RealtimeClient>();
    _sub = _client.quotes.listen(_onQuotes);
    _resubscribe();
  }

  @override
  void didUpdateWidget(LiveQuotes oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resubscribe();
  }

  void _resubscribe() {
    final next = {for (final s in widget.symbols) s.toUpperCase()}.toList()..sort();
    if (listEquals(next, _symbols)) return;
    _release?.call();
    _symbols = next;
    _release = next.isEmpty ? null : _client.subscribe(next);
    for (final symbol in next) {
      final cached = _client.latestQuote(symbol);
      if (cached != null) _live[symbol] = cached;
    }
  }

  void _onQuotes(Map<String, Quote> batch) {
    final relevant = batch.entries.where((e) => _symbols.contains(e.key.toUpperCase()));
    if (relevant.isEmpty || !mounted) return;
    setState(() {
      for (final e in relevant) {
        _live[e.key.toUpperCase()] = e.value;
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _release?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _LiveMap(_live));
}

/// Case-insensitive view over the live quote map.
class _LiveMap extends MapView<String, Quote> {
  _LiveMap(super.map);

  @override
  Quote? operator [](Object? key) => super[key is String ? key.toUpperCase() : key];
}
