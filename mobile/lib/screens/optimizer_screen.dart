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
import '../widgets/price_chart.dart';
import '../widgets/motion.dart';
import 'search_screen.dart';
import 'selector_screen.dart' show DateButton, Stepper1D;
import 'strategy_screen.dart';

const _tabular = [FontFeature.tabularFigures()];

enum _Source { selector, symbols }

/// Stage 2 (frontend /optimizer): tune the algebraic signal on a training
/// period, then check it on the unseen period that follows, against buy & hold.
class OptimizerScreen extends StatefulWidget {
  const OptimizerScreen({super.key});

  @override
  State<OptimizerScreen> createState() => _OptimizerScreenState();
}

class _OptimizerScreenState extends State<OptimizerScreen> with AutomaticKeepAliveClientMixin, StrategyIntentConsumer {
  late final ApiClient _api = context.read<ApiClient>();
  late final String _token = context.read<AuthProvider>().token!;
  late final Future<OptimizerOptions> _options = _api.optimizerOptions();
  late Future<List<SelectorRun>> _selectorRuns = _api.selectorRuns(_token);
  late Future<List<OptimizerRun>> _history = _api.optimizerRuns(_token);

  _Source _source = _Source.selector;
  String? _selectorRunId;
  int _topK = 3;
  final List<String> _symbols = [];
  DateTime _trainingStart = yearsAgo(4);
  DateTime _trainingEnd = yearsAgo(1);
  String _objective = 'sharpe';
  String _strategy = 'algebraic';
  final Map<String, (double, double)> _bounds = {};
  List<OptimizerRun> _batch = const [];
  OptimizerRun? _selected;
  bool _busy = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  StrategyStage get stage => StrategyStage.optimizer;

  @override
  void applyIntent(StrategyIntent intent) {
    setState(() {
      if (intent.selectorRunId != null) {
        _source = _Source.selector;
        _selectorRunId = intent.selectorRunId;
        _selectorRuns = _api.selectorRuns(_token);
      } else if (intent.symbol != null) {
        _source = _Source.symbols;
        _symbols
          ..clear()
          ..add(intent.symbol!);
      }
    });
  }

