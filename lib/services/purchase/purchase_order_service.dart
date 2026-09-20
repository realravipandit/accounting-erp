import 'dart:convert';

import 'package:sas_app/core/network/api_service.dart';

class PurchaseOrderService {
  PurchaseOrderService({
    ApiService? apiService,
  }) : _api = apiService ?? ApiService();

  final ApiService _api;

  // ============================================================
  // NEXT PURCHASE ORDER NUMBER
  // Endpoint: /api/purchase-order/next-voucher
  // ============================================================
  Future<String> getNextPurchaseOrderNumber() async {
    final response = await _api.get('purchase-order/next-voucher');

    if (response.statusCode != 200) {
      throw Exception('Failed to get next purchase order number');
    }

    final data = jsonDecode(response.body);

    if (data is Map) {
      return data['voucherId']?.toString() ??
          data['orderNumber']?.toString() ??
          data['voucherNo']?.toString() ??
          '';
    }

    return data?.toString() ?? '';
  }

  // ============================================================
  // TERM MASTERS (pitermmaster)
  // Endpoint: /api/purchase-order/term-masters
  // ============================================================
  Future<List<Map<String, dynamic>>> fetchTermMasters() async {
    final response = await _api.get('purchase-order/term-masters');

    if (response.statusCode != 200) {
      throw Exception('Failed to load purchase order term masters');
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
  // VENDORS
  // Endpoint: /api/purchase-order/vendors
  // Used by Purchase Order Entry for vendor lookup. Distinct from
  // PurchaseService.getPurchaseVendors() (purchase/vendors, for the
  // purchase-invoice flow) --- kept separate on purpose.
  // ============================================================
  Future<List<Map<String, dynamic>>> fetchVendors() async {
    final response = await _api.get('purchase-order/vendors');

    if (response.statusCode != 200) {
      throw Exception('Failed to load vendors');
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
  // SUBMIT PURCHASE ORDER
  // Endpoint: /api/purchase-order/create
  // ============================================================
  Future<Map<String, dynamic>> submitPurchaseOrder(
    Map<String, dynamic> payload,
  ) async {
    final response = await _api.post(
      'purchase-order/create',
      body: payload,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to save purchase order. HTTP Status: ${response.statusCode}',
      );
    }
  }

  // ============================================================
  // GET PURCHASE ORDERS (LIST)
  // Endpoint: /api/purchase-order
  // ============================================================
  Future<Map<String, dynamic>> fetchPurchaseOrders({
    int page = 1,
    int pageSize = 50,
    String? search,
  }) async {
    final queryParameters = <String, dynamic>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };

    if (search != null && search.isNotEmpty) {
      queryParameters['search'] = search;
    }

    final response = await _api.get(
      'purchase-order',
      queryParameters: queryParameters,
    );

    if (response.statusCode != 200) {
      print('PURCHASE ORDERS FETCH FAILED: status=${response.statusCode} body=${response.body}');
      throw Exception('Failed to load purchase orders');
    }

    final data = jsonDecode(response.body);

    if (data is Map<String, dynamic>) {
      return data;
    }

    return {
      'orders': data is List ? data : [],
      'page': page,
      'pageSize': pageSize,
    };
  }

  // ============================================================
  // GET PURCHASE ORDER BY ID (DETAIL)
  // Endpoint: /api/purchase-order/:orderId
  // ============================================================
  Future<Map<String, dynamic>> fetchPurchaseOrderById(String orderId) async {
    final response = await _api.get('purchase-order/$orderId');

    if (response.statusCode != 200) {
      print('PURCHASE ORDER DETAILS FETCH FAILED: status=${response.statusCode} body=${response.body}');
      throw Exception('Failed to load purchase order details');
    }

    final data = jsonDecode(response.body);

    if (data is Map<String, dynamic>) {
      return data;
    }

    return {};
  }
}