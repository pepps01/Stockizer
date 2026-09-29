import 'package:flutter/material.dart';

import '../services/api_client.dart';
import 'login_screen.dart';

/// Verification emails link to the web frontend (FRONTEND_URL/verify-email),
/// which handles the common case. This screen covers the in-app path — a user
/// who copies the token out of the email and pastes it here instead.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _api = ApiClient();
  final _tokenController = TextEditingController();
  bool _submitting = false;
  bool _success = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _api.verifyEmail(_tokenController.text.trim());
      setState(() => _success = true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify email')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _success
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Email verified. You can now log in.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: const Text('Go to login'),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Paste the verification token from your email link.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tokenController,
                    decoration: const InputDecoration(labelText: 'Verification token'),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: Text(_submitting ? 'Verifying…' : 'Verify'),
                  ),
                ],
              ),
      ),
    );
  }
}
