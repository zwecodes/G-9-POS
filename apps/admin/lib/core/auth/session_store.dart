import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _kAccessToken = 'g9pos_admin_access_token';
const _kRefreshToken = 'g9pos_admin_refresh_token';
const _kExpiresAt = 'g9pos_admin_expires_at';
const _kUserId = 'g9pos_admin_user_id';
const _kUserName = 'g9pos_admin_user_name';
const _kUserRole = 'g9pos_admin_user_role';
const _kDeviceId = 'g9pos_admin_device_id';

class SessionStore {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String> deviceId() async {
    final prefs = await _prefs;
    final existing = prefs.getString(_kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await prefs.setString(_kDeviceId, id);
    return id;
  }

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required int expiresAt,
    required String userId,
    required String userName,
    required String role,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(_kAccessToken, accessToken);
    await prefs.setString(_kRefreshToken, refreshToken);
    await prefs.setInt(_kExpiresAt, expiresAt);
    await prefs.setString(_kUserId, userId);
    await prefs.setString(_kUserName, userName);
    await prefs.setString(_kUserRole, role);
  }

  Future<String?> accessToken() async =>
      (await _prefs).getString(_kAccessToken);

  Future<String?> refreshToken() async =>
      (await _prefs).getString(_kRefreshToken);

  Future<String?> userName() async => (await _prefs).getString(_kUserName);

  Future<String?> userRole() async => (await _prefs).getString(_kUserRole);

  Future<bool> hasSession() async {
    final token = await accessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
    await prefs.remove(_kExpiresAt);
    await prefs.remove(_kUserId);
    await prefs.remove(_kUserName);
    await prefs.remove(_kUserRole);
  }
}
