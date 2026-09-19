import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import '../../../core/auth/app_identity.dart';
import '../../../core/auth/token_cache.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_enqueue.dart';
import '../../../core/sync/sync_event.dart';
import '../../../core/utils/repository_exception.dart';
import '../../../core/utils/repository_write.dart';
import '../../../core/utils/uuid_generator.dart';

/// Device activation is a sync event; rename is online PATCH (API-SPEC.md §3).
class DeviceSettingsRepository {
  DeviceSettingsRepository({
    required AppDatabase db,
    required AppIdentity identity,
    required TokenCache tokens,
    required String apiUrl,
    UuidGenerator? uuids,
    Logger? logger,
    int Function()? nowMs,
    http.Client? httpClient,
  })  : _db = db,
        _identity = identity,
        _tokens = tokens,
        _apiUrl = apiUrl,
        _uuids = uuids ?? UuidGenerator(),
        _log = logger ?? Logger(),
        _nowMs = nowMs ?? _defaultNowMs,
        _http = httpClient ?? http.Client();

  final AppDatabase _db;
  final AppIdentity _identity;
  final TokenCache _tokens;
  final String _apiUrl;
  final UuidGenerator _uuids;
  final Logger _log;
  final int Function() _nowMs;
  final http.Client _http;

  static int _defaultNowMs() => DateTime.now().millisecondsSinceEpoch;

  /// Queues `DEVICE_ACTIVATED` — works offline; flushes when online.
  Future<void> activateThisDevice() {
    return runRepositoryWrite(
      _log,
      'Could not activate device',
      'Could not make this the active POS. Try again.',
      () async {
        requireOwnerRole(_identity.operatorRole);
        final id = _uuids.v4();
        final now = _nowMs();
        final deviceId = await _identity.deviceId;
        final operatorId = _identity.operatorId;
        await enqueueSyncEvent(
          _db.syncQueueDao,
          id: id,
          eventType: SyncEventType.deviceActivated,
          deviceId: deviceId,
          operatorId: operatorId,
          createdAt: now,
          referenceId: null,
        );
      },
    );
  }

  /// Online-only rename via `PATCH /v1/devices/{id}`.
  Future<void> renameThisDevice(String name) {
    return runRepositoryWrite(
      _log,
      'Could not rename device',
      'Could not rename this device. Check the connection and try again.',
      () async {
        requireOwnerRole(_identity.operatorRole);
        final trimmed = name.trim();
        if (trimmed.isEmpty) {
          throw const RepositoryException('Please enter a device name.');
        }
        final token = await _tokens.getAccessToken();
        if (token == null || token.isEmpty) {
          throw const RepositoryException(
            'Sign in again to rename this device.',
          );
        }
        final deviceId = await _identity.deviceId;
        final response = await _http.patch(
          Uri.parse('$_apiUrl/v1/devices/$deviceId'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'name': trimmed}),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return;
        }
        if (response.statusCode == 401) {
          throw const RepositoryException(
            'Sign in again to rename this device.',
          );
        }
        throw const RepositoryException(
          'Could not rename this device. Try again.',
        );
      },
    );
  }
}
