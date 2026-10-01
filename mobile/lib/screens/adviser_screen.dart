import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models/market.dart';
import '../models/strategy.dart';
import '../navigation.dart';
import '../services/api_client.dart';
import '../services/realtime_client.dart';
import '../state/auth_provider.dart';
import '../state/shell_controller.dart';
import '../theme.dart';
import '../widgets/badges.dart';
import '../widgets/common.dart';
import '../widgets/live_quotes.dart';
import '../widgets/signal_tile.dart';
import 'search_screen.dart';
import 'strategy_screen.dart';
import 'ticker_detail_screen.dart' show monitorIntervals;

/// Stage 3 (frontend /adviser): monitored tickers and the live signal feed —
/// green BUY, red SELL, orange HOLD, pushed over the socket. Never trades.
class AdviserScreen extends StatefulWidget {
  const AdviserScreen({super.key});

  @override
  State<AdviserScreen> createState() => _AdviserScreenState();
}

class _AdviserScreenState extends State<AdviserScreen> with AutomaticKeepAliveClientMixin, StrategyIntentConsumer {
  late final ApiClient _api = context.read<ApiClient>();
  late final RealtimeClient _realtime = context.read<RealtimeClient>();
  late final String _token = context.read<AuthProvider>().token!;
  late Future<List<AdviserSession>> _sessions = _api.sessions(_token);
  late Future<List<SignalEvent>> _history = _api.signals(_token);
  final List<SignalEvent> _pushed = [];
  StreamSubscription<SignalEvent>? _signalSub;

  @override
  bool get wantKeepAlive => true;

  @override
  StrategyStage get stage => StrategyStage.adviser;

  @override
  void applyIntent(StrategyIntent intent) => _reloadSessions();

  @override
  void initState() {
    super.initState();
    _realtime.listenForSignals();
    _signalSub = _realtime.signals.listen((signal) {
      if (!mounted) return;
      setState(() {
        _pushed
          ..removeWhere((s) => s.id == signal.id)
          ..insert(0, signal);
        if (_pushed.length > 100) _pushed.removeLast();
        _sessions = _api.sessions(_token);
      });
    });
  }

  @override
  void dispose() {
    _signalSub?.cancel();
    super.dispose();
  }

  void _reloadSessions() => setState(() => _sessions = _api.sessions(_token));

