import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../services/api_client.dart';
import '../services/realtime_client.dart';

/// Session state — mirrors frontend/src/lib/auth-context.tsx. The JWT is kept
/// in SharedPreferences and handed to the realtime socket so the user's
/// Adviser signals are pushed to this device.
class AuthProvider extends ChangeNotifier {
  static const _tokenKey = 'algizer_token';

  AuthProvider(this._api, this._realtime);

  final ApiClient _api;
  final RealtimeClient _realtime;

  User? user;
  String? token;
  bool isRestoring = true;

  bool get isSignedIn => token != null && user != null;

  /// Restores a stored session; an expired or revoked token is discarded.
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_tokenKey);
    if (stored != null) {
      try {
        user = await _api.getMe(stored);
        token = stored;
      } on ApiException catch (e) {
        // Keep the token when the server is merely unreachable; drop it when rejected.
        if (e.statusCode != 0) await prefs.remove(_tokenKey);
      }
    }
    _realtime.setToken(token);
    isRestoring = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final (accessToken, loggedInUser) = await _api.login(email.trim(), password);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    token = accessToken;
    user = loggedInUser;
    _realtime.setToken(token);
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    token = null;
    user = null;
    _realtime.setToken(null);
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (token == null) return;
    user = await _api.getMe(token!);
    notifyListeners();
  }

  void setUser(User updated) {
    user = updated;
    notifyListeners();
  }
}
