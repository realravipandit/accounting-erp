import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/network/api_service.dart';
import 'package:sas_app/models/sales/sales_order_model.dart';


// ============================================================================
// SALES ORDER SERVICE
//
// Mirrors DashboardService's pattern exactly: ApiService injected/defaulted,
// try/catch around each call, debugPrint on status + errors, safe empty
// fallback on failure rather than throwing.
// ============================================================================

class SalesOrderService {
  SalesOrderService({
    ApiService? apiService,
  }) : _api = apiService ?? ApiService();

  final ApiService _api;

  Future<List<SalesOrder>> fetchSalesOrders({
    int page = 1,
    int pageSize = 50,
    String? search,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      };
      if (search != null && search.isNotEmpty) {
        queryParameters['search'] = search;
      }

      final response = await _api.get(
        'sales-order',
        queryParameters: queryParameters,
      );

      debugPrint(
        'Sales Orders Status: ${response.statusCode}',
      );

      if (response.statusCode != 200) {
        return [];
      }

      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic> && decoded['orders'] is List) {
        return (decoded['orders'] as List)
            .map((e) => SalesOrder.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }

      return [];
    } catch (e) {
      debugPrint(
        'Sales Orders Error: $e',
      );
      return [];
    }
  }

  Future<SalesOrderDetail?> fetchSalesOrderDetail(String orderNumber) async {
    try {
      final response = await _api.get('sales-order/$orderNumber');

      debugPrint(
        'Sales Order Detail Status: ${response.statusCode}',
      );

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic> && decoded['order'] is Map) {
        return SalesOrderDetail.fromJson(decoded);
      }

      return null;
    } catch (e) {
      debugPrint(
        'Sales Order Detail Error: $e',
      );
      return null;
    }
  }
}