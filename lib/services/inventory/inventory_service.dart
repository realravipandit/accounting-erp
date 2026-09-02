import 'dart:convert';
import '../../core/network/api_service.dart';

class InventoryService {
  InventoryService({
    ApiService? apiService,
  }) : _api = apiService ?? ApiService();
  final ApiService _api;

  // =========================================
  // ITEMS
  // =========================================
  Future<List<dynamic>> getItems() async {
    final response = await _api.get('items');
    if (response.statusCode != 200) {
      throw Exception('Failed to load items');
    }
    final data = jsonDecode(response.body);
    if (data is List) {
      return data;
    }
    return [];
  }

  // =========================================
  // ITEM GROUPS
  // Backend route: GET /api/items/groups
  // =========================================
  Future<List<dynamic>> getItemGroups() async {
    final response = await _api.get('items/groups');
    if (response.statusCode != 200) {
      throw Exception('Failed to load item groups');
    }
    final data = jsonDecode(response.body);
    if (data is List) {
      return data;
    }
    return [];
  }

  // =========================================
  // ITEM SUB GROUPS
  // Backend route: GET /api/items/subgroups/:groupId
  // =========================================
  Future<List<dynamic>> getItemSubGroups(int groupId) async {
    final response = await _api.get('items/subgroups/$groupId');
    if (response.statusCode != 200) {
      throw Exception('Failed to load item sub groups');
    }
    final data = jsonDecode(response.body);
    if (data is List) {
      return data;
    }
    return [];
  }

  // =========================================
  // UNITS
  // Backend route: GET /api/items/units
  // =========================================
  Future<List<dynamic>> getUnits() async {
    final response = await _api.get('items/units');
    if (response.statusCode != 200) {
      throw Exception('Failed to load units');
    }
    final data = jsonDecode(response.body);
    if (data is List) {
      return data;
    }
    return [];
  }

  // =========================================
  // NEXT ITEM CODE
  // Backend route: GET /api/items/next-code?prefix=XX
  // Backend response shape: { "nextCode": "AB00001" }
  // =========================================
  Future<String?> getNextItemCode(String prefix) async {
    final response = await _api.get(
      'items/next-code',
      queryParameters: {'prefix': prefix},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to get next item code');
    }
    final data = jsonDecode(response.body);
    if (data is Map) {
      return data['nextCode']?.toString();
    }
    return data?.toString();
  }

  // =========================================
  // SEARCH ITEM NAMES (live search / autocomplete)
  // Backend route: GET /api/items/search?q=...
  // Backend response shape: [ { ItemID, ItemName, ItemCode }, ... ]
  // =========================================
  Future<List<dynamic>> searchItemNames(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }
    final response = await _api.get(
      'items/search',
      queryParameters: {'q': query.trim()},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to search items');
    }
    final data = jsonDecode(response.body);
    if (data is List) {
      return data;
    }
    return [];
  }

  // =========================================
  // CREATE ITEM
  // Backend route: POST /api/items
  // =========================================
  Future<Map<String, dynamic>> createItem(
    Map<String, dynamic> itemData,
  ) async {
    final response = await _api.post(
      'items',
      body: itemData,
    );
    final data = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data is Map && (data['error'] != null || data['message'] != null)
            ? (data['error'] ?? data['message']).toString()
            : 'Failed to create item',
      );
    }
    if (data is Map<String, dynamic>) {
      return data;
    }
    return {};
  }

  Future<List<dynamic>> fetchInventory() async {
    final response = await _api.get('inventory');
    if (response.statusCode != 200) {
      throw Exception('Failed to load inventory');
    }
    final data = jsonDecode(response.body);
    if (data is List) {
      return data;
    }
    if (data is Map && data['data'] is List) {
      return data['data'];
    }
    if (data is Map && data['records'] is List) {
      return data['records'];
    }
    return [];
  }
}