import 'dart:async';
import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../auth/session_store.dart';

typedef LiveEventHandler = void Function(String event, Map<String, dynamic> payload);

/// Dashboard-only socket — API-SPEC.md §11.
class LiveFeedClient {
  LiveFeedClient({
    required this.apiBaseUrl,
    required SessionStore store,
    Logger? logger,
  })  : _store = store,
        _log = logger ?? Logger();

  final String apiBaseUrl;
  final SessionStore _store;
  final Logger _log;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  var _delayMs = 1000;
  var _wanted = false;
  LiveEventHandler? onEvent;
  void Function(bool connected)? onConnectionChanged;

  Future<void> start() async {
    _wanted = true;
    await _connect();
  }

  Future<void> stop() async {
    _wanted = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
    onConnectionChanged?.call(false);
  }

  Future<void> _connect() async {
    if (!_wanted) return;
    final token = await _store.accessToken();
    if (token == null || token.isEmpty) {
      onConnectionChanged?.call(false);
      return;
    }

    await _sub?.cancel();
    await _channel?.sink.close();

    final wsUrl = _toWsUrl(apiBaseUrl, token);
    try {
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel = channel;
      await channel.ready;
      _delayMs = 1000;
      onConnectionChanged?.call(true);
      _sub = channel.stream.listen(
        _onMessage,
        onError: (Object error, StackTrace stack) {
          _log.w('Live feed error', error: error, stackTrace: stack);
          _scheduleReconnect();
        },
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (error, stack) {
      _log.w('Live feed connect failed', error: error, stackTrace: stack);
      onConnectionChanged?.call(false);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is! Map<String, dynamic>) return;
      final event = decoded['event'] as String?;
      final payload = decoded['payload'];
      if (event == null || payload is! Map<String, dynamic>) return;
      onEvent?.call(event, payload);
    } catch (error, stack) {
      _log.w('Live feed message ignored', error: error, stackTrace: stack);
    }
  }

  void _scheduleReconnect() {
    onConnectionChanged?.call(false);
    if (!_wanted) return;
    _reconnectTimer?.cancel();
    final wait = _delayMs;
    _delayMs = (_delayMs * 2).clamp(1000, 30000);
    _reconnectTimer = Timer(Duration(milliseconds: wait), () {
      if (_wanted) _connect();
    });
  }

  static String _toWsUrl(String apiBase, String token) {
    final uri = Uri.parse(apiBase);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: '/ws',
      queryParameters: {'token': token},
    ).toString();
  }
}

class LiveSaleItem {
  const LiveSaleItem({
    required this.id,
    required this.saleNumber,
    required this.totalAmountMmk,
    required this.createdAtMs,
  });

  final String id;
  final String saleNumber;
  final int totalAmountMmk;
  final int createdAtMs;
}

class LiveFeedState {
  const LiveFeedState({
    this.connected = false,
    this.recentSales = const [],
    this.notices = const [],
  });

  final bool connected;
  final List<LiveSaleItem> recentSales;
  final List<String> notices;

  LiveFeedState copyWith({
    bool? connected,
    List<LiveSaleItem>? recentSales,
    List<String>? notices,
  }) {
    return LiveFeedState(
      connected: connected ?? this.connected,
      recentSales: recentSales ?? this.recentSales,
      notices: notices ?? this.notices,
    );
  }
}
