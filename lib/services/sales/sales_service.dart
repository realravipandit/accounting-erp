import 'dart:convert';

import '../../core/network/api_service.dart';
import 'package:sas_akount_login/models/common/record_query.dart'; // Make sure this path is correct for your project!

class SalesService {
  SalesService({
    ApiService? apiService,
  }) : _api = apiService ?? ApiService();

  final ApiService _api;

  // ============================================================
  // GET SALES RECORDS (Updated to use RecordQuery)
  // ============================================================

  Future<Map<String, dynamic>> fetchSales(RecordQuery query) async {
    // Convert the RecordQuery object into HTTP parameters
    final queryParameters = <String, dynamic>{
      'page': query.page.toString(),
      'limit': query.limit.toString(),
      'sortField': query.sortField,
      'sortOrder': query.sortOrder,
    };

    if (query.search != null && query.search!.isNotEmpty) {
      queryParameters['search'] = query.search;
    }
    
    // Safely format DateTime objects into strings for the backend
    if (query.startDate != null) {
      queryParameters['startDate'] = query.startDate!.toIso8601String();
    }
    if (query.endDate != null) {
      queryParameters['endDate'] = query.endDate!.toIso8601String();
    }
    
    // Merge any extra filters you might add later
    if (query.extraFilters.isNotEmpty) {
      queryParameters.addAll(query.extraFilters);
    }

    final response = await _api.get(
      'sales',
      queryParameters: queryParameters,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load sales records');
    }

    final data = jsonDecode(response.body);

    if (data is Map<String, dynamic>) {
      return data;
    }

    // Fallback normalization just in case
    return {
      'records': data is List ? data : [],
      'pagination': {
        'page': query.page,
        'limit': query.limit,
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
      throw Exception('Failed to load sales details');
    }

    final data = jsonDecode(response.body);

    if (data is Map<String, dynamic>) {
      return data;
    }

    return {};
  }

  // ============================================================
  // NEXT INVOICE / VOUCHER NUMBER
  // Original working endpoint: /api/sales/next-voucher
  // ============================================================

  Future<String> getNextInvoiceNumber() async {
    final response = await _api.get(
      'sales/next-voucher',
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get next invoice number');
    }

    final data = jsonDecode(response.body);

    if (data is Map) {
      return data['voucherId']?.toString() ??
          data['invoiceNumber']?.toString() ??
          data['voucherNo']?.toString() ??
          '';
    }

    return data?.toString() ?? '';
  }

  // ============================================================
  // TERM MASTERS
  // ============================================================

  Future<List<Map<String, dynamic>>> fetchTermMasters() async {
    final response = await _api.get(
      'sales/term-masters',
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load sales term masters');
    }

    final data = jsonDecode(response.body);

    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return [];
  }

  // ============================================================
  // LEDGERS
  // Used by Sale Entry for customer and cash/bank lookups.
  // ============================================================

  Future<List<Map<String, dynamic>>> fetchLedgers() async {
    final response = await _api.get(
      'ledgers',
    );

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

    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return [];
  }

  // ============================================================
  // ITEMS
  // Used by ItemSearchScreen inside Sale Entry.
  // ============================================================

  Future<List<Map<String, dynamic>>> getItems() async {
    final response = await _api.get(
      'items',
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load items');
    }

    final data = jsonDecode(response.body);

    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return [];
  }

  // ============================================================
  // SUBMIT SALE
  // Original working endpoint: /api/sales
  // ============================================================

  Future<Map<String, dynamic>> submitSale(
    Map<String, dynamic> saleData,
  ) async {
    final response = await _api.post(
      'sales',
      body: saleData,
    );

    final data = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : <String, dynamic>{};

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        data is Map && data['error'] != null
            ? data['error'].toString()
            : data is Map && data['message'] != null
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