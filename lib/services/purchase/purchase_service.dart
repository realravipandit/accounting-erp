import 'dart:convert';
import 'package:sas_akount_login/core/network/api_service.dart';
import 'package:sas_akount_login/models/common/record_query.dart';

class PurchaseService {
  PurchaseService({
    ApiService? apiService,
  }) : _api = apiService ?? ApiService();

  final ApiService _api;

  // ============================================================
  // GET PURCHASE RECORDS (PAGINATED & FILTERED)
  // ============================================================
  Future<Map<String, dynamic>> fetchPurchases([RecordQuery? query]) async {
    query ??= RecordQuery();

    // Ensure query parameters map cleanly to string key-values
    final Map<String, dynamic> rawParams = query.toQueryParameters();
    final Map<String, String> queryParams = rawParams.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    )..removeWhere((key, value) => value.isEmpty);

    final response = await _api.get(
      'purchase',
      queryParameters: queryParams,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load purchase records (Status: ${response.statusCode})');
    }

    final dynamic data = jsonDecode(response.body);

    // Format 1: Standard API Response { "data": [...], "meta": {...} }
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      return {
        'data': (data['data'] as List? ?? []),
        'meta': data['meta'] ?? {
          'page': query.page,
          'limit': query.limit,
          'totalPages': 1,
        },
      };
    }

    // Format 2: Legacy API Response { "records": [...], "pagination": {...} }
    if (data is Map<String, dynamic> && data.containsKey('records')) {
      return {
        'data': (data['records'] as List? ?? []),
        'meta': data['pagination'] ?? data['meta'] ?? {
          'page': query.page,
          'limit': query.limit,
          'totalPages': 1,
        },
      };
    }

    // Format 3: Raw Array Response [...]
    if (data is List) {
      return {
        'data': data,
        'meta': {
          'page': query.page,
          'limit': query.limit,
          'totalPages': 1,
        },
      };
    }

    return {'data': [], 'meta': {'page': 1, 'limit': 25, 'totalPages': 1}};
  }

  // ============================================================
  // GET PURCHASE DETAILS (BY VOUCHER ID)
  // ============================================================
  Future<Map<String, dynamic>> fetchPurchaseDetails(String voucherId) async {
    final response = await _api.get(
      'purchase/details',
      queryParameters: {'voucherId': voucherId},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load purchase details (Status: ${response.statusCode})');
    }

    final dynamic data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) {
      return data.containsKey('data') && data['data'] is Map<String, dynamic>
          ? data['data']
          : data;
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

    final dynamic data = jsonDecode(response.body);

    if (data is List) {
      return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return [];
  }

  // ============================================================
  // GET NEXT PURCHASE VOUCHER NUMBER
  // ============================================================
  Future<String> getNextPurchaseVoucher() async {
    final response = await _api.get('purchase/next-voucher');

    if (response.statusCode != 200) {
      throw Exception('Failed to get next purchase voucher');
    }

    final dynamic data = jsonDecode(response.body);

    if (data is Map) {
      return data['voucherNo']?.toString() ??
             data['voucherId']?.toString() ??
             data['nextVoucher']?.toString() ??
             '';
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

    final dynamic data = jsonDecode(response.body);
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'];
    return [];
  }

  // ============================================================
  // SUBMIT PURCHASE VOUCHER
  // ============================================================
  Future<Map<String, dynamic>> submitPurchase(Map<String, dynamic> purchaseData) async {
    final response = await _api.post(
      'purchase/submit',
      body: purchaseData,
    );

    final dynamic data = response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorMessage = (data is Map)
          ? (data['message'] ?? data['error'] ?? 'Failed to submit purchase')
          : 'Failed to submit purchase';
      throw Exception(errorMessage.toString());
    }

    if (data is Map<String, dynamic>) {
      return data;
    }
    return {};
  }
}