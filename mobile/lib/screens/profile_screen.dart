import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../state/auth_provider.dart';
import '../state/shell_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/exchange_picker.dart';

/// Account details and signal preferences (frontend /profile).
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
  late String? _defaultExchange = _initial.defaultExchange;
  late final Set<String> _channels = {..._initial.alertChannels};
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
            alertChannels: _channels.toList(),
            defaultExchange: _defaultExchange,
            clearDefaultExchange: _defaultExchange == null,
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

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final user = context.watch<AuthProvider>().user!;
    final createdAt = parseApiTime(user.createdAt);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Form(
        key: _formKey,
        onChanged: _edited,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            SectionCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: p.brand,
                    child: Text(user.initials, style: TextStyle(color: p.brandForeground, fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        Text(user.email, style: TextStyle(color: p.mutedForeground)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(user.isVerified ? Icons.verified : Icons.error_outline, size: 15, color: user.isVerified ? p.gain : p.hold),
                            const SizedBox(width: 4),
                            Text(
                              user.isVerified ? 'Verified' : 'Not verified',
                              style: TextStyle(fontSize: 12, color: user.isVerified ? p.gain : p.hold, fontWeight: FontWeight.w600),
                            ),
                            if (createdAt != null) ...[
                              Text('  ·  Member since ${createdAt.year}', style: TextStyle(fontSize: 12, color: p.mutedForeground)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Personal details',
              child: Row(
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
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Signal preferences',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LabeledField(
                    label: 'Risk profile',
                    hint: 'Recorded with your account for future personalisation of signals.',
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 'conservative', label: Text('Conservative')),
                        ButtonSegment(value: 'moderate', label: Text('Moderate')),
                        ButtonSegment(value: 'aggressive', label: Text('Aggressive')),
                      ],
                      selected: {_risk},
                      onSelectionChanged: (v) => setState(() {
                        _risk = v.first;
                        _saved = false;
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Default exchange',
                    hint: 'Pre-selected in the Selector.',
                    child: ExchangePickerField(
                      value: _defaultExchange,
                      allowNone: true,
                      onChanged: (code) => setState(() {
                        _defaultExchange = code;
                        _saved = false;
                      }),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Signal alerts', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('In-app'),
                    subtitle: const Text('Live banners while the app is open'),
                    value: _channels.contains('in_app'),
                    onChanged: (on) => setState(() {
                      on ? _channels.add('in_app') : _channels.remove('in_app');
                      _saved = false;
                    }),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Email'),
                    subtitle: const Text('Email me when a signal changes'),
                    value: _channels.contains('email'),
                    onChanged: (on) => setState(() {
                      on ? _channels.add('email') : _channels.remove('email');
                      _saved = false;
                    }),
                  ),
                ],
              ),
            ),
            ErrorNote(_error),
            const SizedBox(height: 16),
            BusyButton(
              label: _saved ? 'Saved ✓' : 'Save changes',
              busyLabel: 'Saving…',
              busy: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: p.loss),
              onPressed: _logout,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign out'),
            ),
            const SizedBox(height: 24),
            Text(
              'Algizer · Evalucre Capital\nAPI ${context.read<ApiClient>().baseUrl}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: p.mutedForeground, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  static String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
}
