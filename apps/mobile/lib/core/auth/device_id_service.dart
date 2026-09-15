import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'auth_constants.dart';

/// Client-generated device id. Set once on first install, never changes.
/// SYNC-PROTOCOL.md §6.4 / DATA-MODEL.md §3.2.
class DeviceIdService {
  DeviceIdService({
    FlutterSecureStorage? storage,
    Uuid? uuid,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _uuid = uuid ?? const Uuid();

  final FlutterSecureStorage _storage;
  final Uuid _uuid;

  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: kDeviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final created = _uuid.v4();
    await _storage.write(key: kDeviceIdKey, value: created);
    return created;
  }
}
