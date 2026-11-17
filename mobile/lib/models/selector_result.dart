import 'market.dart';

/// The ticker fields every pipeline payload (selector result, optimizer run,
/// adviser session) carries.
class TickerBrief {
  final String symbol;
  final String displaySymbol;
  final String name;
  final String exchange;
  final String currency;
  final String dataSource;

  const TickerBrief({
    required this.symbol,
    required this.displaySymbol,
    required this.name,
    required this.exchange,
    required this.currency,
    required this.dataSource,
  });

  factory TickerBrief.fromJson(Json json) => TickerBrief(
        symbol: json['symbol'] as String,
        displaySymbol: json['display_symbol'] as String? ?? json['symbol'] as String,
        name: json['name'] as String? ?? '',
        exchange: json['exchange'] as String? ?? '',
        currency: json['currency'] as String? ?? '',
        dataSource: json['data_source'] as String? ?? 'yahoo',
      );
}

class SelectorMetric {
  final String value;
  final String label;
  const SelectorMetric(this.value, this.label);
}

/// The Selector's starting parameter: equity (all), growth or value stocks.
class StockTypeOption {
  final String value;
  final String label;
  final String description;
  const StockTypeOption(this.value, this.label, this.description);
}

class SelectorOptions {
  final List<SelectorMetric> metrics;
  final List<StockTypeOption> stockTypes;
  final String defaultStart;
  final String defaultEnd;

  const SelectorOptions({required this.metrics, this.stockTypes = const [], required this.defaultStart, required this.defaultEnd});

  factory SelectorOptions.fromJson(Json json) {
    final period = json['default_period'] as Json? ?? const {};
    return SelectorOptions(
      metrics: (json['metrics'] as List<dynamic>? ?? const [])
          .map((m) => SelectorMetric((m as Json)['value'] as String, m['label'] as String))
          .toList(),
      stockTypes: (json['stock_types'] as List<dynamic>? ?? const [])
          .map((t) => StockTypeOption((t as Json)['value'] as String, t['label'] as String? ?? '', t['description'] as String? ?? ''))
          .toList(),
      defaultStart: period['start'] as String? ?? '',
      defaultEnd: period['end'] as String? ?? '',
    );
  }
}

/// One ranked ticker: `metrics` holds total_return, cagr, volatility, sharpe,
/// sortino, max_drawdown, calmar, momentum (fractions) and prices.
class SelectorResult {
  final TickerBrief ticker;
  final int rank;
  final double score;
  final Map<String, double> metrics;

  /// "growth" | "value" | "blend", judged against the exchange's other stocks.
  final String? style;

  const SelectorResult({required this.ticker, required this.rank, required this.score, required this.metrics, this.style});

  double? metric(String key) => metrics[key];

  factory SelectorResult.fromJson(Json json) => SelectorResult(
        ticker: TickerBrief.fromJson(json),
        rank: json['rank'] as int? ?? 0,
        score: toDouble(json['score']),
        metrics: {
          for (final e in (json['metrics'] as Json? ?? const {}).entries)
            if (e.value is num) e.key: (e.value as num).toDouble(),
        },
        style: (json['metrics'] as Json?)?['style'] as String?,
      );
}

class SelectorRun {
  final String id;
  final String exchange;
  final String exchangeName;
  final String periodStart;
  final String periodEnd;
  final String metric;
  final int topN;
  final String stockType;
  final int universeSize;
  final String? artifactId;
  final String createdAt;
  final List<SelectorResult>? results;

  const SelectorRun({
    required this.id,
    required this.exchange,
    required this.exchangeName,
    required this.periodStart,
    required this.periodEnd,
    required this.metric,
    required this.topN,
    this.stockType = 'equity',
    required this.universeSize,
    this.artifactId,
    required this.createdAt,
    this.results,
  });

  factory SelectorRun.fromJson(Json json) => SelectorRun(
        id: json['id'].toString(),
        exchange: json['exchange'] as String? ?? '',
        exchangeName: json['exchange_name'] as String? ?? '',
        periodStart: json['period_start'] as String? ?? '',
        periodEnd: json['period_end'] as String? ?? '',
        metric: json['metric'] as String? ?? '',
        topN: json['top_n'] as int? ?? 0,
        stockType: json['stock_type'] as String? ?? 'equity',
        universeSize: json['universe_size'] as int? ?? 0,
        artifactId: json['artifact_id'] as String?,
        createdAt: json['created_at'] as String? ?? '',
        results: json['results'] == null ? null : listOf(json['results'], SelectorResult.fromJson),
      );
}
