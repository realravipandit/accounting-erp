import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sas_akount_login/utils/config.dart';

class ApiService {
  final _storage = const FlutterSecureStorage();
  final _headers = {'Content-Type': 'application/json'};

  Future<Map<String, String>> _authHeaders() async {
    final t = await _storage.read(key: 'jwt_token');
    final companyId = await _storage.read(key: 'selected_company_id');
    final companyCode = await _storage.read(key: 'selected_company_code');
    
    return {
      ..._headers, 
      if (t != null) 'Authorization': 'Bearer $t', 
      if (companyId != null) 'company-id': companyId,
      if (companyCode != null) 'x-company-code': companyCode,
    };
  }

  /// Generic fetch helper for endpoints returning a List
  Future<List<Map<String, dynamic>>> _fetch(String ep) async {
    final res = await http.get(Uri.parse('${Config.baseUrl}/api/$ep'), headers: await _authHeaders());
    if (res.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    throw Exception(res.statusCode == 401 ? 'Authentication required' : 'Failed to load $ep');
  }

  // --- Authentication & Companies ---
  Future<bool> login(String u, String p) async {
    final res = await http.post(
      Uri.parse('${Config.baseUrl}/api/login'), 
      body: jsonEncode({'username': u, 'password': p}), 
      headers: _headers,
    );
    if (res.statusCode != 200) return false;
    final token = jsonDecode(res.body)['accessToken'] ?? jsonDecode(res.body)['token'];
    if (token == null) return false;
    await _storage.write(key: 'jwt_token', value: token);
    return true;
  }

  Future<List<dynamic>> getCompanies() async {
    final t = await _storage.read(key: 'jwt_token');
    if (t == null) throw Exception("Authentication error: No token found.");
    final res = await http.get(
      Uri.parse('${Config.baseUrl}/api/companies'), 
      headers: {..._headers, 'Authorization': 'Bearer $t'},
    );
    return res.statusCode == 200 ? jsonDecode(res.body) : throw Exception('Failed to load companies');
  }

  // --- Dashboard & Reports (RESTORED) ---
  // --- Dashboard & Reports (RESTORED & BULLETPROOFED) ---
  Future<Map<String, dynamic>> fetchDashboardSummary({String? period, DateTime? startDate, DateTime? endDate}) async {
    try {
      String query = '';
      
      // 1. Safely encode the period (fixes spaces like "Last 24 Hours")
      if (period != null && period.isNotEmpty) {
        query = '?period=${Uri.encodeComponent(period)}';
      }
      
      // 2. Format dates cleanly for SQL (YYYY-MM-DD) instead of ISO string
      if (startDate != null && endDate != null) {
        final startStr = "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
        final endStr = "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
        
        query += '${query.isEmpty ? '?' : '&'}startDate=$startStr&endDate=$endStr';
      }

      final url = '${Config.baseUrl}/api/dashboard$query';
      debugPrint('Fetching Dashboard from: $url');

      final res = await http.get(Uri.parse(url), headers: await _authHeaders());

      // Let's print exactly what the server returns to catch any hidden SQL errors
      debugPrint('Dashboard Status: ${res.statusCode}');
      debugPrint('Dashboard Body: ${res.body}');

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);

        // 3. Safely handle if the Node.js backend returned a List instead of a Map
        if (decoded is List) {
          if (decoded.isNotEmpty) {
            return decoded.first as Map<String, dynamic>;
          } else {
            return {}; // Server returned empty array
          }
        }
        
        // If it's already a map, return it directly
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
      
      return {}; // Fallback for bad status code
    } catch (e) {
      debugPrint('CRITICAL Error fetching dashboard: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> fetchReceivables() => _fetch('receivables');
  Future<List<Map<String, dynamic>>> fetchPayables() => _fetch('payables');
  Future<List<Map<String, dynamic>>> fetchAgeing() => _fetch('ageing');

  // --- Item Master API Methods (RESTORED) ---
  Future<List<Map<String, dynamic>>> getItems() => _fetch('items');
  Future<List<Map<String, dynamic>>> getItemGroups() => _fetch('items/groups');
  
  Future<List<Map<String, dynamic>>> getItemSubGroups(int groupId) async {
    try {
      final res = await http.get(Uri.parse('${Config.baseUrl}/api/items/subgroups/$groupId'), headers: await _authHeaders());
      if (res.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUnits() async {
    try {
      final res = await http.get(Uri.parse('${Config.baseUrl}/api/items/units'), headers: await _authHeaders());
      if (res.statusCode == 200) {
        List data = jsonDecode(res.body);
        return data.map((item) => {
          'unitId': item['UnitID'],
          'unitCode': item['UnitCode'].toString().trim(),
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<String> getNextItemCode(String prefix) async {
    try {
      final res = await http.get(Uri.parse('${Config.baseUrl}/api/items/next-code?prefix=$prefix'), headers: await _authHeaders());
      if (res.statusCode == 200) return jsonDecode(res.body)['nextCode'] ?? '';
      throw Exception('Failed to fetch item code');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<bool> createItem(Map<String, dynamic> itemData) async {
    try {
      final Map<String, dynamic> updatedData = Map.from(itemData);
      updatedData['valuationMethod'] = 'FIFO';
      updatedData['valuationFlag'] = 'F';

      if (updatedData.containsKey('altQty')) updatedData['ConversionRatio'] = updatedData['altQty'];
      if (updatedData.containsKey('qty')) updatedData['Factor'] = updatedData['qty'];

      final res = await http.post(
        Uri.parse('${Config.baseUrl}/api/items'),
        headers: await _authHeaders(),
        body: jsonEncode(updatedData),
      );
      if (res.statusCode == 200 || res.statusCode == 201) return true;
      throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to create item');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // --- Ledger Master API Methods (RESTORED) ---
  Future<bool> checkLedgerNameExists(String name) async {
    try {
      final res = await http.get(Uri.parse('${Config.baseUrl}/api/ledgers/check-name?name=$name'), headers: await _authHeaders());
      if (res.statusCode == 200) return jsonDecode(res.body)['exists'] ?? false;
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> createLedger(Map<String, dynamic> ledgerData) async {
    try {
      final res = await http.post(
        Uri.parse('${Config.baseUrl}/api/ledgers'),
        headers: await _authHeaders(),
        body: jsonEncode(ledgerData),
      );
      if (res.statusCode == 200 || res.statusCode == 201) return true;
      throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to create ledger');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<String?> fetchNextLedgerCode(String prefix) async {
    try {
      final response = await http.get(Uri.parse('${Config.baseUrl}/api/ledgers/next-code?prefix=$prefix'), headers: await _authHeaders());
      if (response.statusCode == 200) return jsonDecode(response.body)['nextCode'];
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAccountGroups() => _fetch('ledgers/groups');
  Future<List<Map<String, dynamic>>> fetchLedgers() => _fetch('ledgers');

  // --- NEW: BULLETPROOF SALES SUBMIT METHOD ---
  Future<Map<String, dynamic>> submitSale(Map<String, dynamic> payload) async {
    try {
      debugPrint('Submitting Sale Payload: ${jsonEncode(payload)}');
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/api/sales'),
        headers: await _authHeaders(),
        body: jsonEncode(payload),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return {
          'success': true,
          'voucherId': responseData['voucherId'],
          'netAmount': responseData['netAmount'],
          'message': 'Sale saved successfully!'
        };
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? 'Unknown error occurred on server.'
        };
      }
    } catch (e) {
      debugPrint('Submit Sale Error: $e');
      return {
        'success': false,
        'message': 'Failed to connect to the server. Check your network.'
      };
    }
  }

  // --- Utility Lookups ---
  Future<String> getNextInvoiceNumber() async {
    try {
      final res = await http.get(Uri.parse('${Config.baseUrl}/api/sales/next-voucher'), headers: await _authHeaders());
      if (res.statusCode == 200) return jsonDecode(res.body)['voucherId'] ?? '';
      return 'Error';
    } catch (e) {
      return 'Error';
    }
  }

  /// Fetches active term masters from tblSITermMaster
  Future<List<Map<String, dynamic>>> fetchTermMasters() async {
    try {
      final res = await http.get(
        Uri.parse('${Config.baseUrl}/api/sales/term-masters'),
        headers: await _authHeaders(),
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  // ===========================================================================
  // PURCHASE ENTRY API METHODS
  // ===========================================================================

  /// 1. Fetch Next Purchase Voucher Number
  Future<String> getNextPurchaseVoucher() async {
    try {
      final res = await http.get(
        Uri.parse('${Config.baseUrl}/api/purchase/next-voucher'),
        headers: await _authHeaders(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          return data['voucherNo'].toString();
        }
      }
      throw Exception('Failed to fetch purchase voucher no');
    } catch (e) {
      debugPrint('getNextPurchaseVoucher error: $e');
      rethrow;
    }
  }

  /// 2. Fetch Vendors Only (LedgerType 'VE' or 'BO')
  Future<List<Map<String, dynamic>>> getPurchaseVendors() async {
    try {
      final res = await http.get(
        Uri.parse('${Config.baseUrl}/api/purchase/vendors'),
        headers: await _authHeaders(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('getPurchaseVendors error: $e');
      return [];
    }
  }

  /// Fetch Purchase Term Masters (tblPITermMaster)
  /// Fetch Purchase Term Masters (tblPITermMaster)
  Future<List<dynamic>> fetchPurchaseTermMasters() async {
    try {
      debugPrint('🌍 HITTING API: ${Config.baseUrl}/api/purchase/term-masters');
      
      final res = await http.get(
        Uri.parse('${Config.baseUrl}/api/purchase/term-masters'),
        headers: await _authHeaders(),
      );
      
      // 🚨 AGGRESSIVE NETWORK LOGS 🚨
      debugPrint('✅ API RESPONSE CODE: ${res.statusCode}');
      debugPrint('📦 API RESPONSE BODY: ${res.body}');
      
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        
        // Handle case where it might be wrapped in an object like { data: [...] }
        if (decoded is List) return decoded;
        if (decoded is Map && decoded['data'] != null) return decoded['data'];
        
        return [];
      } else {
        debugPrint('❌ API FAILED WITH CODE: ${res.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('🚨 CATCH ERROR: $e');
      return [];
    }
  }

  /// 3. Submit Purchase Entry
  Future<Map<String, dynamic>> submitPurchase(Map<String, dynamic> payload) async {
    try {
      final res = await http.post(
        Uri.parse('${Config.baseUrl}/api/purchase/submit'),
        headers: await _authHeaders(),
        body: jsonEncode(payload),
      );
      
      final data = jsonDecode(res.body);
      
      if (res.statusCode == 200) {
        return data; // Returns the { success: true, voucherId: ... } object
      } else {
        return {
          'success': false, 
          'message': data['error'] ?? data['message'] ?? 'Failed to submit purchase.'
        };
      }
    } catch (e) {
      debugPrint('submitPurchase error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 1. Fetch available document sequences for a module (e.g., 'CB')
  Future<List<Map<String, dynamic>>> fetchVoucherSequences(String module) async {
    try {
      final res = await http.get(
        Uri.parse('${Config.baseUrl}/api/vouchers/sequences?module=$module'),
        headers: await _authHeaders(),
      );
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (_) {}
    return [];
  }

  /// 2. Fetch Cash or Bank ledger accounts for the header selector
  Future<List<Map<String, dynamic>>> getCashBankAccounts() async {
    try {
      final res = await http.get(
        Uri.parse('${Config.baseUrl}/api/ledgers/cash-banks'),
        headers: await _authHeaders(),
      );
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (_) {}
    return [];
  }

  /// 3. Submit the completed Cash/Bank Voucher payload
  Future<Map<String, dynamic>> submitCashBankVoucher(Map<String, dynamic> payload) async {
    try {
      final res = await http.post(
        Uri.parse('${Config.baseUrl}/api/cash-bank/submit'),
        headers: await _authHeaders(),
        body: jsonEncode(payload),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 201 || res.statusCode == 200) {
        return {'success': true, ...data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Failed to save voucher.'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getCashBankLedgers() async {
    try {
      final res = await http.get(
        Uri.parse('${Config.baseUrl}/api/ledgers/cash-banks'),
        headers: await _authHeaders(),
      );
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getVoucherLedgers() async {
    try {
      final res = await http.get(
        Uri.parse('${Config.baseUrl}/api/ledgers/voucher-ledgers'),
        headers: await _authHeaders(),
      );
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint("Error fetching voucher ledgers: $e");
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchSales() => _fetch('sales');
  Future<List<Map<String, dynamic>>> fetchSalesDetails(String s, String e) => _fetch('sales/details?startDate=$s&endDate=$e');
  Future<List<Map<String, dynamic>>> fetchPurchases() => _fetch('purchase');
  Future<List<Map<String, dynamic>>> fetchPurchaseDetails() => _fetch('purchase/details');
  Future<List<Map<String, dynamic>>> fetchOutstanding() => _fetch('outstanding');
  Future<List<Map<String, dynamic>>> fetchInventory() => _fetch('inventory');
}