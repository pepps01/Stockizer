// Market payloads — mirrors frontend/src/lib/types.ts.

typedef Json = Map<String, dynamic>;

double? toDoubleOrNull(Object? value) => (value as num?)?.toDouble();

double toDouble(Object? value) => (value as num?)?.toDouble() ?? 0;

List<T> listOf<T>(Object? value, T Function(Json) parse) => (value as List<dynamic>? ?? const []).map((e) => parse(e as Json)).toList();

/// `yahoo` feeds are real (possibly delayed); `synthetic` series are simulated
/// and must always be badged as such.
bool isSimulated(String? dataSource) => dataSource == 'synthetic';

class Country {
  final String code;
  final String name;
  final String region;
  final String currency;
  final int exchangeCount;

  const Country({required this.code, required this.name, required this.region, required this.currency, required this.exchangeCount});

  factory Country.fromJson(Json json) => Country(
    code: json['code'] as String,
    name: json['name'] as String,
    region: json['region'] as String? ?? '',
    currency: json['currency'] as String? ?? '',
    exchangeCount: json['exchange_count'] as int? ?? 0,
  );
}

class Exchange {
  final String id;
  final String code;
  final String name;
  final String countryCode;
  final String country;
  final String region;
  final String timezone;
  final String opensAt;
  final String closesAt;
  final List<int> tradingDays;
  final String currency;
  final String dataSource;
  final bool isOpen;
  final String localTime;
  final int? stockCount;

  const Exchange({
    required this.id,
    required this.code,
    required this.name,
    required this.countryCode,
    required this.country,
    required this.region,
    required this.timezone,
    required this.opensAt,
    required this.closesAt,
    required this.tradingDays,
    required this.currency,
    required this.dataSource,
    required this.isOpen,
    required this.localTime,
    this.stockCount,
  });

  factory Exchange.fromJson(Json json) => Exchange(
    id: json['id'].toString(),
    code: json['code'] as String,
    name: json['name'] as String,
    countryCode: json['country_code'] as String? ?? '',
    country: json['country'] as String? ?? '',
    region: json['region'] as String? ?? '',
    timezone: json['timezone'] as String? ?? '',
    opensAt: json['opens_at'] as String? ?? '',
    closesAt: json['closes_at'] as String? ?? '',
    tradingDays: (json['trading_days'] as List<dynamic>? ?? const []).cast<int>(),
    currency: json['currency'] as String? ?? '',
    dataSource: json['data_source'] as String? ?? 'yahoo',
    isOpen: json['is_open'] as bool? ?? false,
    localTime: json['local_time'] as String? ?? '',
    stockCount: json['stock_count'] as int?,
  );
}

class Quote {
  final String symbol;
  final double price;
  final double? prevClose;
  final double? change;
  final double? changePercent;
  final double open;
  final double high;
  final double low;
  final double volume;
  final String asOf;
  final String currency;
  final String source;
  final bool marketOpen;

  const Quote({
    required this.symbol,
    required this.price,
    this.prevClose,
    this.change,
    this.changePercent,
    required this.open,
    required this.high,
    required this.low,
    required this.volume,
    required this.asOf,
    required this.currency,
    required this.source,
    required this.marketOpen,
  });

  factory Quote.fromJson(Json json) => Quote(
    symbol: json['symbol'] as String,
    price: toDouble(json['price']),
    prevClose: toDoubleOrNull(json['prev_close']),
    change: toDoubleOrNull(json['change']),
    changePercent: toDoubleOrNull(json['change_percent']),
    open: toDouble(json['open']),
    high: toDouble(json['high']),
    low: toDouble(json['low']),
    volume: toDouble(json['volume']),
    asOf: json['as_of']?.toString() ?? '',
    currency: json['currency'] as String? ?? '',
    source: json['source'] as String? ?? 'yahoo',
    marketOpen: json['market_open'] as bool? ?? false,
  );
}

