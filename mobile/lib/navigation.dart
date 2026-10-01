import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/exchange_tickers_screen.dart';
import 'screens/markets_screen.dart';
import 'screens/search_screen.dart';
import 'screens/ticker_detail_screen.dart';
import 'state/shell_controller.dart';

// Route helpers shared by every screen (the web app's hrefs).

Future<void> openSymbol(BuildContext context, String symbol) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SymbolScreen(symbol: symbol)));

Future<void> openExchange(BuildContext context, String code) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExchangeScreen(code: code)));

Future<void> openCountry(BuildContext context, String countryCode) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MarketsScreen(country: countryCode)));

Future<void> openSearch(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const SearchScreen()));

/// Jumps to the Strategy tab (Selector / Optimizer / Adviser) from anywhere,
/// closing any pages pushed over the shell.
void openStrategy(BuildContext context, StrategyIntent intent) {
  final shell = context.read<ShellController>();
  Navigator.of(context).popUntil((route) => route.isFirst);
  shell.openStrategy(intent);
}

void openTab(BuildContext context, ShellTab tab) {
  final shell = context.read<ShellController>();
  Navigator.of(context).popUntil((route) => route.isFirst);
  shell.select(tab);
}
