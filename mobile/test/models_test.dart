import 'package:flutter_test/flutter_test.dart';
import 'package:tickizer/models/financials.dart';
import 'package:tickizer/models/selector_result.dart';
import 'package:tickizer/models/strategy.dart';

void main() {
  test('selector options and results carry stock types and styles', () {
    final options = SelectorOptions.fromJson({
      'metrics': [
        {'value': 'sharpe', 'label': 'Sharpe ratio'},
      ],
      'stock_types': [
        {'value': 'equity', 'label': 'Equity stocks', 'description': 'All'},
        {'value': 'growth', 'label': 'Growth stocks', 'description': 'Fast'},
        {'value': 'value', 'label': 'Value stocks', 'description': 'Cheap'},
      ],
      'default_period': {'start': '2025-01-01', 'end': '2025-12-31'},
    });
    expect(options.stockTypes.map((t) => t.value), ['equity', 'growth', 'value']);

    final run = SelectorRun.fromJson({
      'id': 'r1',
      'exchange': 'NGX',
      'exchange_name': 'Nigerian Exchange',
      'period_start': '2025-01-01',
      'period_end': '2025-12-31',
      'metric': 'sharpe',
      'top_n': 1,
      'stock_type': 'growth',
      'universe_size': 5,
      'created_at': '2026-11-09T00:00:00Z',
      'results': [
        {
          'rank': 1,
          'score': 1.2,
          'symbol': 'MTNN.NGX',
          'display_symbol': 'MTNN',
          'name': 'MTN Nigeria',
          'exchange': 'NGX',
          'currency': 'NGN',
          'data_source': 'synthetic',
          // A text metric must not break the numeric metrics map.
          'metrics': {'total_return': 0.25, 'sharpe': 1.2, 'style': 'growth', 'style_score': 0.41},
        },
      ],
    });
    expect(run.stockType, 'growth');
    final result = run.results!.single;
    expect(result.style, 'growth');
    expect(result.metric('sharpe'), 1.2);
    expect(result.metrics.containsKey('style'), isFalse);
  });

  test('optimizer options list strategies with their own parameters', () {
    final options = OptimizerOptions.fromJson({
      'objectives': ['sharpe'],
      'default_strategy': 'algebraic',
      'strategies': [
        {
          'key': 'algebraic',
          'label': 'Algebraic',
          'description': '',
          'parameters': [
            {'name': 'fast', 'type': 'int', 'low': 5, 'high': 30, 'default': 12, 'description': 'Fast EMA'},
          ],
        },
        {
          'key': 'indicators',
          'label': 'Stochastic + MACD + RSI',
          'description': '',
          'parameters': [
            {'name': 'macd_fast', 'type': 'int', 'low': 5, 'high': 20, 'default': 12, 'description': 'MACD fast'},
            {'name': 'overbought', 'type': 'float', 'low': 60, 'high': 90, 'default': 70, 'description': 'Overbought'},
          ],
        },
      ],
    });
    expect(options.strategies.map((s) => s.key), ['algebraic', 'indicators']);
    expect(options.parameters.single.name, 'fast');
    expect(options.strategy('indicators')!.parameters.map((p) => p.name), ['macd_fast', 'overbought']);
  });

  test('older servers without strategies still parse', () {
    final options = OptimizerOptions.fromJson({
      'objectives': ['sharpe'],
      'parameters': [
        {'name': 'fast', 'type': 'int', 'low': 5, 'high': 30, 'default': 12, 'description': 'Fast EMA'},
      ],
    });
    expect(options.defaultStrategy, 'algebraic');
    expect(options.parameters.single.name, 'fast');
  });

  test('signals expose the components of their strategy', () {
    final signal = AdviserSignal.fromJson({
      'signal_type': 'BUY',
      'score': 0.4,
      'confidence': 0.6,
      'price': 10,
      'as_of': '2026-11-09',
      'reason': 'MACD bullish',
      'strategy': 'indicators',
      'components': {'macd_hist': 0.12, 'rsi': 28.0, 'stoch_d': 15.0},
      'parameters': {'threshold': 0.3},
      'data_source': 'synthetic',
      'market_open': true,
    });
    expect(signal.strategy, 'indicators');
    expect(signal.components['rsi'], 28.0);
    expect(signal.trend, 0);
    expect(signal.threshold, 0.3);
  });

  const ticker = {
    'id': 't1',
    'symbol': 'MTNN.NGX',
    'display_symbol': 'MTNN',
    'name': 'MTN Nigeria',
    'kind': 'stock',
    'currency': 'NGN',
    'data_source': 'synthetic',
    'exchange': 'NGX',
    'exchange_name': 'Nigerian Exchange',
    'country': 'Nigeria',
    'country_code': 'NG',
  };

  test('index financials parse segments with definitions and fundamentals', () {
    final data = IndexFinancials.fromJson({
      'index': {...ticker, 'symbol': 'NGXASI.NGX.IDX', 'kind': 'index', 'name': 'NGX All-Share Index'},
      'countries': ['NG'],
      'unclassified': 0,
      'segments': [
        {'key': 'growth', 'label': 'Growth stocks', 'definition': 'Fast growers', 'traits': ['High P/E'], 'stocks': []},
        {'key': 'value', 'label': 'Value stocks', 'definition': 'Cheap', 'traits': ['Low P/E'], 'stocks': []},
        {
          'key': 'equity',
          'label': 'Equity stocks',
          'definition': 'All',
          'traits': ['Every listed stock'],
          'stocks': [
            {
              ...ticker,
              'style': 'value',
              'fundamentals': {'pe_ratio': 6.5, 'dividend_yield': 7.1, 'revenue_growth': 0.04, 'market_cap': 1e12},
            },
          ],
        },
      ],
    });
    expect(data.segments.map((s) => s.key), ['growth', 'value', 'equity']);
    expect(data.total, 1);
    final stock = data.segments.last.stocks.single;
    expect(stock.style, 'value');
    expect(stock.peRatio, 6.5);
    expect(stock.revenueGrowth, 0.04);
  });

  test('assumptions keep the call and the move since', () {
    final a = Assumption.fromJson({...ticker, 'stance': 'buy', 'price': 100, 'change_since_percent': 4.2, 'updated_at': '2026-11-17T09:00:00Z'});
    expect(a.stance, 'buy');
    expect(a.price, 100);
    expect(a.changeSincePercent, 4.2);
    expect(a.symbol, 'MTNN.NGX');
  });
}