class TickerInfo {
  final String id;
  final String symbol;
  final String displaySymbol;
  final String name;
  final String? sector;
  final String kind; // "stock" | "index"
  final String currency;
  final String dataSource;
  final String exchange;
  final String exchangeName;
  final String country;
  final String countryCode;

  /// The company's logo (its site icon), when the server knows its website.
  final String? logoUrl;

  const TickerInfo({
    required this.id,
    required this.symbol,
    required this.displaySymbol,
    required this.name,
    this.sector,
    required this.kind,
    required this.currency,
    required this.dataSource,
    required this.exchange,
    required this.exchangeName,
    required this.country,
    required this.countryCode,
    this.logoUrl,
  });

  bool get isIndex => kind == 'index';

  /// Currency label for prices; indices are unitless.
  String? get priceCurrency => isIndex ? null : currency;

  factory TickerInfo.fromJson(Json json) => TickerInfo(
    id: json['id']?.toString() ?? '',
    symbol: json['symbol'] as String,
    displaySymbol: json['display_symbol'] as String? ?? json['symbol'] as String,
    name: json['name'] as String? ?? json['symbol'] as String,
    sector: json['sector'] as String?,
    kind: json['kind'] as String? ?? 'stock',
    currency: json['currency'] as String? ?? '',
    dataSource: json['data_source'] as String? ?? 'yahoo',
    exchange: json['exchange'] as String? ?? '',
    exchangeName: json['exchange_name'] as String? ?? '',
    country: json['country'] as String? ?? '',
    countryCode: json['country_code'] as String? ?? '',
    logoUrl: json['logo_url'] as String?,
  );
}

class Technicals {
  final double? summary;
  final String? label;
  final double? movingAverages;
  final String? maLabel;
  final double? oscillators;
  final String? oscLabel;
  final Map<String, double?> indicators;

  const Technicals({
    this.summary,
    this.label,
    this.movingAverages,
    this.maLabel,
    this.oscillators,
    this.oscLabel,
    this.indicators = const {},
  });

  factory Technicals.fromJson(Json? json) {
    if (json == null) return const Technicals();
    return Technicals(
      summary: toDoubleOrNull(json['summary']),
      label: json['label'] as String?,
      movingAverages: toDoubleOrNull(json['moving_averages']),
      maLabel: json['ma_label'] as String?,
      oscillators: toDoubleOrNull(json['oscillators']),
      oscLabel: json['osc_label'] as String?,
      indicators: (json['indicators'] as Json? ?? const {}).map((k, v) => MapEntry(k, toDoubleOrNull(v))),
    );
  }
}

/// perf_1w … perf_1y and volatility_1m, all in percent.
class Performance {
  static const periods = {'perf_1w': '1W', 'perf_1m': '1M', 'perf_3m': '3M', 'perf_6m': '6M', 'perf_ytd': 'YTD', 'perf_1y': '1Y'};

  final Map<String, double?> values;
  const Performance(this.values);

  double? operator [](String key) => values[key];

  factory Performance.fromJson(Json? json) => Performance((json ?? const {}).map((k, v) => MapEntry(k, toDoubleOrNull(v))));
}

/// A ticker plus its quote, technical rating and performance — one row of a market table.
class MarketRow {
  final TickerInfo info;
  final Quote? quote;
  final Technicals technicals;
  final Performance performance;

  const MarketRow({required this.info, this.quote, required this.technicals, required this.performance});

  String get symbol => info.symbol;

  factory MarketRow.fromJson(Json json) => MarketRow(
    info: TickerInfo.fromJson(json),
    quote: json['quote'] == null ? null : Quote.fromJson(json['quote'] as Json),
    technicals: Technicals.fromJson(json['technicals'] as Json?),
    performance: Performance.fromJson(json['performance'] as Json?),
  );
}

class Movers {
  final List<MarketRow> highestVolume;
  final List<MarketRow> mostVolatile;
  final List<MarketRow> gainers;
  final List<MarketRow> losers;
  final int universeSize;

