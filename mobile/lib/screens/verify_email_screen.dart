import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../theme.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/common.dart';

/// "Check your inbox" after signup. The emailed link points at the web app
/// (FRONTEND_URL/verify-email?token=…); opening it anywhere verifies the
/// account, or the link / token can be pasted here.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, this.email, this.initialToken});

  final String? email;
  final String? initialToken;

  static Route<void> route({String? email, String? token}) =>
      MaterialPageRoute(builder: (_) => VerifyEmailScreen(email: email, initialToken: token));

  /// Accepts either the full link from the email or the bare token.
  static String? extractToken(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    final fromLink = uri?.queryParameters['token'];
    if (fromLink != null && fromLink.isNotEmpty) return fromLink;
    return text.contains(' ') ? null : text;
  }

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  late final _input = TextEditingController(text: widget.initialToken ?? '');
  bool _verifying = false;
  bool _verified = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialToken != null) WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final token = VerifyEmailScreen.extractToken(_input.text);
    if (token == null) {
      setState(() => _error = 'Paste the verification link from the email, or its token.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await context.read<ApiClient>().verifyEmail(token);
      if (mounted) setState(() => _verified = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _toLogin() => Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (_verified) {
      return AuthScaffold(
        title: 'Email verified',
        subtitle: 'Your account is active. Log in to continue.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusIcon(icon: Icons.verified_rounded, color: p.gain, background: p.gainSoft),
            const SizedBox(height: 28),
            FilledButton(onPressed: _toLogin, child: const Text('Continue to log in')),
          ],
        ),
      );
    }

    final email = widget.email;
    return AuthScaffold(
      showBack: true,
      title: 'Verify your email',
      subtitle: email == null || email.isEmpty
          ? 'We sent you a verification link when you signed up.'
          : 'We sent a verification link to $email. Open it to activate your account, then log in.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusIcon(icon: Icons.mark_email_unread_outlined, color: p.brand, background: p.brandSoft),
          const SizedBox(height: 24),
          const Notice(
            'Opened the link on another device? You’re done — just log in. You can also paste the link (or its token) below.',
            icon: Icons.info_outline,
          ),
          const SizedBox(height: 20),
          LabeledField(
            label: 'Verification link or token',
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 3,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.link), hintText: 'https://…/verify-email?token=…'),
              onSubmitted: (_) => _verify(),
            ),
          ),
          ErrorNote(_error),
          const SizedBox(height: 16),
          BusyButton(label: 'Verify email', busyLabel: 'Verifying…', busy: _verifying, onPressed: _verify),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _toLogin, child: const Text('I’ve verified — log in')),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.icon, required this.color, required this.background});

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, size: 46, color: color),
      ),
    );
  }
}