  Future<void> _submit(String? fallbackRunId) async {
    final runId = _selectorRunId ?? fallbackRunId;
    if (_source == _Source.selector && runId == null) {
      setState(() => _error = 'Run the Selector first, or switch to Symbols.');
      return;
    }
    if (_source == _Source.symbols && _symbols.isEmpty) {
      setState(() => _error = 'Add at least one symbol.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final runs = await _api.runOptimizer(
        _token,
        selectorRunId: _source == _Source.selector ? runId : null,
        topK: _source == _Source.selector ? _topK : null,
        symbols: _source == _Source.symbols ? List.of(_symbols) : null,
        trainingStart: isoDate(_trainingStart),
        trainingEnd: isoDate(_trainingEnd),
        objective: _objective,
        strategy: _strategy,
        bounds: _bounds,
      );
      if (!mounted) return;
      setState(() {
        _batch = runs;
        _history = _api.optimizerRuns(_token);
      });
      Haptics.alert();
      final first = runs.where((r) => r.completed).firstOrNull;
      if (first != null) await _select(first);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// List payloads may omit the equity curves, so completed runs are re-fetched.
  Future<void> _select(OptimizerRun run) async {
    setState(() => _selected = run);
    if (!run.completed) return;
    try {
      final full = await _api.optimizerRun(_token, run.id);
      if (mounted && _selected?.id == run.id) setState(() => _selected = full);
    } catch (_) {
      // Keep the summary we already have.
    }
  }

  Future<void> _addSymbol() async {
    final ticker = await SearchScreen.pick(context, title: 'Add a symbol to tune');
    if (ticker != null && !_symbols.contains(ticker.symbol) && _symbols.length < 10) {
      setState(() => _symbols.add(ticker.symbol));
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final current = start ? _trainingStart : _trainingEnd;
    final picked = await showDatePicker(context: context, initialDate: current, firstDate: DateTime(2000), lastDate: DateTime.now());
    if (picked != null) setState(() => start ? _trainingStart = picked : _trainingEnd = picked);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.palette;
    return RefreshIndicator(
      onRefresh: () async => setState(() {
        _history = _api.optimizerRuns(_token);
        _selectorRuns = _api.selectorRuns(_token);
      }),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'Tune the algebraic signal’s parameters on a training period, then check them on the unseen period that follows — compared with simply buying and holding.',
            style: TextStyle(color: p.mutedForeground, fontSize: 13.5),
          ),
          const SizedBox(height: 14),
          AsyncView<OptimizerOptions>(future: _options, builder: (context, options) => _form(options)),
          if (_selected != null) ...[const SizedBox(height: 16), _RunDetail(key: ValueKey(_selected!.id), run: _selected!)],
          const SizedBox(height: 16),
          SectionCard(
            title: _batch.isNotEmpty ? 'This batch' : 'Recent runs',
            child: _batch.isNotEmpty
                ? _RunList(runs: _batch, selectedId: _selected?.id, onSelect: _select)
                : AsyncView<List<OptimizerRun>>(
                    future: _history,
                    builder: (context, runs) => runs.isEmpty
                        ? const EmptyState(title: 'No optimisation runs yet', icon: Icons.tune)
                        : _RunList(runs: runs.take(12).toList(), selectedId: _selected?.id, onSelect: _select),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _form(OptimizerOptions options) {
    final objectives = options.objectives.isEmpty ? const ['sharpe'] : options.objectives;
    final objective = objectives.contains(_objective) ? _objective : objectives.first;
    final strategy = options.strategy(_strategy) ?? options.strategies.first;
    return SectionCard(
      title: 'Configure',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (options.strategies.length > 1) ...[
            LabeledField(
              label: 'Strategy',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Segmented<String>(
                    value: strategy.key,
                    options: [for (final s in options.strategies) (s.key, strategyShortNames[s.key] ?? s.label)],
                    onChanged: (key) => setState(() {
                      _strategy = key;
                      _bounds.clear(); // each strategy has its own parameters
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(strategy.description, style: TextStyle(fontSize: 12.5, height: 1.4, color: context.palette.mutedForeground)),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          Segmented<_Source>(
            value: _source,
            onChanged: (s) => setState(() => _source = s),
            options: const [(_Source.selector, 'From Selector file'), (_Source.symbols, 'Symbols')],
          ),
          const SizedBox(height: 14),
          if (_source == _Source.selector)
            FutureBuilder<List<SelectorRun>>(
              future: _selectorRuns,
              builder: (context, snapshot) {
                final runs = snapshot.data ?? const <SelectorRun>[];
                final selected = runs.any((r) => r.id == _selectorRunId) ? _selectorRunId : runs.firstOrNull?.id;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LabeledField(
                      label: 'Ticker file',
                      child: runs.isEmpty
                          ? Text(
                              snapshot.hasData ? 'Run the Selector first — its ticker files appear here.' : 'Loading…',
                              style: TextStyle(color: context.palette.mutedForeground),
                            )
                          : DropdownButtonFormField<String>(
                              key: ValueKey(selected),
                              initialValue: selected,
                              isExpanded: true,
                              items: [
                                for (final r in runs)
                                  DropdownMenuItem(
                                    value: r.id,
                                    child: Text(
                                      '${r.exchange} · ${r.metric} · ${r.periodStart}→${r.periodEnd}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (v) => setState(() => _selectorRunId = v),
                            ),
                    ),
                    const SizedBox(height: 14),
                    LabeledField(
                      label: 'Tune the top K tickers',
                      child: Stepper1D(value: _topK, min: 1, max: 10, onChanged: (v) => setState(() => _topK = v)),
                    ),
                    const SizedBox(height: 14),
                    ..._commonFields(options, objectives, objective, () => _submit(selected)),
                  ],
                );
              },
            )
          else ...[
            LabeledField(
              label: 'Symbols',
              hint: 'Up to 10, e.g. AAPL, RY.TO, DANGCEM.NGX',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _symbols) InputChip(label: Text(s), onDeleted: () => setState(() => _symbols.remove(s))),
                  ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('Add symbol'), onPressed: _addSymbol),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ..._commonFields(options, objectives, objective, () => _submit(null)),
          ],
        ],
      ),
    );
  }

  List<Widget> _commonFields(OptimizerOptions options, List<String> objectives, String objective, VoidCallback submit) => [
    Row(
      children: [
        Expanded(
          child: LabeledField(
            label: 'Training from',
            child: DateButton(date: _trainingStart, onTap: () => _pickDate(start: true)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LabeledField(
            label: 'Training to',
            child: DateButton(date: _trainingEnd, onTap: () => _pickDate(start: false)),
          ),
        ),
      ],
    ),
    const SizedBox(height: 14),
    LabeledField(
      label: 'Objective',
      child: DropdownButtonFormField<String>(
        initialValue: objective,
        isExpanded: true,
        items: [for (final o in objectives) DropdownMenuItem(value: o, child: Text(o.replaceAll('_', ' ')))],
        onChanged: (v) => setState(() => _objective = v ?? _objective),
      ),
    ),
    const SizedBox(height: 6),
    Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text('Parameter bounds', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text(
          _bounds.isEmpty ? 'Engine defaults' : '${_bounds.length} customised',
          style: TextStyle(fontSize: 12, color: context.palette.mutedForeground),
        ),
        children: [
          for (final (group, params) in _grouped((options.strategy(_strategy) ?? options.strategies.first).parameters)) ...[
            if (group.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Align(alignment: Alignment.centerLeft, child: Text(group.toUpperCase(), style: labelCaps(context.palette))),
              ),
            for (final param in params)
              _BoundSlider(
                param: param,
                value: _bounds[param.name] ?? (param.low, param.high),
                onChanged: (v) => setState(() => _bounds[param.name] = v),
              ),
          ],
          if (_bounds.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => setState(_bounds.clear), child: const Text('Reset to defaults')),
            ),
        ],
      ),
    ),
    ErrorNote(_error),
    const SizedBox(height: 8),
    BusyButton(label: 'Estimate parameters', busyLabel: 'Estimating…', icon: Icons.tune, busy: _busy, onPressed: submit),
  ];

  /// Indicator parameters are shown in the groups traders know them by
  /// (Stochastic · MACD · RSI); the algebraic strategy needs no headings.
  static List<(String, List<ParamOption>)> _grouped(List<ParamOption> params) {
    String group(String name) {
      if (name.startsWith('stoch_')) return 'Stochastic';
      if (name.startsWith('macd_')) return 'MACD';
      if (name.startsWith('rsi_') || name == 'overbought' || name == 'oversold') return 'RSI';
      return 'Signal';
    }

    final groups = <String, List<ParamOption>>{};
    for (final param in params) {
      groups.putIfAbsent(group(param.name), () => []).add(param);
    }
    if (groups.length == 1) return [('', params)];
    return [for (final e in groups.entries) (e.key, e.value)];
  }
}

class _BoundSlider extends StatelessWidget {
  const _BoundSlider({required this.param, required this.value, required this.onChanged});

  final ParamOption param;
  final (double, double) value;
  final ValueChanged<(double, double)> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (lo, hi) = value;
    String fmt(double v) => param.isInt ? v.round().toString() : v.toStringAsFixed(2);
    final span = param.high - param.low;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(param.description, style: TextStyle(fontSize: 12.5, color: p.mutedForeground)),
              ),
              Text(
                '${fmt(lo)} – ${fmt(hi)}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, fontFeatures: _tabular),
              ),
            ],
          ),
          RangeSlider(
            min: param.low,
            max: param.high,
            divisions: param.isInt ? span.round().clamp(1, 1000) : (span / 0.05).round().clamp(1, 1000),
            values: RangeValues(lo.clamp(param.low, param.high), hi.clamp(param.low, param.high)),
            onChanged: (v) => onChanged((param.isInt ? v.start.roundToDouble() : v.start, param.isInt ? v.end.roundToDouble() : v.end)),
          ),
        ],
      ),
    );
  }
}

class _RunList extends StatelessWidget {
  const _RunList({required this.runs, required this.selectedId, required this.onSelect});

  final List<OptimizerRun> runs;
  final String? selectedId;
  final ValueChanged<OptimizerRun> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      children: [
        for (var i = 0; i < runs.length; i++) ...[
          if (i > 0) const Divider(),
          InkWell(
            onTap: () => onSelect(runs[i]),
            child: Container(
              color: runs[i].id == selectedId ? p.brandSoft : null,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              child: _RunRow(run: runs[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _RunRow extends StatelessWidget {
  const _RunRow({required this.run});

  final OptimizerRun run;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final objective = run.objective;
    Widget cell(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: p.mutedForeground)),
        Text(
          value,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, fontFeatures: _tabular),
        ),
      ],
    );
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(run.ticker.displaySymbol, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  SourceBadge(source: run.ticker.dataSource),
                ],
              ),
              Text(
                run.completed ? '$objective · ${formatDateTime(run.createdAt)}' : (run.error ?? 'Failed'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: run.completed ? p.mutedForeground : p.loss),
              ),
            ],
          ),
        ),
        if (run.completed) ...[
          cell('Train', formatNumber(run.bestScore, 2)),
          const SizedBox(width: 14),
          cell('Unseen', formatNumber(run.test?.strategy[objective], 2)),
          const SizedBox(width: 14),
          cell('B&H', formatNumber(run.test?.buyAndHold[objective], 2)),
        ],
      ],
    );
  }
}

