import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';

import '../database/app_database.dart';
import 'sync_batch.dart';
import 'sync_rejection_handler.dart';

/// CODING-STANDARDS.md §8 — never hardcode a production host.
const String kApiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8080',
);
const String kSyncEventsPath = '/v1/sync/events';

Uri syncEventsUri() => Uri.parse('$kApiUrl$kSyncEventsPath');

/// SYNC-PROTOCOL.md §2.3 — delay before the Nth attempt (1-based).
Duration syncRetryDelay(int attempt) {
  if (attempt <= 1) return Duration.zero;
  if (attempt == 2) return const Duration(seconds: 5);
  if (attempt == 3) return const Duration(seconds: 30);
  return const Duration(minutes: 5);
}

class SyncEventsResult {
  const SyncEventsResult({
    required this.accepted,
    required this.rejected,
    required this.conflictIds,
  });

  final List<String> accepted;
  final List<RejectedEvent> rejected;
  final List<String> conflictIds;
}

class SyncHttpException implements Exception {
  const SyncHttpException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'SyncHttpException($statusCode): $message';
}

typedef SyncEventsPoster = Future<SyncEventsResult> Function({
  required Uri uri,
  required String? accessToken,
  required String body,
});

/// Background-only queue flusher. Never called from the sale path.
class SyncFlusher {
  SyncFlusher({
    required AppDatabase db,
    required SyncRejectionHandler rejectionHandler,
    required Future<String?> Function() accessToken,
    Logger? logger,
    int Function()? nowMs,
    SyncEventsPoster? poster,
    Duration httpTimeout = const Duration(seconds: 30),
  })  : _db = db,
        _rejectionHandler = rejectionHandler,
        _accessToken = accessToken,
        _log = logger ?? Logger(),
        _nowMs = nowMs ?? _defaultNowMs,
        _poster = poster ?? _defaultPoster,
        _httpTimeout = httpTimeout;

  final AppDatabase _db;
  final SyncRejectionHandler _rejectionHandler;
  final Future<String?> Function() _accessToken;
  final Logger _log;
  final int Function() _nowMs;
  final SyncEventsPoster _poster;
  final Duration _httpTimeout;

  bool _flushing = false;
  int _attempt = 1;
  Timer? _retryTimer;

  static int _defaultNowMs() => DateTime.now().millisecondsSinceEpoch;

  /// Sends pending queue items. Safe to call from connectivity or a timer.
  Future<void> flush() async {
    _retryTimer?.cancel();
    if (_flushing) return;
    _flushing = true;

    try {
      final pending = await _db.syncQueueDao.getPending();
      if (pending.isEmpty) {
        _attempt = 1;
        return;
      }

      final token = await _accessToken();
      final batches = buildBatches(pending);
      var transientFailure = false;

      for (final batch in batches) {
        try {
          await _sendBatch(batch, token);
        } catch (error, stack) {
          transientFailure = true;
          _log.e(
            'Sync batch could not be sent',
            error: error,
            stackTrace: stack,
          );
          break;
        }
      }

      if (transientFailure) {
        _scheduleRetry();
      } else {
        _attempt = 1;
      }
    } catch (error, stack) {
      _log.e('Sync flush failed', error: error, stackTrace: stack);
      _scheduleRetry();
    } finally {
      _flushing = false;
    }
  }

  void dispose() {
    _retryTimer?.cancel();
  }

  Future<void> _sendBatch(SyncBatch batch, String? token) async {
    if (batch.isEmpty) return;

    final deviceId = batch.items.first.deviceId;
    final body = jsonEncode({
      'device_id': deviceId,
      'events': batch.items.map(decodeQueuePayload).toList(),
    });

    if (utf8.encode(body).length > kSyncMaxPayloadBytes) {
      throw const SyncHttpException(
        413,
        'Sync batch is larger than 5MB',
      );
    }

    final result = await _poster(
      uri: syncEventsUri(),
      accessToken: token,
      body: body,
    ).timeout(_httpTimeout);

    final now = _nowMs();

    for (final id in result.accepted) {
      await _db.syncQueueDao.markSynced(id, now);
      await _db.inventoryEventDao.markSynced(id, now);
      await _db.saleDao.markSynced(id, now);
    }

    final handledGroups = <String>{};
    for (final rejected in result.rejected) {
      final key = rejected.referenceId ?? rejected.id;
      if (handledGroups.contains(key)) continue;
      handledGroups.add(key);
      await _rejectionHandler.handleRejection(rejected);
    }

    for (final id in result.conflictIds) {
      await _db.syncQueueDao.deleteById(id);
    }
  }

  void _scheduleRetry() {
    _attempt += 1;
    final delay = syncRetryDelay(_attempt);
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      unawaited(flush());
    });
  }

  static Future<SyncEventsResult> _defaultPoster({
    required Uri uri,
    required String? accessToken,
    required String body,
  }) async {
    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: 15);
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      if (accessToken != null && accessToken.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $accessToken',
        );
      }
      request.add(utf8.encode(body));
      final response = await request.close();
      final responseBody = await utf8.decodeStream(response);

      if (response.statusCode != 200) {
        throw SyncHttpException(
          response.statusCode,
          'Sync request failed',
        );
      }

      return parseSyncEventsResult(responseBody);
    } finally {
      client.close(force: true);
    }
  }
}

/// Unwraps API-SPEC.md §1.4 `{ data, meta }` and reads sync outcome arrays.
SyncEventsResult parseSyncEventsResult(String responseBody) {
  final decoded = jsonDecode(responseBody);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Sync response was not an object');
  }
  if (decoded['error'] is Map<String, dynamic>) {
    final error = decoded['error'] as Map<String, dynamic>;
    throw SyncHttpException(
      0,
      error['message'] as String? ?? 'Sync request failed',
    );
  }

  final dataRaw = decoded['data'];
  final data = dataRaw is Map<String, dynamic> ? dataRaw : decoded;

  final accepted = <String>[];
  final acceptedRaw = data['accepted'];
  if (acceptedRaw is List) {
    for (final item in acceptedRaw) {
      if (item is String) accepted.add(item);
    }
  }

  final rejected = <RejectedEvent>[];
  final rejectedRaw = data['rejected'];
  if (rejectedRaw is List) {
    for (final item in rejectedRaw) {
      if (item is Map) {
        rejected.add(
          RejectedEvent.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }
  }

  final conflictIds = <String>[];
  final conflictsRaw = data['conflicts'];
  if (conflictsRaw is List) {
    for (final item in conflictsRaw) {
      if (item is Map) {
        final id = item['id'];
        if (id is String) conflictIds.add(id);
      } else if (item is String) {
        conflictIds.add(item);
      }
    }
  }

  return SyncEventsResult(
    accepted: accepted,
    rejected: rejected,
    conflictIds: conflictIds,
  );
}
