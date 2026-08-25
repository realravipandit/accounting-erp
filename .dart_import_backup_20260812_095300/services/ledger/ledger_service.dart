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
      'ledger/check-name',
      queryParameters: {
        'ledgerName': ledgerName,
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
      'ledger',
      body: ledgerData,
    );

    final data = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : <String, dynamic>{};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data is Map && data['message'] != null
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
  Future<String?> fetchNextLedgerCode() async {
    final response = await _api.get('ledger/next-code');

    if (response.statusCode != 200) {
      throw Exception('Failed to get next ledger code');
    }

    final data = jsonDecode(response.body);

    if (data is Map) {
      return data['ledgerCode']?.toString() ?? data['code']?.toString();
    }

    return data?.toString();
  }

  // =========================================
  // ACCOUNT GROUPS
  // =========================================
  Future<List<dynamic>> fetchAccountGroups() async {
    final response = await _api.get('ledger/account-groups');

    if (response.statusCode != 200) {
      throw Exception('Failed to load account groups');
    }

    final data = jsonDecode(response.body);

    if (data is List) {
      return data;
    }

    return [];
  }

  // =========================================
  // LEDGERS
  // =========================================
  Future<List<dynamic>> fetchLedgers() async {
    final response = await _api.get('ledger');

    if (response.statusCode != 200) {
      throw Exception('Failed to load ledgers');
    }

    final data = jsonDecode(response.body);

    if (data is List) {
      return data;
    }

    return [];
  }
}