enum _Period { train, test }

class _RunDetail extends StatefulWidget {
  const _RunDetail({super.key, required this.run});

  final OptimizerRun run;

  @override
  State<_RunDetail> createState() => _RunDetailState();
}

class _RunDetailState extends State<_RunDetail> {
  late _Period _period = widget.run.test != null ? _Period.test : _Period.train;
  int _interval = 300;
  bool _starting = false;

  Future<void> _monitor() async {
    final token = context.read<AuthProvider>().token!;
    setState(() => _starting = true);
    try {
      await context.read<ApiClient>().createSession(
        token,
        symbol: widget.run.ticker.symbol,
        intervalSec: _interval,
        optimizerRunId: widget.run.id,
      );
      if (!mounted) return;
      Haptics.alert();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Adviser session started with these parameters.'),
          action: SnackBarAction(label: 'View', onPressed: () => openStrategy(context, const StrategyIntent.adviser())),
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final run = widget.run;
    if (!run.completed) {
      return SectionCard(title: '${run.ticker.displaySymbol} — failed', child: ErrorNote(run.error ?? 'Optimisation failed.'));
    }
    final summary = _period == _Period.test ? run.test : run.train;
    final curve = _period == _Period.test ? run.testCurve : run.trainCurve;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => openSymbol(context, run.ticker.symbol),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${run.ticker.displaySymbol} · ${run.ticker.name}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.chevron_right, color: p.mutedForeground),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(strategyShortNames[run.strategy] ?? run.strategy).toUpperCase()} · ${run.objective.replaceAll('_', ' ').toUpperCase()}',
            style: labelCaps(p),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in run.parameters.entries)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: p.surfaceMuted, borderRadius: BorderRadius.circular(99)),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${e.key} = '),
                        TextSpan(
                          text: formatParam(e.value),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 12, fontFeatures: _tabular),
                  ),
                ),
            ],
          ),
          if (run.minTradesMet == false) ...[
            const SizedBox(height: 10),
            const Notice('No parameter set traded often enough in training — treat these values with caution.', tone: NoticeTone.hold),
          ],
          const SizedBox(height: 14),
          _PeriodBand(
            run: run,
            period: _period,
            onChanged: (v) {
              if (v != _period) Haptics.tick();
              setState(() => _period = v);
            },
          ),
          if (summary != null) ...[
            const SizedBox(height: 12),
            _StatsTable(summary: summary),
            const SizedBox(height: 8),
            Text(
              '${summary.trades} entries · '
              '${summary.winRate != null ? '${(summary.winRate! * 100).toStringAsFixed(0)}% winning trades · ' : ''}'
              'in the market ${(summary.exposure * 100).toStringAsFixed(0)}% of days · 10 bps cost per trade',
              style: TextStyle(fontSize: 12, color: p.mutedForeground),
            ),
          ],
          if (curve.isNotEmpty) ...[const SizedBox(height: 16), EquityChart(points: curve)],
          const Divider(height: 28),
          DropdownButtonFormField<int>(
            initialValue: _interval,
            decoration: const InputDecoration(labelText: 'Monitoring interval'),
            items: const [
              DropdownMenuItem(value: 60, child: Text('Every minute')),
              DropdownMenuItem(value: 300, child: Text('Every 5 minutes')),
              DropdownMenuItem(value: 900, child: Text('Every 15 minutes')),
              DropdownMenuItem(value: 3600, child: Text('Hourly')),
              DropdownMenuItem(value: 86400, child: Text('Daily')),
            ],
            onChanged: (v) => setState(() => _interval = v ?? _interval),
          ),
          const SizedBox(height: 10),
          BusyButton(label: 'Monitor with Adviser', icon: Icons.notifications_active_outlined, busy: _starting, onPressed: _monitor),
        ],
      ),
    );
  }
}

