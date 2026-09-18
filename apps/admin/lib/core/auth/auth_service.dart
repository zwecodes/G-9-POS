import '../api/api_client.dart';
import 'session_store.dart';

class AuthService {
  AuthService({
    required ApiClient api,
    required SessionStore store,
  })  : _api = api,
        _store = store;

  final ApiClient _api;
  final SessionStore _store;

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final deviceId = await _store.deviceId();
    final data = await _api.postJson('/v1/auth/login', {
      'username': username.trim(),
      'password': password,
      'device_id': deviceId,
      'device_name': 'G9POS Admin',
      'device_type': 'dashboard',
      'login_context': 'dashboard',
    });
    final user = data['user'];
    if (user is! Map<String, dynamic>) {
      throw const ApiException('Could not sign in. Try again.');
    }
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    final expiresAt = data['expires_at'];
    final userId = user['id'] as String?;
    final name = user['name'] as String? ?? username;
    final role = user['role'] as String?;
    if (access == null ||
        refresh == null ||
        userId == null ||
        role == null ||
        expiresAt is! num) {
      throw const ApiException('Could not sign in. Try again.');
    }
    if (role != 'dashboard_viewer') {
      throw const ApiException(
        'This login is for the shop dashboard only.',
      );
    }
    await _store.saveSession(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expiresAt.toInt(),
      userId: userId,
      userName: name,
      role: role,
    );
  }

  Future<void> logout() async {
    final refresh = await _store.refreshToken();
    try {
      await _api.postJson(
        '/v1/auth/logout',
        {'refresh_token': refresh},
        auth: true,
      );
    } catch (_) {
      // Always clear local session.
    }
    await _store.clear();
  }
}
