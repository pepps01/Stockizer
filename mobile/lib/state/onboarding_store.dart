import 'package:shared_preferences/shared_preferences.dart';

/// Remembers that the onboarding carousel was completed on this device.
class OnboardingStore {
  static const _seenKey = 'algizer_onboarding_seen';

  Future<bool> hasSeen() async => (await SharedPreferences.getInstance()).getBool(_seenKey) ?? false;

  Future<void> markSeen() async => (await SharedPreferences.getInstance()).setBool(_seenKey, true);
}
