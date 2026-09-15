import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_constants.dart';

class TokenCache {
  TokenCache({
    FlutterSecureStorage? storage,
    int Function()? nowMs,
    Map<String, String>? memory,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _nowMs = nowMs ?? _defaultNowMs,
        _memory = memory;

  final FlutterSecureStorage _storage;
  final int Function() _nowMs;
  final Map<String, String>? _memory;

  static int _defaultNowMs() => DateTime.now().millisecondsSinceEpoch;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresAt,
    required String userId,
    required String userRole,
  }) async {
    await _write(kAccessTokenKey, accessToken);
    await _write(kRefreshTokenKey, refreshToken);
    await _write(kTokenExpiresAtKey, '$expiresAt');
    await _write(kUserIdKey, userId);
    await _write(kUserRoleKey, userRole);
  }

  Future<String?> getAccessToken() => _read(kAccessTokenKey);

  Future<String?> getRefreshToken() => _read(kRefreshTokenKey);

  Future<bool> isAccessTokenValid() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) return false;
    final raw = await _read(kTokenExpiresAtKey);
    if (raw == null || raw.isEmpty) return false;
    final expiresAt = int.tryParse(raw);
    if (expiresAt == null) return false;
    return _nowMs() < expiresAt;
  }

  Future<String?> getUserId() => _read(kUserIdKey);

  Future<String?> getUserRole() => _read(kUserRoleKey);

  /// Sign-out. Does not touch [kDeviceIdKey].
  Future<void> clearTokens() async {
    await _delete(kAccessTokenKey);
    await _delete(kRefreshTokenKey);
    await _delete(kTokenExpiresAtKey);
    await _delete(kUserIdKey);
    await _delete(kUserRoleKey);
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

  Future<void> _delete(String key) async {
    if (_memory != null) {
      _memory.remove(key);
      return;
    }
    await _storage.delete(key: key);
  }
}
