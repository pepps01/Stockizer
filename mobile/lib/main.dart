import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_client.dart';
import 'services/realtime_client.dart';
import 'state/auth_provider.dart';
import 'state/onboarding_store.dart';
import 'state/shell_controller.dart';
import 'theme.dart';
import 'widgets/app_shell.dart';

void main() {
  runApp(const AlgizerApp());
}

class AlgizerApp extends StatelessWidget {
  const AlgizerApp({super.key, this.api, this.realtime, this.onboarding, this.minSplash = const Duration(milliseconds: 1400)});

  /// Overridable for tests.
  final ApiClient? api;
  final RealtimeClient? realtime;
  final OnboardingStore? onboarding;
  final Duration minSplash;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>(create: (_) => api ?? ApiClient()),
        Provider<OnboardingStore>(create: (_) => onboarding ?? OnboardingStore()),
        Provider<RealtimeClient>(
          create: (context) => realtime ?? RealtimeClient(context.read<ApiClient>().socketUrl),
          dispose: (_, client) => client.dispose(),
        ),
        ChangeNotifierProvider<AuthProvider>(create: (context) => AuthProvider(context.read<ApiClient>(), context.read<RealtimeClient>())),
        ChangeNotifierProvider<ShellController>(create: (_) => ShellController()),
      ],
      child: MaterialApp(
        title: 'Algizer',
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        home: AppRoot(minSplash: minSplash),
      ),
    );
  }
}

/// Splash → onboarding (first launch) → login → home shell.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key, required this.minSplash});

  final Duration minSplash;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _ready = false;
  bool _onboarded = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final auth = context.read<AuthProvider>();
    final store = context.read<OnboardingStore>();
    final results = await Future.wait<Object?>([store.hasSeen(), auth.restore(), Future<void>.delayed(widget.minSplash)]);
    if (!mounted) return;
    setState(() {
      _onboarded = results.first as bool;
      _ready = true;
    });
  }

  Future<void> _finishOnboarding(OnboardingExit exit) async {
    await context.read<OnboardingStore>().markSeen();
    if (!mounted) return;
    setState(() => _onboarded = true);
    if (exit == OnboardingExit.register) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).push(RegisterScreen.route());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = context.select<AuthProvider, bool>((auth) => auth.isSignedIn);
    final Widget page;
    if (!_ready) {
      page = const SplashScreen(key: ValueKey('splash'));
    } else if (!_onboarded) {
      page = OnboardingScreen(key: const ValueKey('onboarding'), onDone: _finishOnboarding);
    } else if (!signedIn) {
      page = const LoginScreen(key: ValueKey('login'));
    } else {
      page = const AppShell(key: ValueKey('shell'));
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: page);
  }
}
