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

  static const String _kTokenKey = 'jwt_token';
  static const String _kCompanyIdKey = 'selected_company_id';
  static const String _kCompanyCodeKey = 'selected_company_code';

  // ============================================================
  // LOGIN
  // ============================================================
  Future<bool> login(
    String username,
    String password,
    String centralDatabase,
  ) async {
    try {
      final response = await _api.post(
        'login',
        authenticated: false,
        body: {
          'username': username.trim(),
          'password': password,
          'centralDatabase': centralDatabase.trim(),
        },
      );

      if (response.statusCode != 200) {
        return false;
      }

      final dynamic data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        return false;
      }

      final token = data['accessToken'] ?? data['token'];
      if (token == null || token.toString().trim().isEmpty) {
        return false;
      }

      // 1. Just save the token. 
      // 2. The LoginScreen already handles saving the 'true/false' database toggle.
      await _storage.write(key: _kTokenKey, value: token.toString());

      return true;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // GET ACCESSIBLE COMPANIES
  // ============================================================
  Future<List<Map<String, dynamic>>> getCompanies() async {
    final response = await _api.get('companies');

    if (response.statusCode != 200) {
      throw Exception('Failed to load companies (Status: ${response.statusCode})');
    }

    final dynamic data = jsonDecode(response.body);

    if (data is List) {
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } else if (data is Map && data['data'] is List) {
      return (data['data'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }

    return [];
  }

  // ============================================================
  // LOGOUT & SESSION MANAGEMENT
  // ============================================================
  Future<void> logout() async {
    // Only deleting session tokens keeps your UI states and IPs intact
    await _storage.delete(key: _kTokenKey);
    await _storage.delete(key: _kCompanyIdKey);
    await _storage.delete(key: _kCompanyCodeKey);
  }

  Future<bool> isAuthenticated() async {
    final token = await _storage.read(key: _kTokenKey);
    return token != null && token.trim().isNotEmpty;
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _kTokenKey);
  }
}