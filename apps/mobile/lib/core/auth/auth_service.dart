import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';

import 'auth_constants.dart';
import 'device_id_service.dart';
import 'token_cache.dart';

enum AuthState {
  authenticated,
  tokenExpiredOffline,
  tokenExpiredOnline,
  unauthenticated,
}

class AuthException implements Exception {
  const AuthException(this.message, {this.code});

  final String message;
  final String? code;
}

class AuthHttpResponse {
  const AuthHttpResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

typedef AuthPoster = Future<AuthHttpResponse> Function({
  required Uri uri,
  required String body,
  String? accessToken,
});

/// Owner username+password login and JWT cache.
/// Staff unlock is PIN-only and does not call this service.
class AuthService {
  AuthService({
    required TokenCache tokens,
    required DeviceIdService deviceIds,
    required String deviceName,
    required String deviceType,
    Connectivity? connectivity,
    Logger? logger,
    int Function()? nowMs,
    AuthPoster? poster,
    Duration httpTimeout = const Duration(seconds: 30),
  })  : _tokens = tokens,
        _deviceIds = deviceIds,
        _deviceName = deviceName,
        _deviceType = deviceType,
        _connectivity = connectivity ?? Connectivity(),
        _log = logger ?? Logger(),
        _nowMs = nowMs ?? _defaultNowMs,
        _poster = poster ?? _defaultPoster,
        _httpTimeout = httpTimeout;

  final TokenCache _tokens;
  final DeviceIdService _deviceIds;
  final String _deviceName;
  final String _deviceType;
  final Connectivity _connectivity;
  final Logger _log;
  final int Function() _nowMs;
  final AuthPoster _poster;
  final Duration _httpTimeout;

  static int _defaultNowMs() => DateTime.now().millisecondsSinceEpoch;

  Future<void> login(String username, String password) async {
    try {
      final deviceId = await _deviceIds.getOrCreateDeviceId();
      final body = jsonEncode({
        'username': username,
        'password': password,
        'device_id': deviceId,
        'device_name': _deviceName,
        'device_type': _deviceType,
      });

      final response = await _poster(
        uri: Uri.parse('$kApiUrl$kAuthLoginPath'),
        body: body,
      ).timeout(_httpTimeout);

      final data = _unwrapData(
        response,
        fallback: 'Could not sign in. Check the connection and try again.',
        unauthorized: 'Username or password is wrong.',
      );

      await _saveSession(data, fallbackRefresh: null);
    } on AuthException {
      rethrow;
    } catch (error, stack) {
      _log.e('Sign in failed', error: error, stackTrace: stack);
      throw const AuthException(
        'Could not sign in. Check the connection and try again.',
      );
    }
  }

  Future<void> refreshToken() async {
    try {
      final refresh = await _tokens.getRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        throw const AuthException('Please sign in again.');
      }

      final access = await _tokens.getAccessToken();
      final body = jsonEncode({'refresh_token': refresh});

      final response = await _poster(
        uri: Uri.parse('$kApiUrl$kAuthRefreshPath'),
        body: body,
        accessToken: access,
      ).timeout(_httpTimeout);

      if (response.statusCode == 401) {
        await _tokens.clearTokens();
        throw const AuthException('Please sign in again.', code: 'UNAUTHORIZED');
      }

      final data = _unwrapData(
        response,
        fallback: 'Could not refresh the session. Try again.',
        unauthorized: 'Please sign in again.',
      );

      await _saveSession(data, fallbackRefresh: refresh);
    } on AuthException {
      rethrow;
    } catch (error, stack) {
      _log.e('Token refresh failed', error: error, stackTrace: stack);
      throw const AuthException('Could not refresh the session. Try again.');
    }
  }

  Future<AuthState> getAuthState() async {
    final accessValid = await _tokens.isAccessTokenValid();
    if (accessValid) return AuthState.authenticated;

    final refresh = await _tokens.getRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      return AuthState.unauthenticated;
    }

    if (await _hasConnectivity()) {
      return AuthState.tokenExpiredOnline;
    }
    return AuthState.tokenExpiredOffline;
  }

  Future<void> signOut() => _tokens.clearTokens();

  Future<void> _saveSession(
    Map<String, dynamic> data, {
    required String? fallbackRefresh,
  }) async {
    final accessToken = data['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthException(
        'Could not sign in. Check the connection and try again.',
      );
    }

    final refreshToken =
        (data['refresh_token'] as String?) ?? fallbackRefresh;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const AuthException(
        'Could not sign in. Check the connection and try again.',
      );
    }

    final user = data['user'];
    var userId = await _tokens.getUserId();
    var userRole = await _tokens.getUserRole();
    if (user is Map) {
      final id = user['id'];
      final role = user['role'];
      if (id is String && id.isNotEmpty) userId = id;
      if (role is String && role.isNotEmpty) userRole = role;
    }
    if (userId == null || userId.isEmpty || userRole == null || userRole.isEmpty) {
      throw const AuthException(
        'Could not sign in. Check the connection and try again.',
      );
    }

    await _tokens.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: _parseExpiresAt(data['expires_at']),
      userId: userId,
      userRole: userRole,
    );
  }

  int _parseExpiresAt(Object? raw) {
    if (raw is int) {
      return raw < 1000000000000 ? raw * 1000 : raw;
    }
    if (raw is num) {
      return _parseExpiresAt(raw.toInt());
    }
    if (raw is String && raw.isNotEmpty) {
      final asInt = int.tryParse(raw);
      if (asInt != null) return _parseExpiresAt(asInt);
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed.millisecondsSinceEpoch;
    }
    return _nowMs() + kAccessTokenTtlMs;
  }

  Map<String, dynamic> _unwrapData(
    AuthHttpResponse response, {
    required String fallback,
    required String unauthorized,
  }) {
    Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(response.body);
      if (raw is! Map<String, dynamic>) {
        throw AuthException(fallback);
      }
      decoded = raw;
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException(fallback);
    }

    final errorRaw = decoded['error'];
    if (errorRaw is Map) {
      throw AuthException(
        _messageForError(errorRaw, fallback, unauthorized),
        code: errorRaw['code'] as String?,
      );
    }

    if (response.statusCode == 401) {
      throw AuthException(unauthorized, code: 'UNAUTHORIZED');
    }
    if (response.statusCode != 200) {
      throw AuthException(fallback);
    }

    final data = decoded['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw AuthException(fallback);
  }

  String _messageForError(
    Map<dynamic, dynamic> error,
    String fallback,
    String unauthorized,
  ) {
    final code = error['code'] as String?;
    switch (code) {
      case 'ACCOUNT_LOCKED':
        return 'This account is locked. Try again in a few minutes.';
      case 'UNAUTHORIZED':
        return unauthorized;
      case 'RATE_LIMITED':
        return 'Too many attempts. Please wait and try again.';
      case 'FORBIDDEN':
        return 'You do not have permission to do that.';
    }
    return fallback;
  }

  Future<bool> _hasConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (error, stack) {
      _log.e(
        'Could not check connectivity',
        error: error,
        stackTrace: stack,
      );
      return false;
    }
  }

  static Future<AuthHttpResponse> _defaultPoster({
    required Uri uri,
    required String body,
    String? accessToken,
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
      return AuthHttpResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } finally {
      client.close(force: true);
    }
  }
}
