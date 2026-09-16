import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';

import '../auth/auth_constants.dart';
import 'sync_cursor.dart';
import 'sync_pull_applier.dart';
import 'sync_pull_payload.dart';

const String kSyncPullPath = '/v1/sync/pull';

Uri syncPullUri({required int lastSyncAtMs, required String deviceId}) {
  return Uri.parse('$kApiUrl$kSyncPullPath').replace(
    queryParameters: {
      'last_sync_at': '$lastSyncAtMs',
      'device_id': deviceId,
    },
  );
}

typedef SyncPullGetter = Future<String> Function({
  required Uri uri,
  required String? accessToken,
});

/// `GET /v1/sync/pull` — SYNC-PROTOCOL.md §9 / DATA-MODEL.md §7.
/// Never called from the sale path.
class SyncPuller {
  SyncPuller({
    required SyncPullApplier applier,
    required SyncCursor cursor,
    required Future<String?> Function() accessToken,
    required Future<String> Function() deviceId,
    Logger? logger,
    int Function()? nowMs,
    SyncPullGetter? getter,
    Duration httpTimeout = const Duration(seconds: 30),
    void Function(int lastSyncAtMs)? onCursor,
  })  : _applier = applier,
        _cursor = cursor,
        _accessToken = accessToken,
        _deviceId = deviceId,
        _log = logger ?? Logger(),
        _nowMs = nowMs ?? _defaultNowMs,
        _getter = getter ?? _defaultGetter,
        _httpTimeout = httpTimeout,
        _onCursor = onCursor;

  final SyncPullApplier _applier;
  final SyncCursor _cursor;
  final Future<String?> Function() _accessToken;
  final Future<String> Function() _deviceId;
  final Logger _log;
  final int Function() _nowMs;
  final SyncPullGetter _getter;
  final Duration _httpTimeout;
  final void Function(int lastSyncAtMs)? _onCursor;

  bool _pulling = false;

  static int _defaultNowMs() => DateTime.now().millisecondsSinceEpoch;

  Future<int> lastSyncAtMs() => _cursor.getLastSyncAtMs();

  Future<void> pull() async {
    if (_pulling) return;
    _pulling = true;
    try {
      final token = await _accessToken();
      if (token == null || token.isEmpty) return;
      final deviceId = await _deviceId();
      var lastSync = await _cursor.getLastSyncAtMs();
      for (var page = 0; page < 50; page++) {
        final body = await _getter(
          uri: syncPullUri(lastSyncAtMs: lastSync, deviceId: deviceId),
          accessToken: token,
        ).timeout(_httpTimeout);
        final payload = parsePullPayload(body);
        if (payload.isEmpty) {
          lastSync = _advance(lastSync, payload);
          await _saveCursor(lastSync);
          return;
        }
        await _applier.apply(payload);
        lastSync = _advance(lastSync, payload);
        await _saveCursor(lastSync);
        if (!payload.hitPageLimit) return;
      }
    } catch (error, stack) {
      _log.e('Sync pull failed', error: error, stackTrace: stack);
    } finally {
      _pulling = false;
    }
  }

  int _advance(int previous, PullPayload payload) {
    final paging = payload.pagingWatermark;
    if (paging != null) {
      return paging <= previous ? previous + 1 : paging;
    }
    final maxTs = payload.maxTimestamp;
    final now = _nowMs();
    final candidate = maxTs == null ? now : (maxTs > now ? maxTs : now);
    return candidate <= previous ? previous : candidate;
  }

  Future<void> _saveCursor(int lastSync) async {
    await _cursor.setLastSyncAtMs(lastSync);
    _onCursor?.call(lastSync);
  }

  static Future<String> _defaultGetter({
    required Uri uri,
    required String? accessToken,
  }) async {
    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: 15);
      final request = await client.getUrl(uri);
      if (accessToken != null && accessToken.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $accessToken',
        );
      }
      final response = await request.close();
      final responseBody = await utf8.decodeStream(response);
      if (response.statusCode != 200) {
        throw HttpException('Sync pull HTTP ${response.statusCode}', uri: uri);
      }
      return responseBody;
    } finally {
      client.close(force: true);
    }
  }
}
