import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../services/api_client.dart';

class AuthProvider extends ChangeNotifier {
  static const _tokenKey = 'tickizer_token';

  final ApiClient _api;
  User? user;
  String? token;
  bool isLoading = true;

  AuthProvider(this._api) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_tokenKey);
    if (stored == null) {
      isLoading = false;
      notifyListeners();
      return;
    }
    token = stored;
    try {
      user = await _api.getMe(stored);
    } catch (_) {
      await prefs.remove(_tokenKey);
      token = null;
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final (accessToken, loggedInUser) = await _api.login(email, password);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    token = accessToken;
    user = loggedInUser;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    token = null;
    user = null;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (token == null) return;
    user = await _api.getMe(token!);
    notifyListeners();
  }
}
