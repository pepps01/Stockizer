class Exchange {
  final String code;
  final String name;
  final String country;
  final bool isOpen;

  Exchange({required this.code, required this.name, required this.country, required this.isOpen});

  factory Exchange.fromJson(Map<String, dynamic> json) => Exchange(
        code: json['code'] as String,
        name: json['name'] as String,
        country: json['country'] as String,
        isOpen: json['is_open'] as bool? ?? false,
      );
}

class Ticker {
  final String symbol;
  final String name;
  final String? sector;
  final String? country;
  final String? description;
  final double? price;
  final double? changePercent;
  final String? currency;
  final double? peRatio;
  final double? marketCap;
  final double? eps;
  final double? dividendYield;
  final double? fiftyTwoWeekHigh;
  final double? fiftyTwoWeekLow;

  Ticker({
    required this.symbol,
    required this.name,
    this.sector,
    this.country,
    this.description,
    this.price,
    this.changePercent,
    this.currency,
    this.peRatio,
    this.marketCap,
    this.eps,
    this.dividendYield,
    this.fiftyTwoWeekHigh,
    this.fiftyTwoWeekLow,
  });

  factory Ticker.fromJson(Map<String, dynamic> json) => Ticker(
        symbol: json['symbol'] as String,
        name: json['name'] as String? ?? json['symbol'] as String,
        sector: json['sector'] as String?,
        country: json['country'] as String?,
        description: json['description'] as String?,
        price: (json['price'] as num?)?.toDouble(),
        changePercent: (json['change_percent'] as num?)?.toDouble(),
        currency: json['currency'] as String?,
        peRatio: (json['pe_ratio'] as num?)?.toDouble(),
        marketCap: (json['market_cap'] as num?)?.toDouble(),
        eps: (json['eps'] as num?)?.toDouble(),
        dividendYield: (json['dividend_yield'] as num?)?.toDouble(),
        fiftyTwoWeekHigh: (json['fifty_two_week_high'] as num?)?.toDouble(),
        fiftyTwoWeekLow: (json['fifty_two_week_low'] as num?)?.toDouble(),
      );
}

class PricePoint {
  final String time;
  final double value;

  PricePoint({required this.time, required this.value});

  factory PricePoint.fromJson(Map<String, dynamic> json) =>
      PricePoint(time: json['time'] as String, value: (json['value'] as num).toDouble());
}