  Future<void> _act(AdviserSession session, String action) async {
    try {
      if (action == 'evaluate') {
        final signal = await _api.evaluateSession(_token, session.id);
        if (mounted && signal == null) showSnack(context, 'Checked — no new signal for ${session.ticker.displaySymbol}.');
      } else {
        await _api.updateSession(_token, session.id, action);
      }
      _reloadSessions();
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.palette;
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _sessions = _api.sessions(_token);
          _history = _api.signals(_token);
        });
        await _sessions.then<void>((_) {}, onError: (_) {});
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Monitors your tickers at the interval you choose and emits colour-coded decision signals — green BUY, red SELL, orange HOLD — pushed to you in real time. It never places trades.',
            style: TextStyle(color: p.mutedForeground, fontSize: 13.5),
          ),
          const SizedBox(height: 14),
          _NewSession(onCreated: _reloadSessions),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Monitored tickers',
            action: ValueListenableBuilder<RealtimeState>(
              valueListenable: _realtime.state,
              builder: (context, state, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: state == RealtimeState.open ? p.gain : p.hold, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(state == RealtimeState.open ? 'Live' : 'Reconnecting…', style: TextStyle(fontSize: 12, color: p.mutedForeground)),
                ],
              ),
            ),
            child: AsyncView<List<AdviserSession>>(
              future: _sessions,
              onRetry: _reloadSessions,
              builder: (context, sessions) {
                final visible = sessions.where((s) => s.status != 'stopped').toList();
                if (visible.isEmpty) {
                  return const EmptyState(
                    title: 'Nothing monitored yet',
                    message: 'Add a ticker above, or start monitoring from any symbol page or Optimizer result.',
                    icon: Icons.notifications_none,
                  );
                }
                return LiveQuotes(
                  symbols: visible.map((s) => s.ticker.symbol),
                  builder: (context, live) => Column(
                    children: [
                      for (final s in visible)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SessionTile(session: s, quote: live[s.ticker.symbol], onAction: (a) => _act(s, a)),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Signal feed',
            child: FutureBuilder<List<SignalEvent>>(
              future: _history,
              builder: (context, snapshot) {
                final ids = _pushed.map((s) => s.id).toSet();
                final feed = [..._pushed, ...(snapshot.data ?? const <SignalEvent>[]).where((s) => !ids.contains(s.id))].take(100).toList();
                if (snapshot.hasError && feed.isEmpty) return ErrorNote(errorMessage(snapshot.error));
                if (feed.isEmpty) {
                  return Text('Signals appear here the moment the Adviser emits them.', style: TextStyle(color: p.mutedForeground, fontSize: 13));
                }
                return Column(
                  children: [
                    for (var i = 0; i < feed.length; i++) ...[if (i > 0) const Divider(), SignalEventTile(signal: feed[i])],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.quote, required this.onAction});

  final AdviserSession session;
  final Quote? quote;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = session;
    final edge = s.lastSignalType == null ? p.border : SignalBadge.colors(p, s.lastSignalType!).$1;
    final detail = TextStyle(fontSize: 12, color: p.mutedForeground);
    return Opacity(
      opacity: s.isActive ? 1 : 0.6,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: p.border),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: edge),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          InkWell(
                            onTap: () => openSymbol(context, s.ticker.symbol),
                            child: Text(s.ticker.displaySymbol, style: TextStyle(fontWeight: FontWeight.w700, color: p.brand)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(s.ticker.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: detail)),
                          SourceBadge(source: s.ticker.dataSource),
                          const SizedBox(width: 6),
                          SignalBadge(type: s.lastSignalType, size: BadgeSize.sm),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            formatPrice(quote?.price ?? s.lastPrice, s.ticker.currency),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
                          ),
                          if (quote != null) ChangeText(quote!.changePercent, style: const TextStyle(fontSize: 12)),
                          Text('confidence ${s.lastConfidence != null ? '${(s.lastConfidence! * 100).toStringAsFixed(0)}%' : '—'}', style: detail),
                          Text('every ${formatInterval(s.intervalSec)}', style: detail),
                          Text(s.parameters != null ? 'optimised params' : 'default params', style: detail),
                          Text('checked ${formatDateTime(s.lastEvaluatedAt)}', style: detail),
                        ],
                      ),
                      Row(
                        children: [
                          TextButton.icon(onPressed: () => onAction('evaluate'), icon: const Icon(Icons.refresh, size: 16), label: const Text('Check now')),
                          TextButton.icon(
                            onPressed: () => onAction(s.isActive ? 'paused' : 'active'),
                            icon: Icon(s.isActive ? Icons.pause : Icons.play_arrow, size: 16),
                            label: Text(s.isActive ? 'Pause' : 'Resume'),
                          ),
                          const Spacer(),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: p.loss),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Stop monitoring ${s.ticker.displaySymbol}?'),
                                  content: const Text('The Adviser will stop checking this ticker. Past signals stay in your feed.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Stop')),
                                  ],
                                ),
                              );
                              if (confirmed ?? false) onAction('stopped');
                            },
                            child: const Text('Stop'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewSession extends StatefulWidget {
  const _NewSession({required this.onCreated});

  final VoidCallback onCreated;

  @override
  State<_NewSession> createState() => _NewSessionState();
}

class _NewSessionState extends State<_NewSession> {
  TickerInfo? _ticker;
  Future<List<OptimizerRun>>? _runs;
  String? _runId;
  int _interval = 300;
  bool _busy = false;
  String? _error;

  Future<void> _chooseTicker() async {
    final ticker = await SearchScreen.pick(context, title: 'Monitor a ticker');
    if (ticker == null || !mounted) return;
    setState(() {
      _ticker = ticker;
      _runId = null;
      _runs = context.read<ApiClient>().optimizerRuns(context.read<AuthProvider>().token!, symbol: ticker.symbol);
    });
  }

  Future<void> _start() async {
    final ticker = _ticker;
    if (ticker == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<ApiClient>().createSession(
            context.read<AuthProvider>().token!,
            symbol: ticker.symbol,
            intervalSec: _interval,
            optimizerRunId: _runId,
          );
      if (!mounted) return;
      setState(() {
        _ticker = null;
        _runs = null;
        _runId = null;
      });
      widget.onCreated();
      showSnack(context, 'Monitoring ${ticker.displaySymbol} every ${formatInterval(_interval)}.');
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ticker = _ticker;
    return SectionCard(
      title: 'Monitor a ticker',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledField(
            label: 'Exchange & ticker',
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
              onPressed: _chooseTicker,
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: p.mutedForeground),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ticker == null
                        ? Text('e.g. Dangote, SHOP, 005930', style: TextStyle(color: p.mutedForeground, fontWeight: FontWeight.w400))
                        : Text('${ticker.displaySymbol} · ${ticker.name} · ${ticker.exchange}', overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Interval',
            child: DropdownButtonFormField<int>(
              initialValue: _interval,
              items: [for (final (value, label) in monitorIntervals) DropdownMenuItem(value: value, child: Text(label))],
              onChanged: (v) => setState(() => _interval = v ?? _interval),
            ),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Parameters',
            child: FutureBuilder<List<OptimizerRun>>(
              key: ValueKey(ticker?.symbol),
              future: _runs,
              builder: (context, snapshot) {
                final runs = (snapshot.data ?? const <OptimizerRun>[]).where((r) => r.completed).toList();
                return DropdownButtonFormField<String?>(
                  initialValue: _runId,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Latest optimised / default')),
                    for (final r in runs)
                      DropdownMenuItem<String?>(value: r.id, child: Text('${r.objective} ${r.trainingStart}→${r.trainingEnd}', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: ticker == null ? null : (v) => setState(() => _runId = v),
                );
              },
            ),
          ),
          ErrorNote(_error),
          const SizedBox(height: 12),
          BusyButton(label: 'Start monitoring', icon: Icons.play_arrow_rounded, busy: _busy, onPressed: ticker == null ? null : _start),
        ],
      ),
    );
  }
}
