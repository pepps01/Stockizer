import 'market.dart';
import 'selector_result.dart';

// Optimizer and Adviser payloads — mirrors frontend/src/lib/types.ts.

enum SignalType {
  buy('BUY'),
  sell('SELL'),
  hold('HOLD');

  const SignalType(this.wire);
  final String wire;

  static SignalType? parse(Object? value) {
    for (final t in values) {
      if (t.wire == value) return t;
    }
    return null;
  }
}

/// Signal-engine parameter values by name; the names depend on the strategy
/// (algebraic: fast, slow, window, trend_weight, threshold · indicators:
/// stoch_*, macd_*, rsi_window, overbought, oversold, threshold).
typedef SignalParams = Map<String, double>;

SignalParams parseParams(Object? json) => (json as Json? ?? const {}).map((k, v) => MapEntry(k, toDouble(v)));

String formatParam(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(3);

class AdviserSignal {
  final SignalType signalType;
  final double score;
  final double confidence;
  final double price;
  final String asOf;
  final String reason;
  final String strategy; // "algebraic" | "indicators"
  /// algebraic: trend, z · indicators: macd_hist, rsi, stoch_d
  final Map<String, double> components;
  final SignalParams parameters;
  final String dataSource;
  final bool marketOpen;

  const AdviserSignal({
    required this.signalType,
    required this.score,
    required this.confidence,
    required this.price,
    required this.asOf,
    required this.reason,
    required this.strategy,
    required this.components,
    required this.parameters,
    required this.dataSource,
    required this.marketOpen,
  });

  double get threshold => parameters['threshold'] ?? 0;
  double get trend => components['trend'] ?? 0;
  double get z => components['z'] ?? 0;

  factory AdviserSignal.fromJson(Json json) {
    final components = json['components'] as Json? ?? const {};
    return AdviserSignal(
      signalType: SignalType.parse(json['signal_type']) ?? SignalType.hold,
      score: toDouble(json['score']),
      confidence: toDouble(json['confidence']),
      price: toDouble(json['price']),
      asOf: json['as_of']?.toString() ?? '',
      reason: json['reason'] as String? ?? '',
      strategy: json['strategy'] as String? ?? 'algebraic',
      components: {for (final e in components.entries) if (e.value is num) e.key: (e.value as num).toDouble()},
      parameters: parseParams(json['parameters']),
      dataSource: json['data_source'] as String? ?? 'yahoo',
      marketOpen: json['market_open'] as bool? ?? false,
    );
  }
}

/// A signal the Adviser emitted for one of the user's sessions.
class SignalEvent {
  final String id;
  final String sessionId;
  final String symbol;
  final String displaySymbol;
  final String name;
  final String currency;
  final SignalType signalType;
  final double confidence;
  final double price;
  final double score;
  final String reason;
  final String emittedAt;

  const SignalEvent({
    required this.id,
    required this.sessionId,
    required this.symbol,
    required this.displaySymbol,
    required this.name,
    required this.currency,
    required this.signalType,
    required this.confidence,
    required this.price,
    required this.score,
    required this.reason,
    required this.emittedAt,
  });

  factory SignalEvent.fromJson(Json json) => SignalEvent(
        id: json['id'].toString(),
        sessionId: json['session_id']?.toString() ?? '',
        symbol: json['symbol'] as String,
        displaySymbol: json['display_symbol'] as String? ?? json['symbol'] as String,
        name: json['name'] as String? ?? '',
        currency: json['currency'] as String? ?? '',
        signalType: SignalType.parse(json['signal_type']) ?? SignalType.hold,
        confidence: toDouble(json['confidence']),
        price: toDouble(json['price']),
        score: toDouble(json['score']),
        reason: json['reason'] as String? ?? '',
        emittedAt: json['emitted_at'] as String? ?? '',
      );
}

class StrategyStats {
  final Map<String, double> values;
  const StrategyStats(this.values);

  /// total_return, cagr, volatility, sharpe, sortino, max_drawdown, calmar.
  double? operator [](String key) => values[key];

  factory StrategyStats.fromJson(Json? json) =>
      StrategyStats((json ?? const {}).map((k, v) => MapEntry(k, toDouble(v))));
}

class BacktestSummary {
  final StrategyStats strategy;
  final StrategyStats buyAndHold;
  final int trades;
  final double? winRate;
  final double exposure;

  const BacktestSummary({required this.strategy, required this.buyAndHold, required this.trades, this.winRate, required this.exposure});

  static BacktestSummary? fromJson(Json? json) {
    if (json == null) return null;
    return BacktestSummary(
      strategy: StrategyStats.fromJson(json['strategy'] as Json?),
      buyAndHold: StrategyStats.fromJson(json['buy_and_hold'] as Json?),
      trades: (json['trades'] as num?)?.toInt() ?? 0,
      winRate: toDoubleOrNull(json['win_rate']),
      exposure: toDouble(json['exposure']),
    );
  }
}

class CurvePoint {
  final String time;
  final double strategy;
  final double buyAndHold;

  const CurvePoint({required this.time, required this.strategy, required this.buyAndHold});

  factory CurvePoint.fromJson(Json json) =>
      CurvePoint(time: json['time'].toString(), strategy: toDouble(json['strategy']), buyAndHold: toDouble(json['buy_and_hold']));
}

class OptimizerRun {
  final String id;
  final TickerBrief ticker;
  final String? selectorRunId;
  final String trainingStart;
  final String trainingEnd;
  final String objective;
  final String strategy;
  final double? bestScore;
  final SignalParams parameters;
  final bool? minTradesMet;
  final BacktestSummary? train;
  final BacktestSummary? test;
  final String? testStart;
  final String? testEnd;
  final List<CurvePoint> trainCurve;
  final List<CurvePoint> testCurve;
  final String status; // "completed" | "failed"
  final String? error;
  final String? artifactId;
  final String createdAt;

  const OptimizerRun({
    required this.id,
    required this.ticker,
    this.selectorRunId,
    required this.trainingStart,
    required this.trainingEnd,
    required this.objective,
    this.strategy = 'algebraic',
    this.bestScore,
    required this.parameters,
    this.minTradesMet,
    this.train,
    this.test,
    this.testStart,
    this.testEnd,
    required this.trainCurve,
    required this.testCurve,
    required this.status,
    this.error,
    this.artifactId,
    required this.createdAt,
  });

  bool get completed => status == 'completed';

  factory OptimizerRun.fromJson(Json json) {
    final metrics = json['metrics'] as Json? ?? const {};
    final testPeriod = metrics['test_period'] as Json?;
    final curves = metrics['curves'] as Json? ?? const {};
    return OptimizerRun(
      id: json['id'].toString(),
      ticker: TickerBrief.fromJson(json),
      selectorRunId: json['selector_run_id']?.toString(),
      trainingStart: json['training_start'] as String? ?? '',
      trainingEnd: json['training_end'] as String? ?? '',
      objective: json['objective'] as String? ?? '',
      strategy: json['strategy'] as String? ?? 'algebraic',
      bestScore: toDoubleOrNull(json['best_score']),
      parameters: parseParams(json['parameters']),
      minTradesMet: metrics['min_trades_met'] as bool?,
      train: BacktestSummary.fromJson(metrics['train'] as Json?),
      test: BacktestSummary.fromJson(metrics['test'] as Json?),
      testStart: testPeriod?['start'] as String?,
      testEnd: testPeriod?['end'] as String?,
      trainCurve: listOf(curves['train'], CurvePoint.fromJson),
      testCurve: listOf(curves['test'], CurvePoint.fromJson),
      status: json['status'] as String? ?? 'completed',
      error: json['error'] as String?,
      artifactId: json['artifact_id'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class ParamOption {
  final String name;
  final String type; // "int" | "float"
  final double low;
  final double high;
  final double defaultValue;
  final String description;

  const ParamOption({required this.name, required this.type, required this.low, required this.high, required this.defaultValue, required this.description});

  bool get isInt => type == 'int';

  factory ParamOption.fromJson(Json json) => ParamOption(
        name: json['name'] as String,
        type: json['type'] as String? ?? 'float',
        low: toDouble(json['low']),
        high: toDouble(json['high']),
        defaultValue: toDouble(json['default']),
        description: json['description'] as String? ?? json['name'] as String,
      );
}

/// A signal engine the Optimizer can tune, with its own parameters.
class StrategyOption {
  final String key;
  final String label;
  final String description;
  final List<ParamOption> parameters;

  const StrategyOption({required this.key, required this.label, required this.description, required this.parameters});

  factory StrategyOption.fromJson(Json json) => StrategyOption(
        key: json['key'] as String,
        label: json['label'] as String? ?? json['key'] as String,
        description: json['description'] as String? ?? '',
        parameters: listOf(json['parameters'], ParamOption.fromJson),
      );
}

/// Short names for compact UI.
const strategyShortNames = {'algebraic': 'Algebraic', 'indicators': 'Stoch · MACD · RSI'};

class OptimizerOptions {
  final List<String> objectives;
  final List<StrategyOption> strategies;
  final String defaultStrategy;

  const OptimizerOptions({required this.objectives, required this.strategies, required this.defaultStrategy});

  /// The default strategy's parameters.
  List<ParamOption> get parameters => strategy(defaultStrategy)?.parameters ?? const [];

  StrategyOption? strategy(String key) => strategies.where((s) => s.key == key).firstOrNull;

  factory OptimizerOptions.fromJson(Json json) {
    final strategies = listOf(json['strategies'], StrategyOption.fromJson);
    return OptimizerOptions(
      objectives: (json['objectives'] as List<dynamic>? ?? const []).cast<String>(),
      strategies: strategies.isNotEmpty
          ? strategies
          : [StrategyOption(key: 'algebraic', label: 'Algebraic', description: '', parameters: listOf(json['parameters'], ParamOption.fromJson))],
      defaultStrategy: json['default_strategy'] as String? ?? 'algebraic',
    );
  }
}

class AdviserSession {
  final String id;
  final TickerBrief ticker;
  final String? optimizerRunId;
  final SignalParams? parameters;
  final int intervalSec;
  final String status; // "active" | "paused" | "stopped"
  final String startedAt;
  final String? lastEvaluatedAt;
  final SignalType? lastSignalType;
  final double? lastPrice;
  final double? lastScore;
  final double? lastConfidence;

  const AdviserSession({
    required this.id,
    required this.ticker,
    this.optimizerRunId,
    this.parameters,
    required this.intervalSec,
    required this.status,
    required this.startedAt,
    this.lastEvaluatedAt,
    this.lastSignalType,
    this.lastPrice,
    this.lastScore,
    this.lastConfidence,
  });

  bool get isActive => status == 'active';

  factory AdviserSession.fromJson(Json json) => AdviserSession(
        id: json['id'].toString(),
        ticker: TickerBrief.fromJson(json),
        optimizerRunId: json['optimizer_run_id']?.toString(),
        parameters: json['parameters'] == null ? null : parseParams(json['parameters']),
        intervalSec: (json['interval_sec'] as num?)?.toInt() ?? 300,
        status: json['status'] as String? ?? 'active',
        startedAt: json['started_at'] as String? ?? '',
        lastEvaluatedAt: json['last_evaluated_at'] as String?,
        lastSignalType: SignalType.parse(json['last_signal_type']),
        lastPrice: toDoubleOrNull(json['last_price']),
        lastScore: toDoubleOrNull(json['last_score']),
        lastConfidence: toDoubleOrNull(json['last_confidence']),
      );
}
