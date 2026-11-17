import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models/strategy.dart';
import '../navigation.dart';
import '../screens/dashboard_screen.dart';
import '../screens/markets_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/signals_screen.dart';
import '../screens/strategy_screen.dart';
import '../services/realtime_client.dart';
import '../state/push_registrar.dart';
import '../state/auth_provider.dart';
import '../state/shell_controller.dart';
import '../theme.dart';
import 'badges.dart';
import 'motion.dart';

/// Signed-in shell: Home · Markets · Strategy · Signals · Profile, with the
/// floating pill navigation from the Quiet Ledger design. Also surfaces
/// Adviser signals pushed over the socket as banners (the web SignalToaster).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  late final RealtimeClient _realtime = context.read<RealtimeClient>();
  late final PushRegistrar _push = context.read<PushRegistrar>();
  StreamSubscription<SignalEvent>? _signalSub;
  StreamSubscription<void>? _openedSub;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  static const _screens = [DashboardScreen(), MarketsScreen(), StrategyScreen(), SignalsScreen(), ProfileScreen()];

  static const _tabs = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.public_outlined, Icons.public, 'Markets'),
    (Icons.tune_outlined, Icons.tune, 'Strategy'),
    (Icons.show_chart_outlined, Icons.show_chart, 'Signals'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _realtime.listenForSignals();
    _signalSub = _realtime.signals.listen(_announce);
    _openedSub = _push.push.opened.listen((_) {
      if (mounted) openTab(context, ShellTab.signals);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _lifecycle = state;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _signalSub?.cancel();
    _openedSub?.cancel();
    super.dispose();
  }

  void _announce(SignalEvent signal) {
    if (!mounted) return;
    final channels = context.read<AuthProvider>().user?.alertChannels ?? const ['in_app'];
    if (_lifecycle != AppLifecycleState.resumed) {
      // In the background: a system notification, unless FCM already delivers it.
      final serverPushes = channels.contains('push') && _push.push.remoteAvailable;
      if (!serverPushes && (channels.contains('push') || channels.contains('in_app'))) {
        unawaited(_push.push.showSignal(signal));
      }
      return;
    }
    if (!channels.contains('in_app')) return;
    Haptics.alert();
    final p = context.palette;
    final (tone, _) = SignalBadge.colors(p, signal.signalType);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${signal.signalType.wire} · ${signal.displaySymbol}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: '  at ${formatPrice(signal.price, signal.currency)} · ${(signal.confidence * 100).toStringAsFixed(0)}%',
                      ),
                    ],
                  ),
                  style: TextStyle(color: p.inkForeground, fontSize: 14),
                ),
              ),
            ],
          ),
          action: SnackBarAction(label: 'View', textColor: p.brandSoft, onPressed: () => openTab(context, ShellTab.signals)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellController>();
    return Scaffold(
      body: IndexedStack(index: shell.tab.index, children: _screens),
      bottomNavigationBar: _PillNavigation(
        selected: shell.tab.index,
        tabs: _tabs,
        onSelect: (i) {
          if (i != shell.tab.index) Haptics.tick();
          shell.select(ShellTab.values[i]);
        },
      ),
    );
  }
}

/// Floating navigation: a black pill of labels, the selected tab lifted into
/// a mint pill with its icon (the logo colours, as on the web buttons).
class _PillNavigation extends StatelessWidget {
  const _PillNavigation({required this.selected, required this.tabs, required this.onSelect});

  final int selected;
  final List<(IconData, IconData, String)> tabs;
  final ValueChanged<int> onSelect;

  static const _ink = Color(0xFF0F1411);
  static const _idle = Color(0xFF9AA39D);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      color: p.background,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
          child: Container(
            height: 60,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _ink,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    flex: i == selected ? 13 : 10,
                    child: Semantics(
                      button: true,
                      selected: i == selected,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelect(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i == selected ? brandMint : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (i == selected) ...[Icon(tabs[i].$2, size: 17, color: brandForest), const SizedBox(width: 5)],
                                Text(
                                  tabs[i].$3,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: i == selected ? FontWeight.w900 : FontWeight.w700,
                                    color: i == selected ? brandForest : _idle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
