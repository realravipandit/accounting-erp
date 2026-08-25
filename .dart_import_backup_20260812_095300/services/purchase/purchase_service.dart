import 'dart:convert';

import '../../core/network/api_service.dart';

class PurchaseService {
  PurchaseService({
    ApiService? apiService,
  }) : _api = apiService ?? ApiService();

  final ApiService _api;

  // ============================================================
  // GET PURCHASE RECORDS
  // ============================================================

  Future<Map<String, dynamic>> fetchPurchases({
    int page = 1,
    int limit = 25,
    String? period,
    String? startDate,
    String? endDate,
    String sortBy = 'date',
    String sortOrder = 'desc',
    String? search,
  }) async {
    final queryParameters = <String, dynamic>{
      'page': page,
      'limit': limit,
      'sortBy': sortBy,
      'sortOrder': sortOrder,
    };

    if (period != null && period.isNotEmpty) {
      queryParameters['period'] = period;
    }

    if (startDate != null && startDate.isNotEmpty) {
      queryParameters['startDate'] = startDate;
    }

    if (endDate != null && endDate.isNotEmpty) {
      queryParameters['endDate'] = endDate;
    }

    if (search != null && search.isNotEmpty) {
      queryParameters['search'] = search;
    }

    final response = await _api.get(
      'purchase',
      queryParameters: queryParameters,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load purchase records',
      );
    }

    final data = jsonDecode(response.body);

    if (data is Map<String, dynamic>) {
      return data;
    }

    return {
      'records': data is List ? data : [],
      'pagination': {
        'page': page,
        'limit': limit,
      },
    };
  }

  // ============================================================
  // GET PURCHASE DETAILS
  // ============================================================

  Future<Map<String, dynamic>> fetchPurchaseDetails(
    String voucherId,
  ) async {
    final response = await _api.get(
      'purchase/details',
      queryParameters: {
        'voucherId': voucherId,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load purchase details',
      );
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

  Future<List<dynamic>> getPurchaseVendors() async {
    final response = await _api.get(
      'purchase/vendors',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load purchase vendors',
      );
    }

    final data = jsonDecode(response.body);

    if (data is List) {
      return data;
    }

    // Supports APIs that return:
    // { "data": [...] }
    if (data is Map && data['data'] is List) {
      return data['data'];
    }

    return [];
  }

  // ============================================================
  // GET NEXT PURCHASE VOUCHER
  // ============================================================

  Future<String?> getNextPurchaseVoucher() async {
    final response = await _api.get(
      'purchase/next-voucher',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to get next purchase voucher',
      );
    }

    final data = jsonDecode(response.body);

    if (data is Map) {
      return data['voucherNo']?.toString() ??
          data['voucherId']?.toString();
    }

    return data?.toString();
  }

  // ============================================================
  // GET PURCHASE TERM MASTERS
  // ============================================================

  Future<Map<String, dynamic>> fetchPurchaseTermMasters() async {
    final response = await _api.get(
      'purchase/term-masters',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load purchase term masters',
      );
    }

    final data = jsonDecode(response.body);

    if (data is Map<String, dynamic>) {
      return data;
    }

    return {};
  }

  // ============================================================
  // SUBMIT PURCHASE
  // ============================================================

  Future<Map<String, dynamic>> submitPurchase(
    Map<String, dynamic> purchaseData,
  ) async {
    final response = await _api.post(
      'purchase/submit',
      body: purchaseData,
    );

    final data = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : <String, dynamic>{};

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        data is Map && data['message'] != null
            ? data['message'].toString()
            : 'Failed to submit purchase',
      );
    }

    if (data is Map<String, dynamic>) {
      return data;
    }

    return {};
  }
}