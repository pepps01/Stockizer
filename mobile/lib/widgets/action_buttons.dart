import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/auth_provider.dart';
import '../theme.dart';
import 'common.dart';

/// Star toggle for the user's watchlist (app-bar action on the symbol page).
class WatchlistButton extends StatefulWidget {
  const WatchlistButton({super.key, required this.symbol});

  final String symbol;

  @override
  State<WatchlistButton> createState() => _WatchlistButtonState();
}

class _WatchlistButtonState extends State<WatchlistButton> {
  bool? _watching;

  @override
  void initState() {
    super.initState();
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    context.read<ApiClient>().watchlist(token).then((items) {
      if (mounted) setState(() => _watching = items.any((i) => i.symbol == widget.symbol));
    }).catchError((_) {});
  }

  Future<void> _toggle() async {
    final token = context.read<AuthProvider>().token;
    final api = context.read<ApiClient>();
    if (token == null || _watching == null) return;
    final next = !_watching!;
    setState(() => _watching = next);
    try {
      if (next) {
        await api.addToWatchlist(token, widget.symbol);
      } else {
        await api.removeFromWatchlist(token, widget.symbol);
      }
      if (mounted) showSnack(context, next ? 'Added to your watchlist' : 'Removed from your watchlist');
    } catch (e) {
      if (!mounted) return;
      setState(() => _watching = !next);
      showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final watching = _watching ?? false;
    return IconButton(
      tooltip: watching ? 'Watching' : 'Add to watchlist',
      onPressed: _watching == null ? null : _toggle,
      icon: Icon(watching ? Icons.star_rounded : Icons.star_outline_rounded, color: watching ? context.palette.hold : null),
    );
  }
}

/// "I buy / I hold / I sell" — records the user's own decision in their
/// journal. Algizer never places orders.
class JournalButtons extends StatelessWidget {
  const JournalButtons({super.key, required this.symbol});

  final String symbol;

  Future<void> _record(BuildContext context, String action) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      await context.read<ApiClient>().recordAction(token, symbol, action);
      if (context.mounted) showSnack(context, 'Noted “$action” in your journal — Algizer never places orders.');
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final actions = [('buy', p.gain), ('hold', p.hold), ('sell', p.loss)];
    return Row(
      children: [
        for (final (action, color) in actions) ...[
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () => _record(context, action),
              child: Text('I ${action[0].toUpperCase()}${action.substring(1)}'),
            ),
          ),
          if (action != 'sell') const SizedBox(width: 8),
        ],
      ],
    );
  }
}
