import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../state/auth_provider.dart';
import 'settings_screen.dart';
import '../state/shell_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/profile_sections.dart';

/// The Investor profile tab: identity, risk appetite, alert preferences and
/// journal tallies (frontend /profile).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final User _initial = context.read<AuthProvider>().user!;
  late final _firstName = TextEditingController(text: _initial.firstName);
  late final _lastName = TextEditingController(text: _initial.lastName);
  late String _risk = _initial.riskProfile;
  bool _saving = false;
  bool _saved = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  void _edited() {
    if (_saved) setState(() => _saved = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = await context.read<ApiClient>().updateMe(
        auth.token!,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        riskProfile: _risk,
      );
      auth.setUser(user);
      if (mounted) setState(() => _saved = true);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your Adviser keeps monitoring on the server; you just won’t get signals on this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (!(confirmed ?? false) || !mounted) return;
    final auth = context.read<AuthProvider>();
    context.read<ShellController>().reset();
    Navigator.of(context).popUntil((route) => route.isFirst);
    await auth.logout();
  }

  late Future<(List<String>, int)> _journal = _loadJournal();

  Future<(List<String>, int)> _loadJournal() async {
    final token = context.read<AuthProvider>().token!;
    final api = context.read<ApiClient>();
    final results = await Future.wait([api.journalActions(token), api.watchlist(token)]);
    return (results[0] as List<String>, (results[1] as List).length);
  }

  static const _riskText = {
    'conservative': 'You prefer steadiness over growth and want fewer, surer moves.',
    'moderate': 'You accept some swings in exchange for growth.',
    'aggressive': 'You are comfortable with large swings in pursuit of higher returns.',
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final user = context.watch<AuthProvider>().user!;
    final createdAt = parseApiTime(user.createdAt);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          onChanged: _edited,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Investor profile', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () => Navigator.of(context).push(SettingsScreen.route()),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: p.surfaceMuted,
                    child: Text(
                      user.initials,
                      style: TextStyle(color: p.foreground, fontSize: 21, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(user.email, style: TextStyle(fontSize: 13, color: p.mutedForeground)),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(user.isVerified ? Icons.check : Icons.error_outline, size: 14, color: user.isVerified ? p.gain : p.hold),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${user.isVerified ? 'Email verified' : 'Not verified'}${createdAt != null ? ' · since ${DateFormat('MMM y').format(createdAt)}' : ''}',
                                style: TextStyle(fontSize: 12, color: user.isVerified ? p.gain : p.hold, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'First name',
                      child: TextFormField(controller: _firstName, textCapitalization: TextCapitalization.words, validator: _required),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LabeledField(
                      label: 'Last name',
                      child: TextFormField(controller: _lastName, textCapitalization: TextCapitalization.words, validator: _required),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('RISK APPETITE', style: labelCaps(p)),
              const SizedBox(height: 12),
              Segmented<String>(
                value: _risk,
                options: const [('conservative', 'Conservative'), ('moderate', 'Moderate'), ('aggressive', 'Aggressive')],
                onChanged: (v) => setState(() {
                  _risk = v;
                  _saved = false;
                }),
              ),
              const SizedBox(height: 10),
              Text('${_riskText[_risk] ?? ''} Change it any time.', style: TextStyle(fontSize: 13, height: 1.5, color: p.mutedForeground)),
              const SizedBox(height: 28),
              Text('YOUR JOURNAL', style: labelCaps(p)),
              const SizedBox(height: 10),
              FutureBuilder<(List<String>, int)>(
                future: _journal,
                builder: (context, snapshot) {
                  final actions = snapshot.data?.$1 ?? const <String>[];
                  int count(String a) => actions.where((x) => x == a).length;
                  final stats = [
                    ('Assumed buy', count('buy'), p.gain),
                    ('Assumed hold', count('hold'), p.hold),
                    ('Assumed sell', count('sell'), p.loss),
                    ('Watching', snapshot.data?.$2 ?? 0, p.foreground),
                  ];
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.symmetric(horizontal: BorderSide(color: p.border)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        for (final (label, value, color) in stats)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  snapshot.hasData ? '$value' : '–',
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300, color: color, fontFeatures: priceFeatures),
                                ),
                                Text(label, style: TextStyle(fontSize: 12, color: p.mutedForeground)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              ErrorNote(_error),
              const SizedBox(height: 24),
              BusyButton(label: _saved ? 'Saved ✓' : 'Save changes', busyLabel: 'Saving…', busy: _saving, onPressed: _save),
              const SizedBox(height: 32),
              AssumedPositionsSection(
                onChanged: () => setState(() {
                  _journal = _loadJournal();
                }),
              ),
              const SizedBox(height: 28),
              const WatchlistSection(),
              const SizedBox(height: 20),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: p.loss, padding: EdgeInsets.zero),
                  onPressed: _logout,
                  child: const Text('Sign out'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Stockiser · Evalucre Capital\nAPI ${context.read<ApiClient>().baseUrl}',
                style: TextStyle(fontSize: 11.5, color: p.mutedForeground, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
}
