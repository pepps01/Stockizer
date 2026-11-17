import 'package:flutter/foundation.dart';

import '../format.dart';
import '../services/api_client.dart';

/// The investor's marks on tickers: their assumed buy / hold / sell call and
/// whether each is on their watchlist. Changes show instantly and roll back if
/// the server refuses them. One instance is shared by an index's stock list and
/// its Financials panel so both stay in step (same as the web's useTickerMarks).
class TickerMarks extends ChangeNotifier {
  TickerMarks(this._api, this._token) {
    if (_token != null) _load();
  }

  final ApiClient _api;
  final String? _token;
  final Map<String, String> _stances = {};
  final Set<String> _watching = {};
  final Map<String, (double?, DateTime?)> _assumedAt = {};
  String? error;

  bool get signedIn => _token != null;

  String? stanceOf(String symbol) => _stances[symbol];
  bool isWatching(String symbol) => _watching.contains(symbol);

  /// The price and time at which the current call was assumed, when known.
  (double?, DateTime?)? assumedAt(String symbol) => _stances.containsKey(symbol) ? _assumedAt[symbol] : null;

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([_api.assumptions(_token!), _api.watchlist(_token)]);
      for (final a in results[0] as List) {
        _stances[a.symbol as String] = a.stance as String;
        _assumedAt[a.symbol as String] = (a.price as double?, parseApiTime(a.updatedAt as String)?.toLocal());
      }
      for (final row in results[1] as List) {
        _watching.add(row.symbol as String);
      }
      notifyListeners();
    } catch (_) {
      // Menus still work; they just start empty.
    }
  }

  /// Assume (or with null, clear) a call. [price] is the quote shown when the
  /// call was made, kept so the sheet can say "Assumed hold at X".
  Future<void> assume(String symbol, String? stance, {double? price}) async {
    final token = _token;
    if (token == null) return;
    final before = _stances[symbol];
    final beforeAt = _assumedAt[symbol];
    stance == null ? _stances.remove(symbol) : _stances[symbol] = stance;
    if (stance != null) _assumedAt[symbol] = (price, DateTime.now());
    error = null;
    notifyListeners();
    try {
      stance == null ? await _api.clearAssumption(token, symbol) : await _api.setAssumption(token, symbol, stance);
    } catch (_) {
      before == null ? _stances.remove(symbol) : _stances[symbol] = before;
      beforeAt == null ? _assumedAt.remove(symbol) : _assumedAt[symbol] = beforeAt;
      error = 'Couldn’t save that call. Check your connection and try again.';
      notifyListeners();
    }
  }

  Future<void> toggleWatch(String symbol) async {
    final token = _token;
    if (token == null) return;
    final was = _watching.contains(symbol);
    was ? _watching.remove(symbol) : _watching.add(symbol);
    error = null;
    notifyListeners();
    try {
      was ? await _api.removeFromWatchlist(token, symbol) : await _api.addToWatchlist(token, symbol);
    } catch (_) {
      was ? _watching.add(symbol) : _watching.remove(symbol);
      error = 'Couldn’t update your watchlist. Check your connection and try again.';
      notifyListeners();
    }
  }
}
