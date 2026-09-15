/// CODING-STANDARDS.md §8 — never hardcode a production host.
const String kApiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8080',
);

const String kAuthLoginPath = '/v1/auth/login';
const String kAuthRefreshPath = '/v1/auth/refresh';

/// flutter_secure_storage keys — SYNC-PROTOCOL.md §6.4.
const String kAccessTokenKey = 'g9pos_access_token';
const String kRefreshTokenKey = 'g9pos_refresh_token';
const String kUserIdKey = 'g9pos_user_id';
const String kUserRoleKey = 'g9pos_user_role';
const String kDeviceIdKey = 'g9pos_device_id';
const String kTokenExpiresAtKey = 'g9pos_token_expires_at';

/// Access token TTL: 15 minutes.
const int kAccessTokenTtlMs = 15 * 60 * 1000;

/// Refresh token TTL: 30 days.
const int kRefreshTokenTtlMs = 30 * 24 * 60 * 60 * 1000;
