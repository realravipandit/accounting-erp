import 'dart:convert';
import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/config.dart';

class ApiService {
  ApiService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  final FlutterSecureStorage _storage =
      const FlutterSecureStorage();

  static const String _activeServerKey = 'active_server_address';

  static const Map<String, String> _baseHeaders = {
    'Content-Type': 'application/json',
  };

  // ============================================================
  // AUTH HEADERS
  // ============================================================

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'jwt_token');

    final companyId =
        await _storage.read(key: 'selected_company_id');

    final companyCode =
        await _storage.read(key: 'selected_company_code');

    return {
      ..._baseHeaders,
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
      if (companyId != null && companyId.isNotEmpty)
        'company-id': companyId,
      if (companyCode != null && companyCode.isNotEmpty)
        'x-company-code': companyCode,
    };
  }

  // ============================================================
  // SERVER ADDRESS
  // ============================================================

  Future<String> _getBaseUrl() async {
    final savedServer =
        await _storage.read(key: _activeServerKey);

    if (savedServer != null && savedServer.trim().isNotEmpty) {
      var server = savedServer.trim();

      // Add protocol if user entered only an IP/domain.
      if (!server.startsWith('http://') &&
          !server.startsWith('https://')) {
        server = 'http://$server';
      }

      // Remove trailing slash.
      while (server.endsWith('/')) {
        server = server.substring(0, server.length - 1);
      }

      return server;
    }

    // Fallback only if no server has been saved yet.
    return Config.baseUrl;
  }

  // ============================================================
  // BUILD URI
  // ============================================================

  Future<Uri> _uri(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final baseUrl = await _getBaseUrl();

    final cleanEndpoint = endpoint.startsWith('/')
        ? endpoint.substring(1)
        : endpoint;

    final uri = Uri.parse(
      '$baseUrl/api/$cleanEndpoint',
    );

    if (queryParameters == null ||
        queryParameters.isEmpty) {
      return uri;
    }

    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        ...queryParameters.map(
          (key, value) => MapEntry(
            key,
            value.toString(),
          ),
        ),
      },
    );
  }

  // ============================================================
  // GET
  // ============================================================

  Future<http.Response> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) async {
    final headers = authenticated
        ? await _authHeaders()
        : _baseHeaders;

    final uri = await _uri(
      endpoint,
      queryParameters: queryParameters,
    );

    return _client.get(
      uri,
      headers: headers,
    ).timeout(const Duration(seconds: 10)); // Added timeout
  }

  // ============================================================
  // POST
  // ============================================================

  Future<http.Response> post(
    String endpoint, {
    dynamic body,
    bool authenticated = true,
  }) async {
    final headers = authenticated
        ? await _authHeaders()
        : _baseHeaders;

    final uri = await _uri(endpoint);

    return _client.post(
      uri,
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    ).timeout(const Duration(seconds: 10)); // Added timeout
  }

  // ============================================================
  // PUT
  // ============================================================

  Future<http.Response> put(
    String endpoint, {
    dynamic body,
    bool authenticated = true,
  }) async {
    final headers = authenticated
        ? await _authHeaders()
        : _baseHeaders;

    final uri = await _uri(endpoint);

    return _client.put(
      uri,
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    ).timeout(const Duration(seconds: 10)); // Added timeout
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<http.Response> delete(
    String endpoint, {
    dynamic body,
    bool authenticated = true,
  }) async {
    final headers = authenticated
        ? await _authHeaders()
        : _baseHeaders;

    final uri = await _uri(endpoint);

    return _client.delete(
      uri,
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    ).timeout(const Duration(seconds: 10)); // Added timeout
  }

  // ============================================================
  // RESPONSE DECODER
  // ============================================================

  dynamic decodeResponse(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }

    return jsonDecode(response.body);
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    _client.close();
  }
}