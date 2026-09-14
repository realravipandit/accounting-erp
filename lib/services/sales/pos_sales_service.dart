import 'dart:convert';
import '../../core/network/api_service.dart';

class PosSalesService {
  PosSalesService({
    ApiService? apiService,
  }) : _api = apiService ?? ApiService();

  final ApiService _api;

  // 1. Fetch next Counter Sales ('CS') voucher number
  Future<String> getNextPosInvoiceNumber() async {
    final response = await _api.get('sales/pos/next-voucher');
    if (response.statusCode != 200) {
      throw Exception('Failed to get next POS invoice number');
    }
    final data = jsonDecode(response.body);
    if (data is Map) {
      return data['voucherId']?.toString() ?? 
             data['invoiceNumber']?.toString() ?? 
             data['voucherNo']?.toString() ?? 
             'CS-0001';
    }
    return 'CS-0001';
  }

  // 2. Fetch Live Counters / Classes (tblClass)
  Future<List<Map<String, dynamic>>> fetchClasses() async {
    try {
      final response = await _api.get('sales/pos/classes'); 
      if (response.statusCode != 200) return [];
      
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      if (data is Map && data['data'] is List) {
        return (data['data'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // 3. Fetch Term Masters for POS
  Future<List<Map<String, dynamic>>> fetchTermMasters() async {
    final response = await _api.get('sales/term-masters');
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body);
    if (data is List) {
      return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return [];
  }

  // 4. Fetch Inventory Items
  Future<List<Map<String, dynamic>>> getItems() async {
    final response = await _api.get('items');
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body);
    if (data is List) {
      return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return [];
  }

  // 5. Fetch Ledgers (Customers / Banks)
  Future<List<Map<String, dynamic>>> fetchLedgers() async {
    final response = await _api.get('ledgers');
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body);
    if (data is List) {
      return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return [];
  }

  // 6. Submit POS Sale Payload
  Future<Map<String, dynamic>> submitPosSale(Map<String, dynamic> payload) async {
    final response = await _api.post(
      'sales/pos',
      body: payload,
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
                : 'Failed to submit POS sale',
      );
    }

    if (data is Map<String, dynamic>) {
      return data;
    }
    return {};
  }

  // 7. NEW: Fetch Active Company Profile for PDF Generation
  Future<Map<String, dynamic>> fetchActiveCompanyProfile() async {
    try {
      // NOTE: Ensure this matches your Node.js route path (e.g., 'company/profile')
      final response = await _api.get('company/profile'); 
      if (response.statusCode != 200) return {};
      
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data; 
      }
      return {};
    } catch (_) {
      return {};
    }
  }
}