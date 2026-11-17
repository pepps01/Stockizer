import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models/selector_result.dart';
import '../navigation.dart';
import '../services/api_client.dart';
import '../state/auth_provider.dart';
import '../state/shell_controller.dart';
import '../theme.dart';
import '../widgets/badges.dart';
import '../widgets/common.dart';
import '../widgets/exchange_picker.dart';
import '../widgets/motion.dart';
import 'strategy_screen.dart';

const _tabular = [FontFeature.tabularFigures()];

/// Stage 1 (frontend /selector): rank an exchange's stocks by a performance
/// criterion over a period, keep the top N and save the ticker file.
class SelectorScreen extends StatefulWidget {
  const SelectorScreen({super.key});

  @override
  State<SelectorScreen> createState() => _SelectorScreenState();
}

class _SelectorScreenState extends State<SelectorScreen> with AutomaticKeepAliveClientMixin, StrategyIntentConsumer {
  late final ApiClient _api = context.read<ApiClient>();
  late final String _token = context.read<AuthProvider>().token!;
  late final Future<SelectorOptions> _options = _api.selectorOptions();
  late Future<List<SelectorRun>> _history = _api.selectorRuns(_token);

  late String? _exchange = context.read<AuthProvider>().user?.defaultExchange;
  DateTime? _start;
  DateTime? _end;
  String _stockType = 'equity';
  String _metric = 'sharpe';
  int _topN = 10;
  SelectorRun? _run;
  bool _busy = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  StrategyStage get stage => StrategyStage.selector;

  @override
  void applyIntent(StrategyIntent intent) {
    if (intent.exchange != null) setState(() => _exchange = intent.exchange);
  }

