import 'package:flutter/foundation.dart';

enum ShellTab { home, markets, strategy, signals, profile }

enum StrategyStage { selector, optimizer, adviser }

/// A hand-off into the Strategy tab, e.g. "rank this exchange" from an
/// exchange page or "send to Optimizer" from a Selector run.
class StrategyIntent {
  const StrategyIntent.selector({this.exchange}) : stage = StrategyStage.selector, selectorRunId = null, symbol = null;
  const StrategyIntent.optimizer({this.selectorRunId, this.symbol}) : stage = StrategyStage.optimizer, exchange = null;
  const StrategyIntent.adviser() : stage = StrategyStage.adviser, exchange = null, selectorRunId = null, symbol = null;

  final StrategyStage stage;
  final String? exchange;
  final String? selectorRunId;
  final String? symbol;
}

/// Bottom-navigation state plus pending hand-offs, so any screen can jump to
/// another tab (the Selector → Optimizer → Adviser pipeline crosses screens).
class ShellController extends ChangeNotifier {
  ShellTab tab = ShellTab.home;
  StrategyIntent? _pending;
  int _intentSerial = 0;

  /// Increments with every new intent, so listeners can tell them apart.
  int get intentSerial => _intentSerial;

  void select(ShellTab next) {
    if (next == tab) return;
    tab = next;
    notifyListeners();
  }

  void openStrategy(StrategyIntent intent) {
    _pending = intent;
    _intentSerial++;
    tab = ShellTab.strategy;
    notifyListeners();
  }

  /// Returns the pending intent for [stage] once, then forgets it.
  StrategyIntent? take(StrategyStage stage) {
    final intent = _pending;
    if (intent == null || intent.stage != stage) return null;
    _pending = null;
    return intent;
  }

  StrategyStage? get pendingStage => _pending?.stage;

  void reset() {
    tab = ShellTab.home;
    _pending = null;
  }
}
