import 'dart:convert';

import '../../core/network/api_service.dart';

class SalesService {
  SalesService({
    ApiService? apiService,
  }) : _api = apiService ?? ApiService();

  final ApiService _api;

  // ============================================================
  // GET SALES
  // ============================================================

  Future<Map<String, dynamic>> fetchSales({
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
      'sales',
      queryParameters: queryParameters,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load sales records',
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
  // GET SALE DETAILS
  // ============================================================

  Future<Map<String, dynamic>> fetchSalesDetails(
    String voucherId,
  ) async {
    final response = await _api.get(
      'sales/details',
      queryParameters: {
        'voucherId': voucherId,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load sales details',
      );
    }

    final data = jsonDecode(response.body);

    if (data is Map<String, dynamic>) {
      return data;
    }

    return {};
  }

  // ============================================================
  // NEXT INVOICE NUMBER
  // ============================================================

  Future<String?> getNextInvoiceNumber() async {
    final response = await _api.get(
      'sales/next-invoice',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to get next invoice number',
      );
    }

    final data = jsonDecode(response.body);

    if (data is Map) {
      return data['invoiceNumber']?.toString() ??
          data['voucherNo']?.toString() ??
          data['voucherId']?.toString();
    }

    return data?.toString();
  }

  // ============================================================
  // TERM MASTERS
  // ============================================================

  Future<Map<String, dynamic>> fetchTermMasters() async {
    final response = await _api.get(
      'sales/term-masters',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load sales term masters',
      );
    }

    final data = jsonDecode(response.body);

    if (data is Map<String, dynamic>) {
      return data;
    }

    return {};
  }

  // ============================================================
  // SUBMIT SALE
  // ============================================================

  Future<Map<String, dynamic>> submitSale(
    Map<String, dynamic> saleData,
  ) async {
    final response = await _api.post(
      'sales/submit',
      body: saleData,
    );

    final data = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : <String, dynamic>{};

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        data is Map && data['message'] != null
            ? data['message'].toString()
            : 'Failed to submit sale',
      );
    }

    if (data is Map<String, dynamic>) {
      return data;
    }

    return {};
  }
}