import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/config.dart';

class ApiService {
  ApiService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  final FlutterSecureStorage _storage =
      const FlutterSecureStorage();

  static const Map<String, String> _baseHeaders = {
    'Content-Type': 'application/json',
  };

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'jwt_token');
    final companyId =
        await _storage.read(key: 'selected_company_id');
    final companyCode =
        await _storage.read(key: 'selected_company_code');

    return {
      ..._baseHeaders,
      if (token != null) 'Authorization': 'Bearer $token',
      if (companyId != null) 'company-id': companyId,
      if (companyCode != null) 'x-company-code': companyCode,
    };
  }

  Uri _uri(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) {
    final uri = Uri.parse(
      '${Config.baseUrl}/api/$endpoint',
    );

    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        ...queryParameters.map(
          (key, value) => MapEntry(key, value.toString()),
        ),
      },
    );
  }

  Future<http.Response> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) async {
    final headers =
        authenticated ? await _authHeaders() : _baseHeaders;

    return _client.get(
      _uri(
        endpoint,
        queryParameters: queryParameters,
      ),
      headers: headers,
    );
  }

  Future<http.Response> post(
    String endpoint, {
    dynamic body,
    bool authenticated = true,
  }) async {
    final headers =
        authenticated ? await _authHeaders() : _baseHeaders;

    return _client.post(
      _uri(endpoint),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );
  }

  Future<http.Response> put(
    String endpoint, {
    dynamic body,
    bool authenticated = true,
  }) async {
    final headers =
        authenticated ? await _authHeaders() : _baseHeaders;

    return _client.put(
      _uri(endpoint),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );
  }

  Future<http.Response> delete(
    String endpoint, {
    dynamic body,
    bool authenticated = true,
  }) async {
    final headers =
        authenticated ? await _authHeaders() : _baseHeaders;

    return _client.delete(
      _uri(endpoint),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );
  }

  dynamic decodeResponse(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }

    return jsonDecode(response.body);
  }

  void dispose() {
    _client.close();
  }
}