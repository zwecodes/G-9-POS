import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// CODING-STANDARDS.md §8 — never hardcode a production host.
const String kApiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8080',
);

class ApiException implements Exception {
  const ApiException(this.message, {this.code, this.statusCode, this.details});

  final String message;
  final String? code;
  final int? statusCode;
  final Object? details;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required Future<String?> Function() accessToken,
    http.Client? httpClient,
  })  : _accessToken = accessToken,
        _http = httpClient ?? http.Client();

  final String baseUrl;
  final Future<String?> Function() _accessToken;
  final http.Client _http;

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await _accessToken();
      if (token == null || token.isEmpty) {
        throw const ApiException(
          'Sign in again to continue.',
          code: 'UNAUTHORIZED',
          statusCode: 401,
        );
      }
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await _http.post(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final token = await _accessToken();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        'Sign in again to continue.',
        code: 'UNAUTHORIZED',
        statusCode: 401,
      );
    }
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final response = await _http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return _decode(response);
  }

  /// GET where `data` is a JSON array.
  Future<List<dynamic>> getList(
    String path, {
    Map<String, String>? query,
  }) async {
    final decoded = await getJson(path, query: query);
    final data = decoded['data'];
    if (data is List) return data;
    return const [];
  }

  Future<Map<String, dynamic>> postMultipartFile({
    required String path,
    required String fieldName,
    required String fileName,
    required List<int> bytes,
  }) async {
    final token = await _accessToken();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        'Sign in again to continue.',
        code: 'UNAUTHORIZED',
        statusCode: 401,
      );
    }
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.files.add(
      http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: fileName,
        contentType: MediaType('text', 'csv'),
      ),
    );
    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(response.body);
      json = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      throw ApiException(
        'Could not reach the server. Try again.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json['data'];
      if (data is Map<String, dynamic>) return data;
      return <String, dynamic>{'data': data};
    }
    final error = json['error'];
    if (error is Map<String, dynamic>) {
      throw ApiException(
        (error['message'] as String?) ?? 'Something went wrong. Try again.',
        code: error['code'] as String?,
        statusCode: response.statusCode,
        details: error['details'],
      );
    }
    throw ApiException(
      'Something went wrong. Try again.',
      statusCode: response.statusCode,
    );
  }
}
