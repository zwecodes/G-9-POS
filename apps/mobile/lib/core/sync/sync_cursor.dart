import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String kLastSyncAtKey = 'g9pos_last_sync_at';

/// Device watermark for `GET /v1/sync/pull` (`last_sync_at`).
/// Local-only; not a shop-data column.
class SyncCursor {
  SyncCursor({
    FlutterSecureStorage? storage,
    Map<String, String>? memory,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _memory = memory;

  final FlutterSecureStorage _storage;
  final Map<String, String>? _memory;

  Future<int> getLastSyncAtMs() async {
    final raw = await _read(kLastSyncAtKey);
    if (raw == null || raw.isEmpty) return 0;
    return int.tryParse(raw) ?? 0;
  }

  Future<void> setLastSyncAtMs(int ms) async {
    await _write(kLastSyncAtKey, '$ms');
  }

  Future<String?> _read(String key) async {
    if (_memory != null) return _memory[key];
    return _storage.read(key: key);
  }

  Future<void> _write(String key, String value) async {
    if (_memory != null) {
      _memory[key] = value;
      return;
    }
    await _storage.write(key: key, value: value);
  }
}
