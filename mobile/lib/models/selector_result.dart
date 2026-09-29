class SelectorResult {
  final String symbol;
  final String name;
  final String? description;
  final String? sector;
  final String? country;
  final List<String> indexMemberships;
  final String stockType;
  final double? price;
  final double? changePercent;
  final double? score;
  final String recommendedAction;

  SelectorResult({
    required this.symbol,
    required this.name,
    this.description,
    this.sector,
    this.country,
    required this.indexMemberships,
    required this.stockType,
    this.price,
    this.changePercent,
    this.score,
    required this.recommendedAction,
  });

  factory SelectorResult.fromJson(Map<String, dynamic> json) => SelectorResult(
        symbol: json['symbol'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        sector: json['sector'] as String?,
        country: json['country'] as String?,
        indexMemberships: (json['index_memberships'] as List<dynamic>? ?? []).cast<String>(),
        stockType: json['stock_type'] as String,
        price: (json['price'] as num?)?.toDouble(),
        changePercent: (json['change_percent'] as num?)?.toDouble(),
        score: (json['score'] as num?)?.toDouble(),
        recommendedAction: json['recommended_action'] as String,
      );
}