  const Movers({
    required this.highestVolume,
    required this.mostVolatile,
    required this.gainers,
    required this.losers,
    required this.universeSize,
  });

  Iterable<String> get symbols => [...highestVolume, ...mostVolatile, ...gainers, ...losers].map((r) => r.symbol);

  factory Movers.fromJson(Json json) => Movers(
    highestVolume: listOf(json['highest_volume'], MarketRow.fromJson),
    mostVolatile: listOf(json['most_volatile'], MarketRow.fromJson),
    gainers: listOf(json['gainers'], MarketRow.fromJson),
    losers: listOf(json['losers'], MarketRow.fromJson),
    universeSize: json['universe_size'] as int? ?? 0,
  );
}

class ExchangeListing {
  final Exchange exchange;
  final List<MarketRow> indices;
  final List<MarketRow> stocks;

  const ExchangeListing({required this.exchange, required this.indices, required this.stocks});

  factory ExchangeListing.fromJson(Json json) => ExchangeListing(
    exchange: Exchange.fromJson(json['exchange'] as Json),
    indices: listOf(json['indices'], MarketRow.fromJson),
    stocks: listOf(json['stocks'], MarketRow.fromJson),
  );
}

class Fundamentals {
  final double? marketCap;
  final double? peRatio;
  final double? eps;
  final double? dividendYield;
  final double? beta;
  final double? fiftyTwoWeekHigh;
  final double? fiftyTwoWeekLow;
  final double? avgVolume30d;
  final double? employees;
  final String? industry;
  final String? description;

  const Fundamentals({
    this.marketCap,
    this.peRatio,
    this.eps,
    this.dividendYield,
    this.beta,
    this.fiftyTwoWeekHigh,
    this.fiftyTwoWeekLow,
    this.avgVolume30d,
    this.employees,
    this.industry,
    this.description,
  });

  factory Fundamentals.fromJson(Json? json) {
    if (json == null) return const Fundamentals();
    return Fundamentals(
      marketCap: toDoubleOrNull(json['market_cap']),
      peRatio: toDoubleOrNull(json['pe_ratio']),
      eps: toDoubleOrNull(json['eps']),
      dividendYield: toDoubleOrNull(json['dividend_yield']),
      beta: toDoubleOrNull(json['beta']),
      fiftyTwoWeekHigh: toDoubleOrNull(json['fifty_two_week_high']),
      fiftyTwoWeekLow: toDoubleOrNull(json['fifty_two_week_low']),
      avgVolume30d: toDoubleOrNull(json['avg_volume_30d']),
      employees: toDoubleOrNull(json['employees']),
      industry: json['industry'] as String?,
      description: json['description'] as String?,
    );
  }
}

class SymbolDetail {
  final TickerInfo ticker;
  final Exchange exchange;
  final Quote? quote;
  final Fundamentals fundamentals;
  final Technicals technicals;
  final Performance performance;

  const SymbolDetail({
    required this.ticker,
    required this.exchange,
    this.quote,
    required this.fundamentals,
    required this.technicals,
    required this.performance,
  });

  factory SymbolDetail.fromJson(Json json) => SymbolDetail(
    ticker: TickerInfo.fromJson(json['ticker'] as Json),
    exchange: Exchange.fromJson(json['exchange'] as Json),
    quote: json['quote'] == null ? null : Quote.fromJson(json['quote'] as Json),
    fundamentals: Fundamentals.fromJson(json['fundamentals'] as Json?),
    technicals: Technicals.fromJson(json['technicals'] as Json?),
    performance: Performance.fromJson(json['performance'] as Json?),
  );
}

class Bar {
  final String time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const Bar({required this.time, required this.open, required this.high, required this.low, required this.close, required this.volume});

  factory Bar.fromJson(Json json) => Bar(
    time: json['time'].toString(),
    open: toDouble(json['open']),
    high: toDouble(json['high']),
    low: toDouble(json['low']),
    close: toDouble(json['close']),
    volume: toDouble(json['volume']),
  );
}
