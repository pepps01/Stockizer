import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/api_client.dart';
import '../services/push_service.dart';

/// Keeps the server's list of this phone's push tokens in step with the
/// signed-in user: registers after sign-in (when push is on), re-registers when
/// FCM rotates the token, and unregisters on sign-out.
class PushRegistrar {
  PushRegistrar(this._api, this.push);

  final ApiClient _api;
  final PushService push;
  StreamSubscription<String>? _refresh;
  String? _authToken;

  /// Called after sign-in or session restore.
  Future<void> sync(String authToken, User user) async {
    _authToken = authToken;
    if (!user.alertChannels.contains('push')) return;
    await _register();
  }

  /// The user switched push on: ask the OS, then register. False when denied.
  Future<bool> enable(String authToken) async {
    _authToken = authToken;
    final granted = await push.requestPermission();
    if (granted) await _register();
    return granted;
  }

  Future<void> forget(String authToken) async {
    await _refresh?.cancel();
    _refresh = null;
    _authToken = null;
    try {
      final deviceToken = await push.deviceToken();
      if (deviceToken != null) await _api.unregisterDevice(authToken, deviceToken);
    } catch (e) {
      debugPrint('Push unregister failed: $e');
    }
  }

  Future<void> _register() async {
    if (!push.remoteAvailable) return; // local notifications need no server registration
    final deviceToken = await push.deviceToken();
    if (deviceToken != null) await _send(deviceToken);
    _refresh ??= push.tokenRefresh.listen(_send);
  }

  Future<void> _send(String deviceToken) async {
    final auth = _authToken;
    if (auth == null) return;
    try {
      await _api.registerDevice(auth, deviceToken, push.platform);
    } catch (e) {
      debugPrint('Push register failed: $e');
    }
  }
}
