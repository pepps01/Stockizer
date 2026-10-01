import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/market.dart';
import '../models/strategy.dart';

enum RealtimeState { connecting, open, closed }

/// One shared WebSocket to the backend gateway (/ws) — the Dart twin of
/// frontend/src/lib/realtime.ts. Widgets subscribe to symbols (reference
/// counted, so a symbol shown twice is sent once) and listen for quote batches
/// and Adviser signals. Reconnects with backoff and re-subscribes afterwards.
class RealtimeClient {
  RealtimeClient(this.url);

  final String url;
  final ValueNotifier<RealtimeState> state = ValueNotifier(RealtimeState.closed);

  final _subscriptions = <String, int>{};
  final _latest = <String, Quote>{};
  final _quotes = StreamController<Map<String, Quote>>.broadcast();
  final _signals = StreamController<SignalEvent>.broadcast();

  String? _token;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSub;
  Timer? _retryTimer;
  Timer? _heartbeat;
  Duration _retryDelay = const Duration(seconds: 1);
  bool _disposed = false;

  Stream<Map<String, Quote>> get quotes => _quotes.stream;
  Stream<SignalEvent> get signals => _signals.stream;

  Quote? latestQuote(String symbol) => _latest[symbol.toUpperCase()];

  /// The JWT scopes pushed signals to the user; changing it reconnects.
  void setToken(String? token) {
    if (token == _token) return;
    _token = token;
    if (_channel != null || _retryTimer != null) _reconnectNow();
  }

  /// Subscribes to [symbols]; call the returned function to release them.
  VoidCallback subscribe(Iterable<String> symbols) {
    final wanted = symbols.map((s) => s.toUpperCase()).toList();
    final added = <String>[];
    for (final symbol in wanted) {
      final count = _subscriptions[symbol] ?? 0;
      _subscriptions[symbol] = count + 1;
      if (count == 0) added.add(symbol);
    }
    _ensureConnected();
    if (added.isNotEmpty) _send({'type': 'subscribe', 'symbols': added});

    var released = false;
    return () {
      if (released) return;
      released = true;
      final removed = <String>[];
      for (final symbol in wanted) {
        final count = (_subscriptions[symbol] ?? 1) - 1;
        if (count <= 0) {
          _subscriptions.remove(symbol);
          removed.add(symbol);
        } else {
          _subscriptions[symbol] = count;
        }
      }
      if (removed.isNotEmpty) _send({'type': 'unsubscribe', 'symbols': removed});
    };
  }

  /// Ensures the socket is open so the user's signals are pushed.
  void listenForSignals() => _ensureConnected();

  void _ensureConnected() {
    if (_disposed || _channel != null) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    state.value = RealtimeState.connecting;

    final uri = Uri.parse(_token == null ? url : '$url?token=${Uri.encodeQueryComponent(_token!)}');
    final WebSocketChannel channel;
    try {
      channel = WebSocketChannel.connect(uri);
    } catch (_) {
      _scheduleRetry();
      return;
    }
    _channel = channel;
    _socketSub = channel.stream.listen(
      _dispatch,
      onError: (_) => _onClosed(channel),
      onDone: () => _onClosed(channel),
      cancelOnError: true,
    );
    channel.ready.then((_) {
      if (_channel != channel) return;
      _retryDelay = const Duration(seconds: 1);
      state.value = RealtimeState.open;
      if (_subscriptions.isNotEmpty) _send({'type': 'subscribe', 'symbols': _subscriptions.keys.toList()});
      _heartbeat = Timer.periodic(const Duration(seconds: 25), (_) => _send({'type': 'ping'}));
    }, onError: (_) => _onClosed(channel));
  }

  void _onClosed(WebSocketChannel channel) {
    if (_channel != channel) return;
    _teardown();
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_disposed) return;
    state.value = RealtimeState.closed;
    _retryTimer = Timer(_retryDelay, () {
      _retryTimer = null;
      _ensureConnected();
    });
    _retryDelay = Duration(milliseconds: math.min(_retryDelay.inMilliseconds * 2, 30000));
  }

  void _reconnectNow() {
    final channel = _channel;
    _teardown();
    _retryTimer?.cancel();
    _retryTimer = null;
    channel?.sink.close();
    _ensureConnected();
  }

  void _teardown() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _socketSub?.cancel();
    _socketSub = null;
    _channel = null;
    state.value = RealtimeState.closed;
  }

  void _send(Map<String, Object?> message) {
    if (state.value != RealtimeState.open) return;
    _channel?.sink.add(jsonEncode(message));
  }

  void _dispatch(dynamic raw) {
    final Object? message;
    try {
      message = jsonDecode(raw as String);
    } catch (_) {
      return;
    }
    if (message is! Json) return;
    if (message['type'] == 'quotes' && message['quotes'] is Json) {
      final batch = (message['quotes'] as Json).map((symbol, q) => MapEntry(symbol, Quote.fromJson(q as Json)));
      _latest.addAll(batch);
      _quotes.add(batch);
    } else if (message['type'] == 'signal' && message['signal'] is Json) {
      _signals.add(SignalEvent.fromJson(message['signal'] as Json));
    }
  }

  void dispose() {
    _disposed = true;
    final channel = _channel;
    _teardown();
    _retryTimer?.cancel();
    channel?.sink.close();
    _quotes.close();
    _signals.close();
    state.dispose();
  }
}
