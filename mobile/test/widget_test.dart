import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tickizer/format.dart';
import 'package:tickizer/main.dart';
import 'package:tickizer/models/market.dart';
import 'package:tickizer/models/selector_result.dart';
import 'package:tickizer/models/strategy.dart';
import 'package:tickizer/models/user.dart';
import 'package:tickizer/screens/verify_email_screen.dart';
import 'package:tickizer/services/api_client.dart';
import 'package:tickizer/services/push_service.dart';
import 'package:tickizer/services/realtime_client.dart';

const _user = {
  'id': 'u1',
  'email': 'demo@algizer.app',
  'first_name': 'Ada',
  'last_name': 'Obi',
  'is_verified': true,
  'risk_profile': 'moderate',
  'alert_channels': ['in_app'],
  'default_exchange': 'NGX',
  'created_at': '2026-01-02T10:00:00',
};

final _index = MarketRow.fromJson({
  'id': 't1',
  'symbol': '^GSPC',
  'display_symbol': 'SPX',
  'name': 'S&P 500',
  'kind': 'index',
  'currency': 'USD',
  'data_source': 'yahoo',
  'exchange': 'NYSE',
  'exchange_name': 'New York Stock Exchange',
  'country': 'United States',
  'country_code': 'US',
  'quote': {
    'symbol': '^GSPC',
    'price': 6612.4,
    'change': 21.3,
    'change_percent': 0.32,
    'open': 6590,
    'high': 6620,
    'low': 6580,
    'volume': 1000,
    'as_of': '2026-09-30',
    'currency': 'USD',
    'source': 'yahoo',
    'market_open': true,
  },
});

/// Canned API: a verified user whose login fails unless the password is right.
class FakeApi extends ApiClient {
  FakeApi() : super(baseUrl: 'http://test');

  @override
  Future<User> getMe(String token) async => User.fromJson(_user);

  @override
  Future<(String, User)> login(String email, String password) async {
    if (email == 'new@algizer.app') throw ApiException('Please verify your email before logging in', 403);
    if (password != 'demo-password') throw ApiException('Invalid email or password', 401);
    return ('jwt', User.fromJson(_user));
  }

  @override
  Future<List<MarketRow>> indices({String? country}) async => [_index];

  @override
  Future<List<Country>> countries() async => [
    Country.fromJson({'code': 'NG', 'name': 'Nigeria', 'region': 'Africa', 'currency': 'NGN', 'exchange_count': 1}),
  ];

  @override
  Future<List<Exchange>> exchanges({String? country}) async => [
    Exchange.fromJson({
      'id': 'e1',
      'code': 'NGX',
      'name': 'Nigerian Exchange',
      'country_code': 'NG',
      'country': 'Nigeria',
      'opens_at': '10:00',
      'closes_at': '14:30',
      'trading_days': [0, 1, 2, 3, 4],
      'currency': 'NGN',
      'data_source': 'synthetic',
      'is_open': true,
      'local_time': '2026-09-30T11:00:00',
      'stock_count': 12,
    }),
  ];

  @override
  Future<Movers> movers({String? country, String? exchange, int? limit}) async =>
      Movers(highestVolume: const [], mostVolatile: const [], gainers: [_index], losers: const [], universeSize: 1);

  @override
  Future<List<SignalEvent>> signals(String token, {String? sessionId}) async => const [];

  @override
  Future<List<MarketRow>> watchlist(String token) async => const [];

  @override
  Future<SelectorOptions> selectorOptions() async =>
      const SelectorOptions(metrics: [SelectorMetric('sharpe', 'Sharpe ratio')], defaultStart: '2025-09-30', defaultEnd: '2026-09-30');

  @override
  Future<List<SelectorRun>> selectorRuns(String token) async => const [];

  @override
  Future<List<OptimizerRun>> optimizerRuns(String token, {String? symbol}) async => const [];

  @override
  Future<List<AdviserSession>> sessions(String token) async => const [];

  @override
  Future<List<String>> journalActions(String token) async => const [];

  @override
  Future<List<Bar>> history(String symbol, String range) async => const [];
}

/// Never opens a socket.
class OfflineRealtime extends RealtimeClient {
  OfflineRealtime() : super('ws://test/ws');

  @override
  VoidCallback subscribe(Iterable<String> symbols) => () {};

  @override
  void listenForSignals() {}

  @override
  void setToken(String? token) {}
}

Widget _app() => StockiserApp(api: FakeApi(), realtime: OfflineRealtime(), push: const NoopPushService(), minSplash: Duration.zero);

