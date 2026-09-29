import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/market.dart';
import '../models/selector_result.dart';
import '../models/user.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}

class ApiClient {
  static String get baseUrl {
    // Android emulators can't reach the host machine via localhost — 10.0.2.2
    // is the documented alias. A physical device needs the host's LAN IP
    // instead (override via --dart-define=API_BASE_URL=http://<lan-ip>:5000).
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:5000';
    return 'http://localhost:5000';
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    late http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'PUT':
        response = await http.put(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      default:
        throw ArgumentError('Unsupported method $method');
    }

    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) as Map<String, dynamic> : <String, dynamic>{};

    if (response.statusCode >= 400) {
      throw ApiException(decoded['error'] as String? ?? 'Request failed', response.statusCode);
    }
    return decoded;
  }

  Future<User> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final json = await _request('POST', '/api/auth/register', body: {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'password': password,
    });
    return User.fromJson(json['user'] as Map<String, dynamic>);
  }

  Future<User> verifyEmail(String token) async {
    final json = await _request('GET', '/api/auth/verify-email?token=${Uri.encodeComponent(token)}');
    return User.fromJson(json['user'] as Map<String, dynamic>);
  }

  Future<(String, User)> login(String email, String password) async {
    final json = await _request('POST', '/api/auth/login', body: {'email': email, 'password': password});
    return (json['access_token'] as String, User.fromJson(json['user'] as Map<String, dynamic>));
  }

  Future<User> getMe(String token) async {
    final json = await _request('GET', '/api/auth/me', token: token);
    return User.fromJson(json['user'] as Map<String, dynamic>);
  }

  Future<User> updateMe(String token, {String? firstName, String? lastName}) async {
    final json = await _request('PUT', '/api/auth/me', token: token, body: {
      'first_name': ?firstName,
      'last_name': ?lastName,
    });
    return User.fromJson(json['user'] as Map<String, dynamic>);
  }

  Future<List<Exchange>> listExchanges() async {
    final json = await _request('GET', '/api/exchanges');
    return (json['exchanges'] as List<dynamic>)
        .map((e) => Exchange.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<(Exchange, List<Ticker>)> getExchangeTickers(String code) async {
    final json = await _request('GET', '/api/exchanges/$code/tickers');
    final exchange = Exchange.fromJson(json['exchange'] as Map<String, dynamic>);
    final tickers =
        (json['tickers'] as List<dynamic>).map((t) => Ticker.fromJson(t as Map<String, dynamic>)).toList();
    return (exchange, tickers);
  }

  Future<Ticker> getTicker(String symbol) async {
    final json = await _request('GET', '/api/tickers/$symbol');
    return Ticker.fromJson(json['ticker'] as Map<String, dynamic>);
  }

  Future<List<PricePoint>> getTickerHistory(String symbol, {String period = '1mo', String interval = '1d'}) async {
    final json = await _request('GET', '/api/tickers/$symbol/history?period=$period&interval=$interval');
    return (json['history'] as List<dynamic>).map((p) => PricePoint.fromJson(p as Map<String, dynamic>)).toList();
  }

  Future<List<SelectorResult>> runSelector(String stockType, {int topN = 10}) async {
    final json = await _request('GET', '/api/selector?type=$stockType&top_n=$topN');
    return (json['results'] as List<dynamic>)
        .map((r) => SelectorResult.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> recordSelectorAction(String token, {required String symbol, required String action}) {
    return _request('POST', '/api/selector/action', token: token, body: {'symbol': symbol, 'action': action});
  }
}
