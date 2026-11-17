import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/market.dart';
import '../services/api_client.dart';
import '../state/auth_provider.dart';
import '../state/push_registrar.dart';
import '../state/settings_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/exchange_picker.dart';

/// Settings (web: /settings). Appearance, notifications, market defaults and
/// the watchlist. Every change saves on the spot.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const SettingsScreen());

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AuthProvider _auth = context.read<AuthProvider>();
  late final ApiClient _api = context.read<ApiClient>();
  late Set<String> _channels = {..._auth.user!.alertChannels};
  late String? _exchange = _auth.user!.defaultExchange;
  late Future<List<MarketRow>> _watchlist = _api.watchlist(_auth.token!);
  bool _confirmClear = false;
  bool _clearing = false;
  String? _saved;
  String? _error;

  Future<void> _saveProfile(String what, VoidCallback undo, {Set<String>? channels, String? exchange, bool clearExchange = false}) async {
    setState(() {
      _saved = null;
      _error = null;
    });
    try {
      final user = await _api.updateMe(
        _auth.token!,
        alertChannels: channels?.toList(),
        defaultExchange: exchange,
        clearDefaultExchange: clearExchange,
      );
      _auth.setUser(user);
      if (mounted) setState(() => _saved = what);
    } catch (e) {
      undo();
      if (mounted) setState(() => _error = errorMessage(e));
    }
  }

  Future<void> _toggle(String channel, bool on) async {
    if (channel == 'push' && on) {
      final granted = await context.read<PushRegistrar>().enable(_auth.token!);
      if (!mounted) return;
      if (!granted) {
        showSnack(context, 'Notifications are blocked for Stockiser. Allow them in Android settings.', error: true);
        return;
      }
    }
    final before = {..._channels};
    setState(() => on ? _channels.add(channel) : _channels.remove(channel));
    await _saveProfile('Alerts saved', () => setState(() => _channels = before), channels: _channels);
  }

  Future<void> _chooseExchange(String? code) async {
    final before = _exchange;
    setState(() => _exchange = code);
    await _saveProfile('Default exchange saved', () => setState(() => _exchange = before), exchange: code, clearExchange: code == null);
  }

  Future<void> _clearWatchlist(List<MarketRow> rows) async {
    setState(() => _clearing = true);
    try {
      await Future.wait(rows.map((r) => _api.removeFromWatchlist(_auth.token!, r.symbol)));
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _clearing = false;
          _confirmClear = false;
          _watchlist = _api.watchlist(_auth.token!);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final settings = context.watch<SettingsController>();
    final user = context.watch<AuthProvider>().user!;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Text('Changes save as you make them.', style: TextStyle(fontSize: 13, color: p.mutedForeground)),
          if (_saved != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('✓ $_saved', style: TextStyle(color: p.gain, fontWeight: FontWeight.w700))),
          ErrorNote(_error),
          _Section(
            title: 'Appearance',
            children: [
              _Row(
                label: 'Theme',
                hint: 'System follows your phone.',
                below: Segmented<ThemeMode>(
                  value: settings.themeMode,
                  options: const [(ThemeMode.light, 'Light'), (ThemeMode.dark, 'Dark'), (ThemeMode.system, 'System')],
                  onChanged: settings.setThemeMode,
                ),
              ),
            ],
          ),
          _Section(
            title: 'Notifications',
            children: [
              for (final (channel, label, hint) in const [
                ('in_app', 'In-app signal alerts', 'A banner whenever the Adviser emits a signal'),
                ('email', 'Email alerts', 'An email when a signal changes'),
                ('push', 'Push notifications', 'On this phone, even when Stockiser is closed'),
              ])
                _Row(
                  label: label,
                  hint: hint,
                  trailing: Switch(value: _channels.contains(channel), onChanged: (on) => _toggle(channel, on)),
                ),
            ],
          ),
          _Section(
            title: 'Markets',
            children: [
              _Row(
                label: 'Default exchange',
                hint: 'Pre-selected when you open the Selector.',
                below: ExchangePickerField(value: _exchange, allowNone: true, onChanged: _chooseExchange),
              ),
            ],
          ),
          _Section(
            title: 'Watchlist',
            children: [
              _Row(
                label: 'Order',
                hint: 'Used on Home and your profile.',
                below: Segmented<WatchlistSort>(
                  value: settings.watchlistSort,
                  options: const [(WatchlistSort.added, 'Newest first'), (WatchlistSort.name, 'A–Z'), (WatchlistSort.change, 'Top movers')],
                  onChanged: settings.setWatchlistSort,
                ),
              ),
              _Row(
                label: 'Show on Home',
                hint: 'Your first symbols on the Home screen.',
                trailing: Switch(value: settings.showWatchlistOnHome, onChanged: settings.setShowWatchlistOnHome),
              ),
              FutureBuilder<List<MarketRow>>(
                future: _watchlist,
                builder: (context, snapshot) {
                  final rows = snapshot.data ?? const <MarketRow>[];
                  return _Row(
                    label: 'Clear watchlist',
                    hint: rows.isEmpty ? 'Your watchlist is empty.' : 'Removes all ${rows.length} symbol${rows.length == 1 ? '' : 's'} from your account.',
                    trailing: _confirmClear
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(onPressed: () => setState(() => _confirmClear = false), child: const Text('Keep')),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: p.loss, foregroundColor: Colors.white, minimumSize: const Size(0, 40)),
                                onPressed: _clearing ? null : () => _clearWatchlist(rows),
                                child: Text(_clearing ? 'Clearing…' : 'Remove ${rows.length}'),
                              ),
                            ],
                          )
                        : TextButton(
                            style: TextButton.styleFrom(foregroundColor: p.loss),
                            onPressed: rows.isEmpty ? null : () => setState(() => _confirmClear = true),
                            child: const Text('Clear…'),
                          ),
                  );
                },
              ),
            ],
          ),
          _Section(
            title: 'Account',
            children: [
              _Row(label: 'Signed in as', hint: user.email),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title.toUpperCase(), style: labelCaps(p)),
          const SizedBox(height: 6),
          Container(decoration: BoxDecoration(border: Border(top: BorderSide(color: p.border)))),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, this.hint, this.trailing, this.below});

  final String label;
  final String? hint;
  final Widget? trailing;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 15)),
                    if (hint != null) Text(hint!, style: TextStyle(fontSize: 12, color: p.mutedForeground)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          if (below != null) ...[const SizedBox(height: 10), below!],
        ],
      ),
    );
  }
}
