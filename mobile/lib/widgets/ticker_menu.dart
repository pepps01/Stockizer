import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../format.dart';
import '../models/market.dart';
import '../navigation.dart';
import '../state/shell_controller.dart';
import '../state/ticker_marks.dart';
import '../theme.dart';
import 'motion.dart';

/// The per-ticker call chip (web: AssumeMenu). It shows the assumed call, a
/// star when watched, or "Assume"; tapping it opens [showStockActions].
/// With [dots] it is a plain "⋯" button instead (used in the Financials panel).
class TickerMenu extends StatelessWidget {
  const TickerMenu({
    super.key,
    required this.symbol,
    required this.displaySymbol,
    required this.marks,
    this.name,
    this.quote,
    this.dots = false,
  });

  final String symbol;
  final String displaySymbol;
  final TickerMarks marks;
  final String? name;
  final Quote? quote;
  final bool dots;

  static (String, Color, Color) styleOf(AppPalette p, String stance) => switch (stance) {
    'buy' => ('Buy', p.gain, p.gainSoft),
    'sell' => ('Sell', p.loss, p.lossSoft),
    _ => ('Hold', p.hold, p.holdSoft),
  };

  void _open(BuildContext context) =>
      showStockActions(context, symbol: symbol, displaySymbol: displaySymbol, name: name, quote: quote, marks: marks);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (dots) {
      return IconButton(
        tooltip: 'Actions for $displaySymbol',
        onPressed: () => _open(context),
        icon: Icon(Icons.more_horiz_rounded, color: p.mutedForeground),
      );
    }
    return ListenableBuilder(
      listenable: marks,
      builder: (context, _) {
        final stance = marks.stanceOf(symbol);
        final watching = marks.isWatching(symbol);
        final current = stance == null ? null : styleOf(p, stance);
        final (label, background, foreground) = current != null
            ? (current.$1.toUpperCase(), current.$2, Colors.white)
            : watching
            ? ('★', p.holdSoft, p.hold)
            : ('Assume', p.surfaceMuted, p.mutedForeground);
        return Semantics(
          button: true,
          label: 'Actions for $displaySymbol',
          child: Material(
            color: background,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => _open(context),
              child: Container(
                constraints: const BoxConstraints(minWidth: 58),
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.3, color: foreground),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The stock actions sheet: assume buy / hold / sell (tap the active one to
/// clear it), add to or remove from the watchlist, hand the ticker to the
/// Optimizer → Adviser, or open its chart. Guests are asked to log in.
Future<void> showStockActions(
  BuildContext context, {
  required String symbol,
  required String displaySymbol,
  required TickerMarks marks,
  String? name,
  Quote? quote,
}) {
  Haptics.tick();
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.palette.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (sheet) => _StockActions(symbol: symbol, displaySymbol: displaySymbol, name: name, quote: quote, marks: marks, outer: context),
  );
}

class _StockActions extends StatelessWidget {
  const _StockActions({
    required this.symbol,
    required this.displaySymbol,
    required this.name,
    required this.quote,
    required this.marks,
    required this.outer,
  });

  final String symbol;
  final String displaySymbol;
  final String? name;
  final Quote? quote;
  final TickerMarks marks;
  final BuildContext outer;

  void _then(BuildContext sheet, void Function(BuildContext) action) {
    Navigator.of(sheet).pop();
    if (outer.mounted) action(outer);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final q = quote;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
        child: ListenableBuilder(
          listenable: marks,
          builder: (context, _) {
            final stance = marks.stanceOf(symbol);
            final watching = marks.isWatching(symbol);
            final at = marks.assumedAt(symbol);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SymbolAvatar(displaySymbol, size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displaySymbol, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          if (name != null)
                            Text(
                              name!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: p.mutedForeground),
                            ),
                        ],
                      ),
                    ),
                    if (q != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatNumber(q.price),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w300, fontFeatures: priceFeatures),
                          ),
                          Text(
                            formatPercent(q.changePercent),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: (q.changePercent ?? 0) < 0 ? p.loss : p.gain,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                if (!marks.signedIn) ...[
                  Text('Log in to assume calls and keep a watchlist.', style: TextStyle(color: p.mutedForeground)),
                  const SizedBox(height: 14),
                  FilledButton(onPressed: () => _then(context, (c) => openTab(c, ShellTab.profile)), child: const Text('Log in')),
                ] else ...[
                  Text('ASSUME A POSITION', style: labelCaps(p)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final s in const ['buy', 'hold', 'sell']) ...[
                        if (s != 'buy') const SizedBox(width: 10),
                        Expanded(
                          child: _StanceButton(
                            stance: s,
                            active: stance == s,
                            onTap: () {
                              Haptics.tick();
                              marks.assume(symbol, stance == s ? null : s, price: q?.price);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    stance == null
                        ? 'A call you track in your profile. Stockiser never places orders.'
                        : 'Assumed $stance'
                              '${at?.$1 == null ? '' : ' at ${formatNumber(at!.$1)}'}'
                              '${at?.$2 == null ? '' : ' on ${DateFormat('d MMM').format(at!.$2!)}'}'
                              ' · tap again to clear',
                    style: TextStyle(fontSize: 12.5, color: p.mutedForeground),
                  ),
                  if (marks.error != null) ...[
                    const SizedBox(height: 6),
                    Text(marks.error!, style: TextStyle(fontSize: 12.5, color: p.loss)),
                  ],
                  const SizedBox(height: 18),
                  _ActionRow(
                    icon: watching ? Icons.star_rounded : Icons.star_outline_rounded,
                    iconColor: watching ? p.hold : null,
                    label: watching ? 'Remove from watchlist' : 'Add to watchlist',
                    onTap: () {
                      Haptics.tick();
                      marks.toggleWatch(symbol);
                    },
                  ),
                  _ActionRow(
                    icon: Icons.radar_rounded,
                    label: 'Monitor with Adviser',
                    detail: 'Tune it in the Optimizer, then go live',
                    onTap: () => _then(context, (c) => openStrategy(c, StrategyIntent.optimizer(symbol: symbol))),
                  ),
                ],
                _ActionRow(
                  icon: Icons.show_chart_rounded,
                  label: 'Open chart & signal',
                  onTap: () => _then(context, (c) => openSymbol(c, symbol)),
                ),
                const SizedBox(height: 14),
                OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StanceButton extends StatelessWidget {
  const _StanceButton({required this.stance, required this.active, required this.onTap});

  final String stance;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (label, tone, soft) = TickerMenu.styleOf(p, stance);
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: active ? tone : soft,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: active ? Colors.white : tone),
                ),
                if (active) const Icon(Icons.check_rounded, size: 16, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, required this.onTap, this.detail, this.iconColor});

  final IconData icon;
  final String label;
  final String? detail;
  final Color? iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.border)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor ?? p.foreground),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  if (detail != null) Text(detail!, style: TextStyle(fontSize: 12.5, color: p.mutedForeground)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.mutedForeground),
          ],
        ),
      ),
    );
  }
}

/// A round monogram for a ticker: the first letters of its symbol.
class SymbolAvatar extends StatelessWidget {
  const SymbolAvatar(this.symbol, {super.key, this.size = 40});

  final String symbol;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final letters = symbol.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.surfaceMuted, shape: BoxShape.circle),
      child: Text(
        letters.substring(0, letters.length < 2 ? letters.length : 2).toUpperCase(),
        style: TextStyle(fontSize: size * 0.32, fontWeight: FontWeight.w900, color: p.foreground),
      ),
    );
  }
}
