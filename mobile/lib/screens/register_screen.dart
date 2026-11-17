import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../theme.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/common.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  /// Completes with the registered email once signup succeeds.
  static Route<String> route() => MaterialPageRoute(builder: (_) => const RegisterScreen());

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final email = _email.text.trim();
    try {
      final user = await context.read<ApiClient>().register(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: email,
        password: _password.text,
      );
      if (!mounted) return;
      if (user.isVerified) {
        // No email step on this server: back to login with the email filled in.
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your account is ready. Log in to get started.')));
        Navigator.of(context).pop(email);
        return;
      }
      // Replace signup with "check your inbox"; the login page gets the email back.
      Navigator.of(context).pushReplacement(VerifyEmailScreen.route(email: email), result: email);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AuthScaffold(
      showBack: true,
      title: 'Create your account',
      subtitle: 'Free access to 37 global exchanges, the three-stage pipeline and live signals.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LabeledField(
                      label: 'First name',
                      child: TextFormField(
                        controller: _firstName,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.givenName],
                        textInputAction: TextInputAction.next,
                        validator: requiredField,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LabeledField(
                      label: 'Last name',
                      child: TextFormField(
                        controller: _lastName,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.familyName],
                        textInputAction: TextInputAction.next,
                        validator: requiredField,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: 'Email',
                child: TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: emailField,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline)),
                ),
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: 'Password',
                hint: 'At least 8 characters.',
                child: PasswordField(
                  controller: _password,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: (v) => (v == null || v.length < 8) ? 'Use at least 8 characters' : null,
                ),
              ),
              ErrorNote(_error),
              const SizedBox(height: 20),
              BusyButton(label: 'Create account', busyLabel: 'Creating account…', busy: _submitting, onPressed: _submit),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Already have an account?', style: TextStyle(color: p.mutedForeground)),
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Log in')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
