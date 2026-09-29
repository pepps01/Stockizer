import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/verify_email_screen.dart';
import 'services/api_client.dart';
import 'state/auth_provider.dart';
import 'theme.dart';
import 'widgets/app_shell.dart';

void main() {
  runApp(const TickizerApp());
}

class TickizerApp extends StatelessWidget {
  const TickizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>(create: (_) => ApiClient()),
        ChangeNotifierProvider<AuthProvider>(create: (context) => AuthProvider(context.read<ApiClient>())),
      ],
      child: MaterialApp(
        title: 'Tickizer',
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        home: const AppShell(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/verify-email': (_) => const VerifyEmailScreen(),
        },
      ),
    );
  }
}
