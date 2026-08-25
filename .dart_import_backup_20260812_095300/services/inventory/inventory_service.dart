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
  // =========================================
  Future<List<dynamic>> getItemGroups() async {
    final response = await _api.get('item-groups');

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
  // =========================================
  Future<List<dynamic>> getItemSubGroups() async {
    final response = await _api.get('item-sub-groups');

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
  // =========================================
  Future<List<dynamic>> getUnits() async {
    final response = await _api.get('units');

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
  // =========================================
  Future<String?> getNextItemCode() async {
    final response = await _api.get('items/next-code');

    if (response.statusCode != 200) {
      throw Exception('Failed to get next item code');
    }

    final data = jsonDecode(response.body);

    if (data is Map) {
      return data['itemCode']?.toString() ?? data['code']?.toString();
    }

    return data?.toString();
  }

  // =========================================
  // CREATE ITEM
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
        data is Map && data['message'] != null
            ? data['message'].toString()
            : 'Failed to create item',
      );
    }

    if (data is Map<String, dynamic>) {
      return data;
    }

    return {};
  }
}