  Future<void> _submit(SelectorOptions options) async {
    final exchange = _exchange;
    if (exchange == null) {
      setState(() => _error = 'Choose a stock exchange first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final run = await _api.runSelector(
        _token,
        exchange: exchange,
        periodStart: _start == null ? options.defaultStart : isoDate(_start!),
        periodEnd: _end == null ? options.defaultEnd : isoDate(_end!),
        metric: _metric,
        topN: _topN,
        stockType: _stockType,
      );
      if (!mounted) return;
      Haptics.alert();
      setState(() {
        _run = run;
        _history = _api.selectorRuns(_token);
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openRun(String id) async {
    try {
      final run = await _api.selectorRun(_token, id);
      if (mounted) setState(() => _run = run);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _pickDate({required bool start, required DateTime current}) async {
    final picked = await showDatePicker(context: context, initialDate: current, firstDate: DateTime(2000), lastDate: DateTime.now());
    if (picked != null) setState(() => start ? _start = picked : _end = picked);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: () async => setState(() {
        _history = _api.selectorRuns(_token);
      }),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'Rank an exchange’s stocks by a performance criterion over a historical period, keep the top N, and save them to a ticker file for the Optimizer.',
            style: TextStyle(color: context.palette.mutedForeground, fontSize: 13.5),
          ),
          const SizedBox(height: 14),
          AsyncView<SelectorOptions>(future: _options, builder: (context, options) => _form(options)),
          const SizedBox(height: 16),
          if (_run != null) _Results(run: _run!),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Previous runs',
            child: AsyncView<List<SelectorRun>>(
              future: _history,
              builder: (context, runs) => runs.isEmpty
                  ? Text('No runs yet.', style: TextStyle(color: context.palette.mutedForeground))
                  : Column(
                      children: [
                        for (final r in runs)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            selected: r.id == _run?.id,
                            title: Text(
                              '${r.exchange} · ${r.stockType} · ${r.metric} · top ${r.topN}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text('${r.periodStart} → ${r.periodEnd} · ${formatDateTime(r.createdAt)}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openRun(r.id),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _form(SelectorOptions options) {
    final start = _start ?? DateTime.tryParse(options.defaultStart) ?? yearsAgo(1);
    final end = _end ?? DateTime.tryParse(options.defaultEnd) ?? DateTime.now();
    final metrics = options.metrics.isEmpty ? const [SelectorMetric('sharpe', 'Sharpe ratio')] : options.metrics;
    final metric = metrics.any((m) => m.value == _metric) ? _metric : metrics.first.value;
    return SectionCard(
      title: 'Configure',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (options.stockTypes.isNotEmpty) ...[
            LabeledField(
              label: 'Stock type',
              child: StockTypePicker(options: options.stockTypes, value: _stockType, onChanged: (v) => setState(() => _stockType = v)),
            ),
            const SizedBox(height: 14),
          ],
          LabeledField(
            label: 'Stock exchange',
            child: ExchangePickerField(value: _exchange, onChanged: (code) => setState(() => _exchange = code)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: LabeledField(
                  label: 'From',
                  child: DateButton(
                    date: start,
                    onTap: () => _pickDate(start: true, current: start),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LabeledField(
                  label: 'To',
                  child: DateButton(
                    date: end,
                    onTap: () => _pickDate(start: false, current: end),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Performance criterion',
            child: DropdownButtonFormField<String>(
              initialValue: metric,
              isExpanded: true,
              items: [for (final m in metrics) DropdownMenuItem(value: m.value, child: Text(m.label))],
              onChanged: (v) => setState(() => _metric = v ?? _metric),
            ),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Keep top N',
            child: Stepper1D(value: _topN, min: 1, max: 50, onChanged: (v) => setState(() => _topN = v)),
          ),
          ErrorNote(_error),
          const SizedBox(height: 12),
          BusyButton(
            label: 'Rank & select',
            busyLabel: 'Ranking… (first run downloads history)',
            icon: Icons.filter_alt_outlined,
            busy: _busy,
            onPressed: () => _submit(options),
          ),
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.run});

  final SelectorRun run;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final results = run.results ?? const <SelectorResult>[];
    return SectionCard(
      title: 'Top ${results.length} of ${run.universeSize}${run.stockType == 'equity' ? '' : ' ${run.stockType}'} · ${run.exchangeName}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < results.length; i++) ...[
            if (i > 0) const Divider(),
            FadeSlideIn(
              key: ValueKey('${run.id}-$i'),
              delay: FadeSlideIn.stagger(i, stepMs: 60),
              child: _ResultTile(result: results[i]),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Period ${run.periodStart} → ${run.periodEnd}. Past performance ranks candidates; it does not predict returns.'
            '${run.artifactId != null ? ' Ticker file saved for the Optimizer.' : ''}',
            style: TextStyle(fontSize: 12, color: p.mutedForeground),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => openStrategy(context, StrategyIntent.optimizer(selectorRunId: run.id)),
            child: const Text('Send to Optimizer →'),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});

  final SelectorResult result;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = result;
    Widget metric(String label, String value, [Color? color]) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10.5, color: p.mutedForeground)),
        Text(
          value,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color, fontFeatures: _tabular),
        ),
      ],
    );
    return InkWell(
      onTap: () => openSymbol(context, r.ticker.symbol),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    r.rank.toString().padLeft(2, '0'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300, color: p.mutedForeground, fontFeatures: _tabular),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(r.ticker.displaySymbol, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 6),
                          SourceBadge(source: r.ticker.dataSource),
                          if (r.style != null) ...[
                            const SizedBox(width: 8),
                            Text(r.style!.toUpperCase(), style: labelCaps(p).copyWith(fontSize: 10)),
                          ],
                        ],
                      ),
                      Text(
                        r.ticker.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: p.mutedForeground),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatNumber(r.score, 3),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: _tabular),
                    ),
                    Text('score', style: TextStyle(fontSize: 10.5, color: p.mutedForeground)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                metric('Return', formatRatioPercent(r.metric('total_return'), digits: 1, signed: true), p.change(r.metric('total_return'))),
                metric('Sharpe', formatNumber(r.metric('sharpe'), 2)),
                metric('Volatility', formatRatioPercent(r.metric('volatility'), digits: 1)),
                metric('Max DD', formatRatioPercent(r.metric('max_drawdown'), digits: 1), p.loss),
                metric('Momentum', formatRatioPercent(r.metric('momentum'), digits: 1, signed: true), p.change(r.metric('momentum'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Outlined button showing a date; tapping opens a picker.
class DateButton extends StatelessWidget {
  const DateButton({super.key, required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today_outlined, size: 16),
      label: Text(
        isoDate(date),
        style: const TextStyle(fontWeight: FontWeight.w500, fontFeatures: _tabular),
      ),
    );
  }
}

/// − value + integer stepper.
class Stepper1D extends StatelessWidget {
  const Stepper1D({super.key, required this.value, required this.min, required this.max, required this.onChanged});

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          IconButton(onPressed: value > min ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove)),
          Expanded(
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFeatures: _tabular),
            ),
          ),
          IconButton(onPressed: value < max ? () => onChanged(value + 1) : null, icon: const Icon(Icons.add)),
        ],
      ),
    );
  }
}

/// The Selector's starting parameter: equity (all), growth or value stocks.
/// A quiet radio list, one hairline row per type with its definition.
class StockTypePicker extends StatelessWidget {
  const StockTypePicker({super.key, required this.options, required this.value, required this.onChanged});

  final List<StockTypeOption> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Column(
        children: [
          for (final o in options)
            Semantics(
              inMutuallyExclusiveGroup: true,
              checked: o.value == value,
              button: true,
              child: InkWell(
                onTap: () {
                  if (o.value != value) Haptics.tick();
                  onChanged(o.value);
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: p.border)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        margin: const EdgeInsets.only(top: 1),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: o.value == value ? p.foreground : p.border, width: 2),
                        ),
                        child: o.value == value
                            ? Center(
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(color: p.foreground, shape: BoxShape.circle),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(o.description, style: TextStyle(fontSize: 12.5, height: 1.4, color: p.mutedForeground)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
