import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models/strategy.dart';
import '../navigation.dart';
import '../services/api_client.dart';
import '../services/realtime_client.dart';
import '../state/auth_provider.dart';
import '../state/shell_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/signal_tile.dart';

/// The Signals tab: every signal the Adviser has emitted for this user,
/// newest first and grouped by day, updated live over the socket.
class SignalsScreen extends StatefulWidget {
  const SignalsScreen({super.key});

  @override
  State<SignalsScreen> createState() => _SignalsScreenState();
}

class _SignalsScreenState extends State<SignalsScreen> {
  List<SignalEvent>? _signals;
  List<AdviserSession> _sessions = const [];
  String? _error;
  SignalType? _filter;
  StreamSubscription<SignalEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = context.read<RealtimeClient>().signals.listen((s) {
      final current = _signals;
      if (!mounted || current == null || current.any((x) => x.id == s.id)) return;
      setState(() => _signals = [s, ...current]);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token;
    final api = context.read<ApiClient>();
    if (token == null) return;
    try {
      final results = await Future.wait([api.signals(token), api.sessions(token)]);
      if (!mounted) return;
      setState(() {
        _signals = results[0] as List<SignalEvent>;
        _sessions = results[1] as List<AdviserSession>;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
  }

  static String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(day.year, day.month, day.day)).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    return DateFormat('EEE d MMM').format(day).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final active = _sessions.where((s) => s.status == 'active').toList();
    final visible = (_signals ?? const <SignalEvent>[]).where((s) => _filter == null || s.signalType == _filter).toList();

    // Group by local calendar day, preserving newest-first order.
    final groups = <String, List<SignalEvent>>{};
    for (final s in visible) {
      final t = parseApiTime(s.emittedAt);
      groups.putIfAbsent(t == null ? 'EARLIER' : _dayLabel(t), () => []).add(s);
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Signals', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700))),
                  if (active.isNotEmpty) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: p.gain, shape: BoxShape.circle, boxShadow: [BoxShadow(color: p.gainSoft, spreadRadius: 4)]),
                    ),
                    const SizedBox(width: 8),
                    Text('Live', style: TextStyle(color: p.gain, fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      active.isEmpty
                          ? 'Nothing is being monitored.'
                          : 'Watching ${active.map((s) => s.ticker.displaySymbol).join(', ')} every ${formatInterval(active.first.intervalSec)}',
                      style: TextStyle(fontSize: 13, color: p.mutedForeground),
                    ),
                  ),
                  TextButton(
                    onPressed: () => openStrategy(context, const StrategyIntent.adviser()),
                    child: Text(active.isEmpty ? 'Start' : 'Manage'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final (type, label) in const [(null, 'All'), (SignalType.buy, 'Buy'), (SignalType.hold, 'Hold'), (SignalType.sell, 'Sell')])
                    ChoiceChip(
                      label: Text(label, style: TextStyle(color: _filter == type ? p.inkForeground : p.foreground)),
                      selected: _filter == type,
                      onSelected: (_) => setState(() => _filter = type),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_error != null) ErrorNote(_error, onRetry: _load),
              if (_signals == null && _error == null) const Padding(padding: EdgeInsets.only(top: 16), child: SkeletonList(count: 6, height: 56)),
              if (_signals != null && visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: EmptyState(
                    title: 'No signals yet',
                    message: 'Monitor a ticker with the Adviser and its BUY, SELL and HOLD signals will appear here.',
                    icon: Icons.show_chart,
                  ),
                ),
              for (final entry in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 18, bottom: 2),
                  child: Text(entry.key, style: labelCaps(p)),
                ),
                for (final s in entry.value) SignalEventTile(signal: s, showDate: false),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
