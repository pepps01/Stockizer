import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models/selector_result.dart';
import '../models/strategy.dart';
import '../navigation.dart';
import '../services/api_client.dart';
import '../state/auth_provider.dart';
import '../state/shell_controller.dart';
import '../theme.dart';
import '../widgets/badges.dart';
import '../widgets/common.dart';
import '../widgets/ticker_logo.dart';
import 'adviser_screen.dart';
import 'optimizer_screen.dart';
import 'selector_screen.dart';

/// The Strategy tab (approved blend of the Checklist and Adviser hub
/// directions): a hub card on top (what the Adviser is doing, or a guide for
/// a new investor), the three steps as a checklist with the next one lifted,
/// then what is running and the latest signals. Each step opens as its own
/// page; finishing one offers the next in a sheet.
class StrategyScreen extends StatefulWidget {
  const StrategyScreen({super.key});

  @override
  State<StrategyScreen> createState() => _StrategyScreenState();
}

class _Progress {
  const _Progress(this.selector, this.optimizer, this.sessions, this.signals);

  final List<SelectorRun> selector;
  final List<OptimizerRun> optimizer;
  final List<AdviserSession> sessions;
  final List<SignalEvent> signals;

  List<OptimizerRun> get tuned => optimizer.where((r) => r.status == 'completed').toList();
  List<AdviserSession> get live => sessions.where((s) => s.status == 'active').toList();

  bool done(StrategyStage stage) => switch (stage) {
    StrategyStage.selector => selector.isNotEmpty,
    StrategyStage.optimizer => tuned.isNotEmpty,
    StrategyStage.adviser => live.isNotEmpty,
  };

  int get doneCount => StrategyStage.values.where(done).length;

  /// The first step not yet done, or null once the Adviser is live.
  StrategyStage? get next => StrategyStage.values.where((s) => !done(s)).firstOrNull;

  int get callsThisWeek {
    final since = DateTime.now().subtract(const Duration(days: 7));
    return signals.where((s) => parseApiTime(s.emittedAt)?.isAfter(since) ?? false).length;
  }
}

class _StrategyScreenState extends State<StrategyScreen> {
  late final ShellController _shell = context.read<ShellController>();
  late Future<_Progress> _progress = _load();
  _Progress? _last;
  int _seenIntent = 0;
  ShellTab _lastTab = ShellTab.home;