Future<void> _boot(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('First launch shows the three onboarding pages, then login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _boot(tester);

    expect(find.text('Rank the world’s markets'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Tune the algebra, then prove it'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Live signals, your decision'), findsOneWidget);

    await tester.tap(find.text('I already have an account'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getBool('algizer_onboarding_seen'), isTrue);
  });

  testWidgets('Login routes an unverified account to email verification', (tester) async {
    SharedPreferences.setMockInitialValues({'algizer_onboarding_seen': true});
    await _boot(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'new@algizer.app');
    await tester.enterText(find.byType(TextFormField).at(1), 'whatever1');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Please verify your email before logging in'), findsOneWidget);
    await tester.tap(find.text('Verify your email'));
    await tester.pumpAndSettle();
    expect(find.text('Verify your email'), findsWidgets);
    expect(find.textContaining('new@algizer.app'), findsOneWidget);
  });

  testWidgets('Logging in lands on the home dashboard', (tester) async {
    SharedPreferences.setMockInitialValues({'algizer_onboarding_seen': true});
    await _boot(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'demo@algizer.app');
    await tester.enterText(find.byType(TextFormField).at(1), 'demo-password');
    await tester.tap(find.text('Log in'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.textContaining('Ada'), findsOneWidget);
    expect(find.text('LATEST SIGNALS'), findsOneWidget);
    expect(find.text('S&P 500'), findsWidgets);
    for (final label in ['Home', 'Markets', 'Strategy', 'Profile']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('A stored session skips straight to the dashboard and the Selector opens from its strategy strip', (tester) async {
    SharedPreferences.setMockInitialValues({'algizer_onboarding_seen': true, 'algizer_token': 'jwt'});
    await _boot(tester);
    expect(find.text('LATEST SIGNALS'), findsOneWidget);

    await tester.tap(find.text('Start →'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('CONFIGURE'), findsOneWidget);
    expect(find.text('Rank & select'), findsOneWidget);
  });

  testWidgets('Strategy shows the three steps, and the first step opens its page', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'algizer_onboarding_seen': true, 'algizer_token': 'jwt'});
    await _boot(tester);
    expect(find.text('Signals'), findsNothing);

    await tester.tap(find.text('Strategy'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Pick your stocks'), findsOneWidget);
    expect(find.text('Tune the signal'), findsOneWidget);
    expect(find.text('Go live'), findsOneWidget);
    expect(find.text('0 of 3 done'), findsOneWidget);
    expect(find.text('YOUR GUIDE'), findsOneWidget);

    await tester.tap(find.text('Rank an exchange'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('STEP 1 OF 3 · SELECTOR'), findsOneWidget);
    expect(find.text('CONFIGURE'), findsOneWidget);
  });

  group('helpers', () {
    test('verification token is read from a pasted link or a bare token', () {
      expect(VerifyEmailScreen.extractToken('http://localhost:3000/verify-email?token=abc.def'), 'abc.def');
      expect(VerifyEmailScreen.extractToken('  abc.def  '), 'abc.def');
      expect(VerifyEmailScreen.extractToken(''), isNull);
    });

    test('formatting mirrors the web client', () {
      expect(formatPercent(1.234), '+1.23%');
      expect(formatPercent(-0.5), '−0.50%');
      expect(formatRatioPercent(0.1234, digits: 1, signed: true), '+12.3%');
      expect(formatPrice(1234.5, 'GBp'), '1,234.50 GBX');
      expect(formatInterval(300), '5m');
      expect(formatInterval(3600), '1h');
    });

    test('optimizer runs parse metrics, curves and parameters', () {
      final run = OptimizerRun.fromJson({
        'id': 'r1',
        'symbol': 'AAPL',
        'display_symbol': 'AAPL',
        'name': 'Apple',
        'exchange': 'NASDAQ',
        'currency': 'USD',
        'data_source': 'yahoo',
        'training_start': '2022-01-01',
        'training_end': '2025-01-01',
        'objective': 'sharpe',
        'best_score': 1.2,
        'parameters': {'fast': 12, 'slow': 48, 'window': 20, 'trend_weight': 0.6, 'threshold': 0.2},
        'metrics': {
          'min_trades_met': true,
          'train': {
            'strategy': {'sharpe': 1.2},
            'buy_and_hold': {'sharpe': 0.8},
            'trades': 9,
            'win_rate': 0.55,
            'exposure': 0.6,
          },
          'test': {
            'strategy': {'sharpe': 0.9},
            'buy_and_hold': {'sharpe': 0.7},
            'trades': 3,
            'win_rate': null,
            'exposure': 0.5,
          },
          'test_period': {'start': '2025-01-02', 'end': '2026-09-30', 'bars': 400},
          'curves': {
            'train': [
              {'time': '2022-01-03', 'strategy': 1, 'buy_and_hold': 1},
            ],
            'test': <Object>[],
          },
        },
        'status': 'completed',
        'created_at': '2026-09-30T10:00:00',
      });
      expect(run.completed, isTrue);
      expect(run.test!.strategy['sharpe'], 0.9);
      expect(run.test!.winRate, isNull);
      expect(run.trainCurve, hasLength(1));
      expect(formatParam(run.parameters['fast']!), '12');
      expect(formatParam(run.parameters['threshold']!), '0.200');
    });
  });
}
