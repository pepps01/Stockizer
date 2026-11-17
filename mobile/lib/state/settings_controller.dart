import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/market.dart';

enum WatchlistSort { added, name, change }

/// Device-level display settings (Settings screen): theme, watchlist order and
/// whether Home shows the watchlist. Mirrors the web's per-browser settings.
class SettingsController extends ChangeNotifier {
  static const _themeKey = 'stockiser_theme';
  static const _sortKey = 'stockiser_watchlist_sort';
  static const _homeKey = 'stockiser_home_watchlist';

  ThemeMode themeMode = ThemeMode.system;
  WatchlistSort watchlistSort = WatchlistSort.added;
  bool showWatchlistOnHome = true;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    themeMode = switch (prefs.getString(_themeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    watchlistSort = WatchlistSort.values.where((v) => v.name == prefs.getString(_sortKey)).firstOrNull ?? WatchlistSort.added;
    showWatchlistOnHome = prefs.getBool(_homeKey) ?? true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    mode == ThemeMode.system ? await prefs.remove(_themeKey) : await prefs.setString(_themeKey, mode.name);
  }

  Future<void> setWatchlistSort(WatchlistSort sort) async {
    watchlistSort = sort;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setString(_sortKey, sort.name);
  }

  Future<void> setShowWatchlistOnHome(bool show) async {
    showWatchlistOnHome = show;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setBool(_homeKey, show);
  }

  /// Watchlist rows in the chosen order (the API returns them oldest first).
  List<MarketRow> sortWatchlist(List<MarketRow> rows, [Map<String, Quote> live = const {}]) {
    switch (watchlistSort) {
      case WatchlistSort.name:
        return [...rows]..sort((a, b) => a.info.displaySymbol.compareTo(b.info.displaySymbol));
      case WatchlistSort.change:
        double pct(MarketRow r) => (live[r.symbol] ?? r.quote)?.changePercent ?? double.negativeInfinity;
        return [...rows]..sort((a, b) => pct(b).compareTo(pct(a)));
      case WatchlistSort.added:
        return rows.reversed.toList();
    }
  }
}