  @override
  void initState() {
    super.initState();
    _shell.addListener(_onShell);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onShell());
  }

  @override
  void dispose() {
    _shell.removeListener(_onShell);
    super.dispose();
  }

  Future<_Progress> _load() async {
    final api = context.read<ApiClient>();
    final token = context.read<AuthProvider>().token!;
    final results = await Future.wait<Object>([api.selectorRuns(token), api.optimizerRuns(token), api.sessions(token), api.signals(token)]);
    final progress = _Progress(
      results[0] as List<SelectorRun>,
      results[1] as List<OptimizerRun>,
      results[2] as List<AdviserSession>,
      results[3] as List<SignalEvent>,
    );
    _last = progress;
    return progress;
  }

  void _reload() => setState(() {
    _progress = _load();
  });

  void _onShell() {
    if (!mounted) return;
    // Coming back to the tab: refresh the steps.
    if (_shell.tab != _lastTab) {
      _lastTab = _shell.tab;
      if (_shell.tab == ShellTab.strategy) _reload();
    }
    // A hand-off from anywhere: open that step's page.
    final stage = _shell.pendingStage;
    if (stage != null && _shell.intentSerial != _seenIntent) {
      _seenIntent = _shell.intentSerial;
      _openStage(stage);
    }
  }

  /// Opens a step; on return, if it just got done, offers the next step.
  Future<void> _openStage(StrategyStage stage) async {
    final before = _last;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _StagePage(stage: stage)));
    if (!mounted) return;
    _reload();
    final after = await _progress.then<_Progress?>((p) => p, onError: (_) => null);
    if (!mounted || before == null || after == null) return;
    final finished = StrategyStage.values.where((s) => !before.done(s) && after.done(s)).firstOrNull;
    final next = after.next;
    if (finished != null && next != null) _offerNext(finished, next, after);
  }

  void _offerNext(StrategyStage finished, StrategyStage next, _Progress progress) {
    final headline = switch (finished) {
      StrategyStage.selector => () {
        final count = progress.selector.first.results?.length ?? progress.selector.first.topN;
        return '$count stocks saved.\nStep 1 done.';
      }(),
      StrategyStage.optimizer => '${progress.tuned.first.ticker.displaySymbol} tuned.\nStep 2 done.',
      StrategyStage.adviser => 'You’re live.',
    };
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheet) => _NextStepSheet(
        progress: progress,
        headline: headline,
        next: next,
        onNext: () {
          Navigator.of(sheet).pop();
          _openStage(next);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _progress.then<void>((_) {}, onError: (_) {});
          },
          child: FutureBuilder<_Progress>(
            future: _progress,
            builder: (context, snapshot) {
              final data = snapshot.data ?? _last;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('Strategy', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  ),
                  const SizedBox(height: 14),
                  if (snapshot.hasError && data == null)
                    ErrorNote('Couldn’t load your strategy. Pull to try again.', onRetry: _reload)
                  else if (data == null)
                    const SkeletonList(count: 3, height: 110)
                  else ...[
                    data.live.isNotEmpty
                        ? _AdviserCard(progress: data, onOpen: () => _openStage(StrategyStage.adviser))
                        : _GuideCard(progress: data),
                    _SectionHeader(
                      label: 'BUILD',
                      trailing: Text(
                        '${data.doneCount} of 3 done',
                        style: TextStyle(fontSize: 12.5, color: context.palette.mutedForeground),
                      ),
                    ),
                    if (data.next == null)
                      _ToolTiles(progress: data, onOpen: _openStage)
                    else
                      for (final stage in StrategyStage.values) _StepCard(stage: stage, progress: data, onOpen: () => _openStage(stage)),
                    if (data.live.isNotEmpty) ...[
                      _SectionHeader(label: 'RUNNING', action: 'Manage', onAction: () => _openStage(StrategyStage.adviser)),
                      for (final s in data.live) _LiveRow(session: s, onTap: () => _openStage(StrategyStage.adviser)),
                    ],
                    _SectionHeader(label: 'LATEST SIGNALS', action: 'All signals →', onAction: () => openSignals(context)),
                    if (data.signals.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          'Signals appear here once a stock is live.',
                          style: TextStyle(fontSize: 13, color: context.palette.mutedForeground),
                        ),
                      )
                    else
                      for (final s in data.signals.take(4)) _SignalLine(signal: s),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

const _titles = {
  StrategyStage.selector: ('Pick your stocks', 'Select'),
  StrategyStage.optimizer: ('Tune the signal', 'Optimize'),
  StrategyStage.adviser: ('Go live', 'Advise'),
};

const _explanations = {
  StrategyStage.selector: 'Rank an exchange’s stocks over a past period and keep the strongest.',
  StrategyStage.optimizer: 'Find the settings that would have traded each stock best, then check them on data they never saw.',
  StrategyStage.adviser: 'Stockiser watches the stock with those settings and sends you buy, hold and sell calls.',
};

const _actions = {
  StrategyStage.selector: 'Rank an exchange',
  StrategyStage.optimizer: 'Tune a stock',
  StrategyStage.adviser: 'Start monitoring',
};

const _locked = {StrategyStage.optimizer: 'Opens once you’ve picked stocks', StrategyStage.adviser: 'Opens once a stock is tuned'};

String _status(StrategyStage stage, _Progress progress) {
  switch (stage) {
    case StrategyStage.selector:
      if (progress.selector.isEmpty) return 'Not started';
      final r = progress.selector.first;
      final type = r.stockType == 'equity' ? '' : ' ${r.stockType}';
      return 'Top ${r.topN}$type · ${r.exchange} · ${_ago(r.createdAt)}';
    case StrategyStage.optimizer:
      final tuned = progress.tuned.map((r) => r.ticker.displaySymbol).toSet();
      if (tuned.isEmpty) return progress.selector.isEmpty ? _locked[stage]! : 'Stocks waiting · 0 tuned';
      return '${tuned.length} tuned · ${tuned.take(3).join(', ')}${tuned.length > 3 ? '…' : ''}';
    case StrategyStage.adviser:
      final live = progress.live.length;
      if (live == 0) return progress.tuned.isEmpty ? _locked[stage]! : 'Ready to go live';
      return 'Watching $live stock${live == 1 ? '' : 's'}';
  }
}

/// Hub card for an investor whose Adviser is running: what it watches, how
/// many calls it made this week, and the latest call.
class _AdviserCard extends StatelessWidget {
  const _AdviserCard({required this.progress, required this.onOpen});

  final _Progress progress;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final latest = progress.signals.firstOrNull;
    const soft = Color(0xFFCFE3D6);
    return Material(
      color: brandForest,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.circle, size: 9, color: brandMint),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ADVISER LIVE',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: brandMint),
                    ),
                  ),
                  Text('Manage ›', style: TextStyle(fontSize: 13, color: soft)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _Stat(value: '${progress.live.length}', label: 'stocks watched'),
                  const SizedBox(width: 28),
                  _Stat(value: '${progress.callsThisWeek}', label: 'calls this week'),
                ],
              ),
              if (latest != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      SignalBadge(type: latest.signalType, size: BadgeSize.sm),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${latest.displaySymbol} at ${formatNumber(latest.price)} · ${_ago(latest.emittedAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w300, color: Colors.white, height: 1.1),
      ),
      Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFFCFE3D6))),
    ],
  );
}

