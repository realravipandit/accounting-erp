import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_service.dart';

class AuthService {
  AuthService({
    ApiService? apiService,
    FlutterSecureStorage? storage,
  })  : _api = apiService ?? ApiService(),
        _storage = storage ?? const FlutterSecureStorage();

  final ApiService _api;
  final FlutterSecureStorage _storage;

  Future<bool> login(
    String username,
    String password,
    String centralDatabase,
  ) async {
    final response = await _api.post(
      'login',
      authenticated: false,
      body: {
        'username': username,
        'password': password,
        'centralDatabase': centralDatabase,
      },
    );

    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(response.body);

    final token =
        data['accessToken'] ?? data['token'];

    if (token == null) {
      return false;
    }

    await _storage.write(
      key: 'jwt_token',
      value: token.toString(),
    );

    return true;
  }

  Future<List<dynamic>> getCompanies() async {
    final response = await _api.get(
      'companies',
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load companies');
    }

    final data = jsonDecode(response.body);

    if (data is List) {
      return data;
    }

    return [];
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'selected_company_id');
    await _storage.delete(key: 'selected_company_code');
  }

  Future<bool> isAuthenticated() async {
    final token =
        await _storage.read(key: 'jwt_token');

    return token != null && token.isNotEmpty;
  }
}