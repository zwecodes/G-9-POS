import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_constants.dart';

class TokenCache {
  TokenCache({
    FlutterSecureStorage? storage,
    int Function()? nowMs,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _nowMs = nowMs ?? _defaultNowMs;

  final FlutterSecureStorage _storage;
  final int Function() _nowMs;

  static int _defaultNowMs() => DateTime.now().millisecondsSinceEpoch;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresAt,
    required String userId,
    required String userRole,
  }) async {
    await _storage.write(key: kAccessTokenKey, value: accessToken);
    await _storage.write(key: kRefreshTokenKey, value: refreshToken);
    await _storage.write(key: kTokenExpiresAtKey, value: '$expiresAt');
    await _storage.write(key: kUserIdKey, value: userId);
    await _storage.write(key: kUserRoleKey, value: userRole);
  }

  Future<String?> getAccessToken() => _storage.read(key: kAccessTokenKey);

  Future<String?> getRefreshToken() => _storage.read(key: kRefreshTokenKey);

  Future<bool> isAccessTokenValid() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) return false;
    final raw = await _storage.read(key: kTokenExpiresAtKey);
    if (raw == null || raw.isEmpty) return false;
    final expiresAt = int.tryParse(raw);
    if (expiresAt == null) return false;
    return _nowMs() < expiresAt;
  }

  Future<String?> getUserId() => _storage.read(key: kUserIdKey);

  Future<String?> getUserRole() => _storage.read(key: kUserRoleKey);

  /// Sign-out. Does not touch [kDeviceIdKey].
  Future<void> clearTokens() async {
    await _storage.delete(key: kAccessTokenKey);
    await _storage.delete(key: kRefreshTokenKey);
    await _storage.delete(key: kTokenExpiresAtKey);
    await _storage.delete(key: kUserIdKey);
    await _storage.delete(key: kUserRoleKey);
  }
}