/// Hub card for an investor with nothing live yet: a ring of the steps done
/// and what comes next.
class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.progress});

  final _Progress progress;

  @override
  Widget build(BuildContext context) {
    final next = progress.next ?? StrategyStage.adviser;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: brandForest, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            height: 68,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress.doneCount / 3,
                    strokeWidth: 6,
                    color: brandMint,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '${progress.doneCount}/3',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR GUIDE',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: brandMint),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Get your first buy, hold or sell call',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2),
                ),
                const SizedBox(height: 4),
                Text('Next: ${_titles[next]!.$1.toLowerCase()}', style: const TextStyle(fontSize: 13, color: Color(0xFFCFE3D6))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One step of the checklist: Done, Next (lifted, with its action) or Locked.
class _StepCard extends StatelessWidget {
  const _StepCard({required this.stage, required this.progress, required this.onOpen});

  final StrategyStage stage;
  final _Progress progress;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final done = progress.done(stage);
    final current = progress.next == stage;
    final locked = !done && !current && stage.index > (progress.next?.index ?? 3);
    final (title, _) = _titles[stage]!;

    final marker = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? brandMint : (current ? brandForest : null),
        border: done || current ? null : Border.all(color: p.border, width: 1.5),
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 18, color: brandForest)
          : Text(
              '${stage.index + 1}',
              style: TextStyle(fontWeight: FontWeight.w900, color: current ? brandMint : p.mutedForeground),
            ),
    );

    final (pill, pillBg, pillFg) = done
        ? ('DONE', p.gainSoft, p.gain)
        : (current ? ('NEXT', p.holdSoft, p.hold) : ('', p.surface, p.surface));

    final header = Row(
      children: [
        marker,
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: locked ? p.mutedForeground : p.foreground),
              ),
              Text(
                _status(stage, progress),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: p.mutedForeground),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (locked)
          Icon(Icons.lock_outline_rounded, size: 18, color: p.mutedForeground)
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(99)),
            child: Text(
              pill,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.6, color: pillFg),
            ),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: locked ? p.surfaceMuted.withValues(alpha: 0.6) : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: current ? p.foreground : p.border, width: current ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: current
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      const SizedBox(height: 12),
                      Text(_explanations[stage]!, style: TextStyle(fontSize: 13.5, height: 1.45, color: p.mutedForeground)),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: onOpen,
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        child: Text(_actions[stage]!),
                      ),
                    ],
                  )
                : header,
          ),
        ),
      ),
    );
  }
}

/// Once every step is done, the checklist folds into three tiles that open
/// each tool.
class _ToolTiles extends StatelessWidget {
  const _ToolTiles({required this.progress, required this.onOpen});

