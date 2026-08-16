import 'dart:convert';

import '../../core/network/api_service.dart';

class PayableService {
  PayableService({
    ApiService? apiService,
  }) : _api = apiService ?? ApiService();

  final ApiService _api;

  // ============================================================
  // PAYABLES
  // ============================================================

  Future<Map<String, dynamic>> fetchPayables({
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
      'payable',
      queryParameters: queryParameters,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load payables',
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
  // AGEING
  // ============================================================

  Future<Map<String, dynamic>> fetchAgeing({
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
      'payable/ageing',
      queryParameters: queryParameters,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load payable ageing report',
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
  // OUTSTANDING
  // ============================================================

  Future<Map<String, dynamic>> fetchOutstanding({
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
      'payable/outstanding',
      queryParameters: queryParameters,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load payable outstanding report',
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
}