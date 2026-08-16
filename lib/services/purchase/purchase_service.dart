import 'dart:convert';
import 'package:sas_akount_login/core/network/api_service.dart';
import 'package:sas_akount_login/models/common/record_query.dart';

class PurchaseService {
  PurchaseService({
    ApiService? apiService,
  }) : _api = apiService ?? ApiService();

  final ApiService _api;

  // ============================================================
  // GET PURCHASE RECORDS
  // ============================================================

  Future<Map<String, dynamic>> fetchPurchases([RecordQuery? query]) async {
    // Safety check so background sync doesn't crash if query is null
    query ??= RecordQuery();

    final response = await _api.get(
      'purchase',
      queryParameters: query.toQueryParameters(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load purchase records');
    }

    final data = jsonDecode(response.body);

    // Scenario 1: New Backend Format { "data": [...], "meta": {...} }
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      return data; 
    }

    // Scenario 2: Old Backend Format { "records": [...], "pagination": {...} }
    if (data is Map<String, dynamic> && data.containsKey('records')) {
      return {
        'data': data['records'] ?? [],
        'meta': data['pagination'] ?? data['meta'] ?? {
          'page': query.page,
          'limit': query.limit,
          'totalPages': 1,
        },
      };
    }

    // Scenario 3: Raw List [...]
    return {
      'data': data is List ? data : [],
      'meta': {
        'page': query.page,
        'limit': query.limit,
        'totalPages': 1,
      },
    };
  }

  // ============================================================
  // GET PURCHASE DETAILS
  // ============================================================

  Future<Map<String, dynamic>> fetchPurchaseDetails(String voucherId) async {
    final response = await _api.get(
      'purchase/details',
      queryParameters: {'voucherId': voucherId},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load purchase details');
    }

    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) {
      return data;
    }
    return {};
  }

  // ============================================================
  // GET PURCHASE VENDORS
  // ============================================================

  Future<List<Map<String, dynamic>>> getPurchaseVendors() async {
    final response = await _api.get('purchase/vendors');

    if (response.statusCode != 200) {
      throw Exception('Failed to load purchase vendors');
    }

    final data = jsonDecode(response.body);

    if (data is List) {
      return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }

    if (data is Map && data['data'] is List) {
      return (data['data'] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }

    return [];
  }

  // ============================================================
  // GET NEXT PURCHASE VOUCHER
  // ============================================================

  Future<String> getNextPurchaseVoucher() async {
    final response = await _api.get('purchase/next-voucher');

    if (response.statusCode != 200) {
      throw Exception('Failed to get next purchase voucher');
    }

    final data = jsonDecode(response.body);

    if (data is Map) {
      return data['voucherNo']?.toString() ?? data['voucherId']?.toString() ?? '';
    }

    return data?.toString() ?? '';
  }

  // ============================================================
  // GET PURCHASE TERM MASTERS
  // ============================================================

  Future<List<dynamic>> fetchPurchaseTermMasters() async {
    final response = await _api.get('purchase/term-masters');

    if (response.statusCode != 200) {
      throw Exception('Failed to load purchase term masters');
    }

    final data = jsonDecode(response.body);

    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'];

    return [];
  }

  // ============================================================
  // SUBMIT PURCHASE
  // ============================================================

  Future<Map<String, dynamic>> submitPurchase(Map<String, dynamic> purchaseData) async {
    final response = await _api.post(
      'purchase/submit',
      body: purchaseData,
    );

    final data = response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data is Map && data['message'] != null
            ? data['message'].toString()
            : data is Map && data['error'] != null
                ? data['error'].toString()
                : 'Failed to submit purchase',
      );
    }

    if (data is Map<String, dynamic>) {
      return data;
    }

    return {};
  }
}