class _StatsTable extends StatelessWidget {
  const _StatsTable({required this.summary});

  final BacktestSummary summary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = summary.strategy;
    final b = summary.buyAndHold;
    final rows = <(String, String, String, Color?, Color?)>[
      (
        'Return',
        formatRatioPercent(s['total_return'], digits: 1, signed: true),
        formatRatioPercent(b['total_return'], digits: 1, signed: true),
        p.change(s['total_return']),
        p.change(b['total_return']),
      ),
      ('CAGR', formatRatioPercent(s['cagr'], digits: 1, signed: true), formatRatioPercent(b['cagr'], digits: 1, signed: true), null, null),
      ('Sharpe', formatNumber(s['sharpe'], 2), formatNumber(b['sharpe'], 2), null, null),
      ('Sortino', formatNumber(s['sortino'], 2), formatNumber(b['sortino'], 2), null, null),
      ('Max drawdown', formatRatioPercent(s['max_drawdown'], digits: 1), formatRatioPercent(b['max_drawdown'], digits: 1), p.loss, p.loss),
      ('Volatility', formatRatioPercent(s['volatility'], digits: 1), formatRatioPercent(b['volatility'], digits: 1), null, null),
    ];
    TextStyle head = TextStyle(fontSize: 11.5, color: p.mutedForeground);
    TextStyle cell(Color? c) => TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c, fontFeatures: _tabular);
    return Table(
      columnWidths: const {0: FlexColumnWidth(1.3), 1: FlexColumnWidth(), 2: FlexColumnWidth()},
      border: TableBorder(horizontalInside: BorderSide(color: p.border)),
      children: [
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('', style: head),
            ),
            Text(
              'Stockiser signal',
              textAlign: TextAlign.right,
              style: head.copyWith(color: p.brand, fontWeight: FontWeight.w600),
            ),
            Text('Buy & hold', textAlign: TextAlign.right, style: head),
          ],
        ),
        for (final (label, sv, bv, sc, bc) in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Text(label, style: const TextStyle(fontSize: 13)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Text(sv, textAlign: TextAlign.right, style: cell(sc)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Text(bv, textAlign: TextAlign.right, style: cell(bc)),
              ),
            ],
          ),
      ],
    );
  }
}

