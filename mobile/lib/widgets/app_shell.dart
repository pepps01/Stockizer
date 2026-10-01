import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models/strategy.dart';
import '../navigation.dart';
import '../screens/dashboard_screen.dart';
import '../screens/markets_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/strategy_screen.dart';
import '../services/realtime_client.dart';
import '../state/auth_provider.dart';
import '../state/shell_controller.dart';
import '../theme.dart';
import 'badges.dart';

/// Signed-in shell: Home · Markets · Strategy · Profile. Also surfaces
/// Adviser signals pushed over the socket as banners (the web SignalToaster).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final RealtimeClient _realtime = context.read<RealtimeClient>();
  StreamSubscription<SignalEvent>? _signalSub;

  static const _screens = [DashboardScreen(), MarketsScreen(), StrategyScreen(), ProfileScreen()];

  @override
  void initState() {
    super.initState();
    _realtime.listenForSignals();
    _signalSub = _realtime.signals.listen(_announce);
  }

  @override
  void dispose() {
    _signalSub?.cancel();
    super.dispose();
  }

  void _announce(SignalEvent signal) {
    if (!mounted) return;
    final channels = context.read<AuthProvider>().user?.alertChannels ?? const ['in_app'];
    if (!channels.contains('in_app')) return;
    final p = context.palette;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: SignalBadge.colors(p, signal.signalType).$1, width: 1.5),
          ),
          content: Row(
            children: [
              SignalBadge(type: signal.signalType, size: BadgeSize.sm),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${signal.displaySymbol} · ${formatPrice(signal.price, signal.currency)} · ${(signal.confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: p.foreground, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          action: SnackBarAction(label: 'View', textColor: p.brand, onPressed: () => openStrategy(context, const StrategyIntent.adviser())),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellController>();
    return Scaffold(
      body: IndexedStack(index: shell.tab.index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.tab.index,
        onDestinationSelected: (i) => shell.select(ShellTab.values[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.public_outlined), selectedIcon: Icon(Icons.public), label: 'Markets'),
          NavigationDestination(icon: Icon(Icons.auto_graph_outlined), selectedIcon: Icon(Icons.auto_graph), label: 'Strategy'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
