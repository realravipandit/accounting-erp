import 'dart:convert';

import '../../core/network/api_service.dart';

class LedgerService {
  LedgerService({
    ApiService? apiService,
  }) : _api = apiService ?? ApiService();

  final ApiService _api;

  // =========================================
  // CHECK LEDGER NAME
  // =========================================
  Future<bool> checkLedgerNameExists(String ledgerName) async {
    final response = await _api.get(
      'ledgers/check-name',
      queryParameters: {
        'name': ledgerName,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to check ledger name');
    }

    final data = jsonDecode(response.body);

    if (data is Map) {
      return data['exists'] == true;
    }

    return false;
  }

  // =========================================
  // CREATE LEDGER
  // =========================================
  Future<Map<String, dynamic>> createLedger(
    Map<String, dynamic> ledgerData,
  ) async {
    final response = await _api.post(
      'ledgers',
      body: ledgerData,
    );

    final data = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : <String, dynamic>{};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data is Map && data['error'] != null
            ? data['error'].toString()
            : data is Map && data['message'] != null
                ? data['message'].toString()
                : 'Failed to create ledger',
      );
    }

    if (data is Map<String, dynamic>) {
      return data;
    }

    return {};
  }

  // =========================================
  // NEXT LEDGER CODE
  // =========================================
  Future<String?> fetchNextLedgerCode(String prefix) async {
    final response = await _api.get(
      'ledgers/next-code',
      queryParameters: {
        'prefix': prefix,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get next ledger code');
    }

    final data = jsonDecode(response.body);

    if (data is Map) {
      return data['nextCode']?.toString() ??
          data['ledgerCode']?.toString() ??
          data['code']?.toString();
    }

    return data?.toString();
  }

  // =========================================
  // ACCOUNT GROUPS
  // =========================================
  Future<List<Map<String, dynamic>>> fetchAccountGroups() async {
    final response = await _api.get('ledgers/groups');

    if (response.statusCode != 200) {
      throw Exception('Failed to load account groups');
    }

    final data = jsonDecode(response.body);

    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return [];
  }

  // =========================================
  // LEDGERS
  // =========================================
  Future<List<Map<String, dynamic>>> fetchLedgers() async {
    final response = await _api.get('ledgers');

    if (response.statusCode != 200) {
      throw Exception('Failed to load ledgers');
    }

    final data = jsonDecode(response.body);

    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return [];
  }
}