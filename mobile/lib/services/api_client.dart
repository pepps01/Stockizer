import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/market.dart';
import '../models/financials.dart';
import '../models/selector_result.dart';
import '../models/strategy.dart';
import '../models/user.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  bool get isUnverified => statusCode == 403 && message.toLowerCase().contains('verify');

  @override
  String toString() => message;
}

/// Typed client for the Stockiser REST API — the Dart twin of
/// frontend/src/lib/api.ts. Every call returns parsed models.
class ApiClient {
  ApiClient({String? baseUrl, http.Client? httpClient}) : baseUrl = baseUrl ?? defaultBaseUrl, _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  static final String _platform = kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'other'));

  static String get defaultBaseUrl {
    // Android emulators reach the host machine through 10.0.2.2. A physical
    // device needs the host's LAN IP: --dart-define=API_BASE_URL=http://<lan-ip>:5000
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:5000';
    return 'http://localhost:5000';
  }

  /// ws(s)://host/ws — override with --dart-define=WS_URL=…
  String get socketUrl {
    const override = String.fromEnvironment('WS_URL');
    if (override.isNotEmpty) return override;
    return '${baseUrl.replaceFirst(RegExp('^http'), 'ws')}/ws';
  }

  static const _defaultTimeout = Duration(seconds: 30);
  // Selector / Optimizer runs download history on first use and can take minutes.
  static const _pipelineTimeout = Duration(minutes: 5);

  Future<Json> _request(String method, String path, {Object? body, String? token, Duration timeout = _defaultTimeout}) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'application/json'
      // Lets the server log sign-ins by platform (with the IP it sees).
      ..headers['X-Client-Platform'] = _platform;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request).timeout(timeout));
    } on TimeoutException {
      throw ApiException('The server took too long to respond. Try again.', 0);
    } catch (_) {
      throw ApiException('Can’t reach the Stockiser server at $baseUrl.', 0);
    }

    if (response.statusCode == 204 || response.body.isEmpty) {
      if (response.statusCode >= 400) throw ApiException('Request failed (${response.statusCode})', response.statusCode);
      return const {};
    }
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      decoded = null;
    }
    final json = decoded is Json ? decoded : const <String, dynamic>{};
    if (response.statusCode >= 400) {
      throw ApiException(json['error'] as String? ?? 'Request failed (${response.statusCode})', response.statusCode);
    }
    return json;
  }

  Future<Json> _get(String path, {String? token}) => _request('GET', path, token: token);

  Future<Json> _post(String path, Object body, {String? token, Duration timeout = _defaultTimeout}) =>
      _request('POST', path, body: body, token: token, timeout: timeout);

  static String _query(Map<String, Object?> params) {
    final entries = params.entries.where((e) => e.value != null && e.value.toString().isNotEmpty);
    if (entries.isEmpty) return '';
    return '?${entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value.toString())}').join('&')}';
  }

  static String _seg(String value) => Uri.encodeComponent(value);

  // ---- auth ----

  Future<User> register({required String firstName, required String lastName, required String email, required String password}) async {
    final json = await _post('/api/auth/register', {'first_name': firstName, 'last_name': lastName, 'email': email, 'password': password});
    return User.fromJson(json['user'] as Json);
  }

  Future<User> verifyEmail(String token) async {
    final json = await _get('/api/auth/verify-email${_query({'token': token})}');
    return User.fromJson(json['user'] as Json);
  }

  Future<(String, User)> login(String email, String password) async {
    final json = await _post('/api/auth/login', {'email': email, 'password': password});
    return (json['access_token'] as String, User.fromJson(json['user'] as Json));
  }

  Future<User> getMe(String token) async => User.fromJson((await _get('/api/auth/me', token: token))['user'] as Json);

  Future<User> updateMe(
    String token, {
    String? firstName,
    String? lastName,
    String? riskProfile,
    List<String>? alertChannels,
    String? defaultExchange,
    bool clearDefaultExchange = false,
  }) async {
    final json = await _request(
      'PUT',
      '/api/auth/me',
      token: token,
      body: {
        'first_name': ?firstName,
        'last_name': ?lastName,
        'risk_profile': ?riskProfile,
        'alert_channels': ?alertChannels,
        if (defaultExchange != null || clearDefaultExchange) 'default_exchange': defaultExchange,
      },
    );
    return User.fromJson(json['user'] as Json);
  }

  // ---- markets ----

  Future<List<Country>> countries() async => listOf((await _get('/api/countries'))['countries'], Country.fromJson);

  Future<List<Exchange>> exchanges({String? country}) async =>
      listOf((await _get('/api/exchanges${_query({'country': country})}'))['exchanges'], Exchange.fromJson);

  Future<ExchangeListing> exchange(String code) async => ExchangeListing.fromJson(await _get('/api/exchanges/${_seg(code)}'));

  Future<List<MarketRow>> indices({String? country}) async =>
      listOf((await _get('/api/indices${_query({'country': country})}'))['indices'], MarketRow.fromJson);

  Future<Movers> movers({String? country, String? exchange, int? limit}) async =>
      Movers.fromJson(await _get('/api/movers${_query({'country': country, 'exchange': exchange, 'limit': limit})}'));

  Future<List<TickerInfo>> search(String text) async =>
      listOf((await _get('/api/search${_query({'q': text})}'))['results'], TickerInfo.fromJson);

  Future<SymbolDetail> symbol(String symbol) async => SymbolDetail.fromJson(await _get('/api/symbols/${_seg(symbol)}'));

  Future<List<Bar>> history(String symbol, String range) async =>
      listOf((await _get('/api/symbols/${_seg(symbol)}/history${_query({'range': range})}'))['bars'], Bar.fromJson);

  /// The Adviser's current call — the user's latest optimised parameters when signed in.
  Future<(AdviserSignal, String?)> signal(String symbol, {String? token}) async {
    final json = await _get('/api/symbols/${_seg(symbol)}/signal', token: token);
    return (AdviserSignal.fromJson(json['signal'] as Json), json['optimizer_run_id']?.toString());
  }

  /// The stocks Stockiser covers in an index's market.
  /// Can be slow on a cold server (ratings for every stock), so it gets the long timeout.
  Future<IndexMembers> indexMembers(String symbol) async =>
      IndexMembers.fromJson(await _request('GET', '/api/symbols/${_seg(symbol)}/members', timeout: _pipelineTimeout));

  /// Those stocks split into growth, value and equity segments.
  Future<IndexFinancials> indexFinancials(String symbol) async =>
      IndexFinancials.fromJson(await _request('GET', '/api/symbols/${_seg(symbol)}/financials', timeout: _pipelineTimeout));

  // ---- selector ----

  Future<SelectorOptions> selectorOptions() async => SelectorOptions.fromJson(await _get('/api/selector/options'));

  Future<SelectorRun> runSelector(
    String token, {
    required String exchange,
    required String periodStart,
    required String periodEnd,
    required String metric,
    required int topN,
    String stockType = 'equity',
  }) async {
    final json = await _post(
      '/api/selector/runs',
      {
        'exchange': exchange,
        'period_start': periodStart,
        'period_end': periodEnd,
        'metric': metric,
        'top_n': topN,
        'stock_type': stockType,
      },
      token: token,
      timeout: _pipelineTimeout,
    );
    return SelectorRun.fromJson(json['run'] as Json);
  }

  Future<List<SelectorRun>> selectorRuns(String token) async =>
      listOf((await _get('/api/selector/runs', token: token))['runs'], SelectorRun.fromJson);

  Future<SelectorRun> selectorRun(String token, String id) async =>
      SelectorRun.fromJson((await _get('/api/selector/runs/${_seg(id)}', token: token))['run'] as Json);

  // ---- optimizer ----

  Future<OptimizerOptions> optimizerOptions() async => OptimizerOptions.fromJson(await _get('/api/optimizer/options'));

  /// Tune either the top-K tickers of a Selector run or explicit [symbols].
  Future<List<OptimizerRun>> runOptimizer(
    String token, {
    List<String>? symbols,
    String? selectorRunId,
    int? topK,
    required String trainingStart,
    required String trainingEnd,
    required String objective,
    String strategy = 'algebraic',
    Map<String, (double, double)> bounds = const {},
  }) async {
    final json = await _post(
      '/api/optimizer/runs',
      {
        'symbols': ?symbols,
        'selector_run_id': ?selectorRunId,
        'top_k': ?topK,
        'training_start': trainingStart,
        'training_end': trainingEnd,
        'objective': objective,
        'strategy': strategy,
        'bounds': {
          for (final e in bounds.entries) e.key: [e.value.$1, e.value.$2],
        },
      },
      token: token,
      timeout: _pipelineTimeout,
    );
    return listOf(json['runs'], OptimizerRun.fromJson);
  }

  Future<List<OptimizerRun>> optimizerRuns(String token, {String? symbol}) async =>
      listOf((await _get('/api/optimizer/runs${_query({'symbol': symbol})}', token: token))['runs'], OptimizerRun.fromJson);

  Future<OptimizerRun> optimizerRun(String token, String id) async =>
      OptimizerRun.fromJson((await _get('/api/optimizer/runs/${_seg(id)}', token: token))['run'] as Json);

  // ---- adviser ----

  Future<List<AdviserSession>> sessions(String token) async =>
      listOf((await _get('/api/adviser/sessions', token: token))['sessions'], AdviserSession.fromJson);

  Future<AdviserSession> createSession(String token, {required String symbol, required int intervalSec, String? optimizerRunId}) async {
    final json = await _post('/api/adviser/sessions', {
      'symbol': symbol,
      'interval_sec': intervalSec,
      'optimizer_run_id': optimizerRunId,
    }, token: token);
    return AdviserSession.fromJson(json['session'] as Json);
  }

  Future<AdviserSession> updateSession(String token, String id, String status) async {
    final json = await _request('PATCH', '/api/adviser/sessions/${_seg(id)}', token: token, body: {'status': status});
    return AdviserSession.fromJson(json['session'] as Json);
  }

  Future<SignalEvent?> evaluateSession(String token, String id) async {
    final json = await _post('/api/adviser/sessions/${_seg(id)}/evaluate', const {}, token: token);
    return json['signal'] == null ? null : SignalEvent.fromJson(json['signal'] as Json);
  }

  Future<List<SignalEvent>> signals(String token, {String? sessionId}) async =>
      listOf((await _get('/api/adviser/signals${_query({'session_id': sessionId})}', token: token))['signals'], SignalEvent.fromJson);

  // ---- account ----

  /// The user's journal entries ("buy" / "hold" / "sell" / "view"), newest first.
  /// The investor's assumed calls, one stance ("buy" | "hold" | "sell") per ticker.
  Future<List<String>> journalActions(String token) async => [
    for (final a in ((await _get('/api/assumptions', token: token))['assumptions'] as List? ?? const []))
      (a as Map<String, dynamic>)['stance'] as String,
  ];

  Future<List<Assumption>> assumptions(String token) async =>
      listOf((await _get('/api/assumptions', token: token))['assumptions'], Assumption.fromJson);

  Future<void> clearAssumption(String token, String symbol) => _request('DELETE', '/api/assumptions/${_seg(symbol)}', token: token);

  /// Assume a buy, hold or sell call on a ticker (tracked in the profile; never an order).
  Future<void> setAssumption(String token, String symbol, String stance) =>
      _request('PUT', '/api/assumptions/${_seg(symbol)}', body: {'stance': stance}, token: token);

  Future<List<MarketRow>> watchlist(String token) async =>
      listOf((await _get('/api/watchlist', token: token))['items'], MarketRow.fromJson);

  Future<void> addToWatchlist(String token, String symbol) => _post('/api/watchlist', {'symbol': symbol}, token: token);

  Future<void> removeFromWatchlist(String token, String symbol) => _request('DELETE', '/api/watchlist/${_seg(symbol)}', token: token);

  /// Register this phone's FCM token so the Adviser can push signals to it.
  Future<void> registerDevice(String token, String deviceToken, String platform) =>
      _request('POST', '/api/devices', body: {'token': deviceToken, 'platform': platform}, token: token);

  Future<void> unregisterDevice(String token, String deviceToken) =>
      _request('DELETE', '/api/devices', body: {'token': deviceToken}, token: token);

  /// Journal the user's own decision — Stockiser never places orders.
  Future<void> recordAction(String token, String symbol, String action) =>
      _post('/api/actions', {'symbol': symbol, 'action': action}, token: token);
}
