import 'market.dart';

/// The stocks Stockiser covers in an index's market (not its full membership).
class IndexMembers {
  final TickerInfo index;
  final List<String> countries;
  final List<MarketRow> stocks;

  const IndexMembers({required this.index, required this.countries, required this.stocks});

  factory IndexMembers.fromJson(Json json) => IndexMembers(
        index: TickerInfo.fromJson(json['index'] as Json),
        countries: (json['countries'] as List<dynamic>? ?? const []).cast<String>(),
        stocks: listOf(json['stocks'], MarketRow.fromJson),
      );
}

class FinancialStock {
  final TickerInfo info;
  final Quote? quote;
  final String? style; // growth | value | blend
  final double? marketCap;
  final double? peRatio;
  final double? priceToBook;
  final double? dividendYield; // percent
  final double? revenueGrowth; // fraction

  const FinancialStock({
    required this.info,
    this.quote,
    this.style,
    this.marketCap,
    this.peRatio,
    this.priceToBook,
    this.dividendYield,
    this.revenueGrowth,
  });

  String get symbol => info.symbol;

  factory FinancialStock.fromJson(Json json) {
    final f = json['fundamentals'] as Json? ?? const {};
    return FinancialStock(
      info: TickerInfo.fromJson(json),
      quote: json['quote'] == null ? null : Quote.fromJson(json['quote'] as Json),
      style: json['style'] as String?,
      marketCap: toDoubleOrNull(f['market_cap']),
      peRatio: toDoubleOrNull(f['pe_ratio']),
      priceToBook: toDoubleOrNull(f['price_to_book']),
      dividendYield: toDoubleOrNull(f['dividend_yield']),
      revenueGrowth: toDoubleOrNull(f['revenue_growth']),
    );
  }
}

/// Growth, value or equity: its definition, key traits and the stocks in it.
class FinancialSegment {
  final String key;
  final String label;
  final String definition;
  final List<String> traits;
  final List<FinancialStock> stocks;

  const FinancialSegment({required this.key, required this.label, required this.definition, required this.traits, required this.stocks});

  factory FinancialSegment.fromJson(Json json) => FinancialSegment(
        key: json['key'] as String,
        label: json['label'] as String? ?? '',
        definition: json['definition'] as String? ?? '',
        traits: (json['traits'] as List<dynamic>? ?? const []).cast<String>(),
        stocks: listOf(json['stocks'], FinancialStock.fromJson),
      );
}

class IndexFinancials {
  final TickerInfo index;
  final List<FinancialSegment> segments;
  final int unclassified;

  const IndexFinancials({required this.index, required this.segments, required this.unclassified});

  int get total => segments.where((s) => s.key == 'equity').firstOrNull?.stocks.length ?? 0;

  factory IndexFinancials.fromJson(Json json) => IndexFinancials(
        index: TickerInfo.fromJson(json['index'] as Json),
        segments: listOf(json['segments'], FinancialSegment.fromJson),
        unclassified: json['unclassified'] as int? ?? 0,
      );
}

/// A buy / hold / sell call the investor assumed, with the price then and now.
class Assumption {
  final TickerInfo info;
  final String stance;
  final double? price;
  final Quote? quote;
  final double? changeSincePercent;
  final String updatedAt;

  const Assumption({required this.info, required this.stance, this.price, this.quote, this.changeSincePercent, required this.updatedAt});

  String get symbol => info.symbol;

  factory Assumption.fromJson(Json json) => Assumption(
        info: TickerInfo.fromJson(json),
        stance: json['stance'] as String,
        price: toDoubleOrNull(json['price']),
        quote: json['quote'] == null ? null : Quote.fromJson(json['quote'] as Json),
        changeSincePercent: toDoubleOrNull(json['change_since_percent']),
        updatedAt: json['updated_at'] as String? ?? '',
      );
}
