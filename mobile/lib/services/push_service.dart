import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../format.dart';
import '../models/strategy.dart';

/// Firebase settings, passed at build time so no Firebase file is committed:
///
///   flutter run \
///     --dart-define=FIREBASE_API_KEY=... \
///     --dart-define=FIREBASE_APP_ID=1:...:android:... \
///     --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
///     --dart-define=FIREBASE_PROJECT_ID=...
///
/// Values come from the Firebase console (Project settings → Your apps).
/// Without them push still works as local notifications while the app runs.
class FirebaseConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static bool get configured => apiKey.isNotEmpty && appId.isNotEmpty && messagingSenderId.isNotEmpty && projectId.isNotEmpty;

  static FirebaseOptions get options =>
      const FirebaseOptions(apiKey: apiKey, appId: appId, messagingSenderId: messagingSenderId, projectId: projectId);
}

/// System notifications for Adviser signals.
abstract class PushService {
  /// True when Firebase is configured, so the server can reach the phone even
  /// when the app is closed. Otherwise signals are shown as local notifications
  /// while the app is running.
  bool get remoteAvailable;

  Future<void> init();

  /// Asks the OS for permission to notify; true when granted.
  Future<bool> requestPermission();

  /// The FCM registration token, or null when push isn't available.
  Future<String?> deviceToken();

  Stream<String> get tokenRefresh;

  /// Fires when the user opens the app from a signal notification.
  Stream<void> get opened;

  /// Shows a signal as a local notification.
  Future<void> showSignal(SignalEvent signal);

  String get platform;
}

class NoopPushService implements PushService {
  const NoopPushService();

  @override
  bool get remoteAvailable => false;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<String?> deviceToken() async => null;

  @override
  Stream<String> get tokenRefresh => const Stream.empty();

  @override
  Stream<void> get opened => const Stream.empty();

  @override
  Future<void> showSignal(SignalEvent signal) async {}

  @override
  String get platform => 'android';
}

class DevicePushService implements PushService {
  static const _channel = AndroidNotificationChannel(
    'signals', // the channel the server targets in FCM messages
    'Signals',
    description: 'BUY, SELL and HOLD signals from the Adviser',
    importance: Importance.high,
  );

  final _local = FlutterLocalNotificationsPlugin();
  final _opened = StreamController<void>.broadcast();
  bool _remote = false;
  bool _ready = false;

  @override
  bool get remoteAvailable => _remote;

  @override
  String get platform => !kIsWeb && Platform.isIOS ? 'ios' : 'android';

  @override
  Stream<void> get opened => _opened.stream;

  @override
  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
      onDidReceiveNotificationResponse: (_) => _opened.add(null),
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) _scheduleOpened();

    if (!FirebaseConfig.configured) return;
    try {
      await Firebase.initializeApp(options: FirebaseConfig.options);
      _remote = true;
      FirebaseMessaging.onMessageOpenedApp.listen((_) => _opened.add(null));
      if (await FirebaseMessaging.instance.getInitialMessage() != null) _scheduleOpened();
    } catch (e) {
      debugPrint('Firebase unavailable, falling back to local notifications: $e');
    }
  }

  /// Let the first screen build before routing to Signals.
  void _scheduleOpened() => Future<void>.delayed(const Duration(milliseconds: 600), () => _opened.add(null));

  @override
  Future<bool> requestPermission() async {
    if (_remote) {
      final settings = await FirebaseMessaging.instance.requestPermission();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }
    final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _local.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  @override
  Future<String?> deviceToken() async {
    if (!_remote) return null;
    try {
      // The backend sends through the FCM HTTP v1 API, which targets registration
      // tokens; the newer register()/onRegistered flow yields installation IDs instead.
      // ignore: deprecated_member_use
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('No FCM token: $e');
      return null;
    }
  }

  @override
  Stream<String> get tokenRefresh =>
      // ignore: deprecated_member_use
      _remote ? FirebaseMessaging.instance.onTokenRefresh : const Stream.empty();

  @override
  Future<void> showSignal(SignalEvent signal) async {
    await _local.show(
      id: signal.id.hashCode & 0x7fffffff,
      title: '${signal.signalType.wire} · ${signal.displaySymbol}',
      body: '${signal.name} at ${formatNumber(signal.price)} ${signal.currency} · ${(signal.confidence * 100).round()}% confidence',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(_channel.id, _channel.name,
            channelDescription: _channel.description, importance: Importance.high, priority: Priority.high),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: signal.symbol,
    );
  }
}
