import 'dart:convert';

import '../../core/network/api_service.dart';

class BankingService {
  BankingService({
    ApiService? apiService,
  }) : _api = apiService ?? ApiService();

  final ApiService _api;

  // ============================================================
  // GET VOUCHER SEQUENCES
  // ============================================================

  Future<List<dynamic>> fetchVoucherSequences() async {
    final response = await _api.get(
      'cash-bank/voucher-sequences',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load voucher sequences',
      );
    }

    final data = jsonDecode(response.body);

    if (data is List) {
      return data;
    }

    if (data is Map && data['data'] is List) {
      return data['data'];
    }

    return [];
  }

  // ============================================================
  // GET CASH / BANK ACCOUNTS
  // ============================================================

  Future<List<dynamic>> getCashBankAccounts() async {
    final response = await _api.get(
      'cash-bank/accounts',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load cash/bank accounts',
      );
    }

    final data = jsonDecode(response.body);

    if (data is List) {
      return data;
    }

    if (data is Map && data['data'] is List) {
      return data['data'];
    }

    return [];
  }

  // ============================================================
  // GET CASH / BANK LEDGERS
  // ============================================================

  Future<List<dynamic>> getCashBankLedgers() async {
    final response = await _api.get(
      'cash-bank/ledgers',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load cash/bank ledgers',
      );
    }

    final data = jsonDecode(response.body);

    if (data is List) {
      return data;
    }

    if (data is Map && data['data'] is List) {
      return data['data'];
    }

    return [];
  }

  // ============================================================
  // GET VOUCHER LEDGERS
  // ============================================================

  Future<List<dynamic>> getVoucherLedgers() async {
    final response = await _api.get(
      'cash-bank/voucher-ledgers',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load voucher ledgers',
      );
    }

    final data = jsonDecode(response.body);

    if (data is List) {
      return data;
    }

    if (data is Map && data['data'] is List) {
      return data['data'];
    }

    return [];
  }

  // ============================================================
  // SUBMIT CASH / BANK VOUCHER
  // ============================================================

  Future<Map<String, dynamic>> submitCashBankVoucher(
    Map<String, dynamic> voucherData,
  ) async {
    final response = await _api.post(
      'cash-bank/submit',
      body: voucherData,
    );

    final data = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : <String, dynamic>{};

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        data is Map && data['message'] != null
            ? data['message'].toString()
            : 'Failed to submit cash/bank voucher',
      );
    }

    if (data is Map<String, dynamic>) {
      return data;
    }

    return {};
  }
}