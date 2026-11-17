import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_client.dart';
import 'services/push_service.dart';
import 'services/realtime_client.dart';
import 'state/auth_provider.dart';
import 'state/onboarding_store.dart';
import 'state/push_registrar.dart';
import 'state/settings_controller.dart';
import 'state/shell_controller.dart';
import 'theme.dart';
import 'widgets/app_shell.dart';

void main() {
  runApp(const StockiserApp());
}

class StockiserApp extends StatelessWidget {
  const StockiserApp({super.key, this.api, this.realtime, this.onboarding, this.push, this.minSplash = const Duration(milliseconds: 1400)});

  /// Overridable for tests.
  final ApiClient? api;
  final RealtimeClient? realtime;
  final OnboardingStore? onboarding;
  final PushService? push;
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
        Provider<PushRegistrar>(create: (context) => PushRegistrar(context.read<ApiClient>(), push ?? DevicePushService())),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(context.read<ApiClient>(), context.read<RealtimeClient>(), context.read<PushRegistrar>()),
        ),
        ChangeNotifierProvider<ShellController>(create: (_) => ShellController()),
        ChangeNotifierProvider<SettingsController>(create: (_) => SettingsController()),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          title: 'Stockiser',
          themeMode: context.watch<SettingsController>().themeMode,
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          home: AppRoot(minSplash: minSplash),
        ),
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
    await _initPush();
    if (!mounted) return;
    await context.read<SettingsController>().load();
    if (!mounted) return;
    final results = await Future.wait<Object?>([store.hasSeen(), auth.restore(), Future<void>.delayed(widget.minSplash)]);
    if (!mounted) return;
    setState(() {
      _onboarded = results.first as bool;
      _ready = true;
    });
  }

  /// Notification channels and (when configured) Firebase. A failure here must
  /// never block start-up: signals still arrive in-app.
  Future<void> _initPush() async {
    try {
      await context.read<PushRegistrar>().push.init();
    } catch (e) {
      debugPrint('Push init failed: $e');
    }
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
