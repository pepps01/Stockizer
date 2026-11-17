import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/shell_controller.dart';
import '../theme.dart';
import 'adviser_screen.dart';
import 'optimizer_screen.dart';
import 'selector_screen.dart';

/// The three-stage pipeline in one tab: Selector → Optimizer → Adviser.
class StrategyScreen extends StatefulWidget {
  const StrategyScreen({super.key});

  @override
  State<StrategyScreen> createState() => _StrategyScreenState();
}

class _StrategyScreenState extends State<StrategyScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: StrategyStage.values.length, vsync: this);
  late final ShellController _shell = context.read<ShellController>();
  int _seenIntent = 0;

  @override
  void initState() {
    super.initState();
    _shell.addListener(_followIntent);
    _followIntent();
  }

  void _followIntent() {
    final stage = _shell.pendingStage;
    if (stage == null || _shell.intentSerial == _seenIntent) return;
    _seenIntent = _shell.intentSerial;
    _tabs.animateTo(stage.index);
  }

  @override
  void dispose() {
    _shell.removeListener(_followIntent);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Strategy', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        toolbarHeight: 64,
        bottom: TabBar(
          controller: _tabs,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 2,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          tabs: [
            for (final (n, label) in const [('01', 'Selector'), ('02', 'Optimizer'), ('03', 'Adviser')])
              Tab(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$n  ', style: const TextStyle(fontWeight: FontWeight.w300, fontFeatures: priceFeatures)),
                      TextSpan(text: label),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [SelectorScreen(), OptimizerScreen(), AdviserScreen()],
      ),
    );
  }
}

/// Lets a pipeline stage pick up hand-offs (e.g. "send to Optimizer") whether
/// it is already built or built because of the hand-off.
mixin StrategyIntentConsumer<T extends StatefulWidget> on State<T> {
  StrategyStage get stage;
  void applyIntent(StrategyIntent intent);

  late final ShellController _intentShell = context.read<ShellController>();

  @override
  void initState() {
    super.initState();
    _intentShell.addListener(_consume);
    WidgetsBinding.instance.addPostFrameCallback((_) => _consume());
  }

  void _consume() {
    if (!mounted) return;
    final intent = _intentShell.take(stage);
    if (intent != null) applyIntent(intent);
  }

  @override
  void dispose() {
    _intentShell.removeListener(_consume);
    super.dispose();
  }
}