  final _Progress progress;
  final void Function(StrategyStage) onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final stage in StrategyStage.values) ...[
          if (stage.index > 0) const SizedBox(width: 10),
          Expanded(
            child: Material(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: p.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onOpen(stage),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 124),
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(color: brandMint, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded, size: 16, color: brandForest),
                      ),
                      const SizedBox(height: 10),
                      Text(_titles[stage]!.$2, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                        _status(stage, progress),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, height: 1.35, color: p.mutedForeground),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// "Step done" sheet: the progress bar, what was just finished, and the next step.
class _NextStepSheet extends StatelessWidget {
  const _NextStepSheet({required this.progress, required this.headline, required this.next, required this.onNext});

  final _Progress progress;
  final String headline;
  final StrategyStage next;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (final stage in StrategyStage.values) ...[
                  if (stage.index > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: progress.done(stage) ? brandMint : (stage == next ? brandForest : p.border),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(color: brandMint, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, size: 28, color: brandForest),
              ),
            ),
            const SizedBox(height: 14),
            Text(headline, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1.15)),
            const SizedBox(height: 8),
            Text(
              'Next, ${_titles[next]!.$1.toLowerCase()}. ${_explanations[next]!}',
              style: TextStyle(fontSize: 14, height: 1.5, color: p.mutedForeground),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(_actions[next]!),
            ),
            const SizedBox(height: 6),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: p.mutedForeground),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.action, this.onAction, this.trailing});

  final String label;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 22, 0, 8),
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            Expanded(child: Text(label, style: labelCaps(p))),
            if (trailing != null) Padding(padding: const EdgeInsets.only(right: 6), child: trailing!),
            if (action != null)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: p.foreground),
                onPressed: onAction,
                child: Text(action!),
              ),
          ],
        ),
      ),
    );
  }
}

class _LiveRow extends StatelessWidget {
  const _LiveRow({required this.session, required this.onTap});

  final AdviserSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final checked = session.lastEvaluatedAt == null ? '' : ' · checked ${_ago(session.lastEvaluatedAt!)}';
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Row(
          children: [
            TickerLogo(symbol: session.ticker.displaySymbol, logoUrl: session.ticker.logoUrl, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.ticker.displaySymbol, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(
                    'every ${formatInterval(session.intervalSec)}$checked',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: p.mutedForeground),
                  ),
                ],
              ),
            ),
            if (session.lastSignalType != null) SignalBadge(type: session.lastSignalType!, size: BadgeSize.sm),
          ],
        ),
      ),
    );
  }
}

class _SignalLine extends StatelessWidget {
  const _SignalLine({required this.signal});

  final SignalEvent signal;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: () => openSymbol(context, signal.symbol),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Row(
          children: [
            TickerLogo(symbol: signal.displaySymbol, logoUrl: signal.logoUrl, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(signal.displaySymbol, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(
                    '${formatPrice(signal.price, signal.currency)} · ${_ago(signal.emittedAt)}',
                    style: TextStyle(fontSize: 12, color: p.mutedForeground),
                  ),
                ],
              ),
            ),
            SignalBadge(type: signal.signalType, size: BadgeSize.sm),
            SizedBox(
              width: 42,
              child: Text(
                '${(signal.confidence * 100).round()}%',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: p.mutedForeground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _ago(String iso) {
  final t = parseApiTime(iso);
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  if (d.inDays == 1) return 'yesterday';
  return '${d.inDays} days ago';
}

/// A step's own page: the Selector, Optimizer or Adviser under a titled bar.
class _StagePage extends StatelessWidget {
  const _StagePage({required this.stage});

  final StrategyStage stage;

  @override
  Widget build(BuildContext context) {
    final (title, tool) = _titles[stage]!;
    final name = switch (stage) {
      StrategyStage.selector => 'SELECTOR',
      StrategyStage.optimizer => 'OPTIMIZER',
      StrategyStage.adviser => 'ADVISER',
    };
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('STEP ${stage.index + 1} OF 3 · $name', style: labelCaps(context.palette).copyWith(fontSize: 10.5)),
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
      body: switch (stage) {
        StrategyStage.selector => const SelectorScreen(),
        StrategyStage.optimizer => const OptimizerScreen(),
        StrategyStage.adviser => const AdviserScreen(),
      },
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