/// Training vs unseen, side by side: each column shows its dates and the
/// strategy's return against buy-and-hold. The selected one is underlined in ink;
/// the unseen period is the honest one, so it carries the accent label.
class _PeriodBand extends StatelessWidget {
  const _PeriodBand({required this.run, required this.period, required this.onChanged});

  final OptimizerRun run;
  final _Period period;
  final ValueChanged<_Period> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget column(_Period value, String label, String dates, BacktestSummary? summary, {bool accent = false}) {
      final selected = value == period;
      final ret = summary?.strategy['total_return'];
      final bh = summary?.buyAndHold['total_return'];
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: InkWell(
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.fromLTRB(0, 12, 8, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: selected ? p.ink : p.border, width: selected ? 2 : 1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: labelCaps(p).copyWith(color: accent ? p.brand : p.mutedForeground)),
                  const SizedBox(height: 2),
                  Text(dates, style: TextStyle(fontSize: 11.5, color: p.mutedForeground, fontFeatures: _tabular)),
                  const SizedBox(height: 8),
                  Text(
                    formatRatioPercent(ret, digits: 1, signed: true),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300, color: p.change(ret), fontFeatures: _tabular),
                  ),
                  Text(
                    'vs ${formatRatioPercent(bh, digits: 1, signed: true)} buy & hold',
                    style: TextStyle(fontSize: 11.5, color: p.mutedForeground),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        column(_Period.train, 'TRAINING', '${run.trainingStart} → ${run.trainingEnd}', run.train),
        if (run.test != null) ...[
          const SizedBox(width: 16),
          column(_Period.test, 'UNSEEN', '${run.testStart ?? ''} → ${run.testEnd ?? ''}', run.test, accent: true),
        ],
      ],
    );
  }
}
