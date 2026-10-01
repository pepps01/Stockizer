import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/auth_provider.dart';
import '../theme.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/common.dart';
import 'register_screen.dart';
import 'verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  ApiException? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().login(_email.text, _password.text);
      // The root swaps to the home shell; drop anything pushed over the login page.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _register() async {
    final email = await Navigator.of(context).push<String>(RegisterScreen.route());
    if (email != null && mounted) {
      setState(() {
        _email.text = email;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Log in to run the Selector, tune the Optimizer and receive live Adviser signals.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledField(
                label: 'Email',
                child: TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: emailField,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline), hintText: 'you@example.com'),
                ),
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: 'Password',
                child: PasswordField(
                  controller: _password,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: requiredField,
                ),
              ),
              ErrorNote(_error?.message),
              if (_error?.isUnverified ?? false)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                    label: const Text('Verify your email'),
                    onPressed: () => Navigator.of(context).push(VerifyEmailScreen.route(email: _email.text.trim())),
                  ),
                ),
              const SizedBox(height: 20),
              BusyButton(label: 'Log in', busyLabel: 'Logging in…', busy: _submitting, onPressed: _submit),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('New to Algizer?', style: TextStyle(color: p.mutedForeground)),
                  TextButton(onPressed: _register, child: const Text('Create an account')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
