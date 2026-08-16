import 'dart:convert';

import '../../core/network/api_service.dart';

class ReceivableService {
  ReceivableService({
    ApiService? apiService,
  }) : _api = apiService ?? ApiService();

  final ApiService _api;

  // ============================================================
  // RECEIVABLES
  // ============================================================

  Future<Map<String, dynamic>> fetchReceivables({
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
      'receivable',
      queryParameters: queryParameters,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load receivables',
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
      'ageing',
      queryParameters: queryParameters,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load ageing report',
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
      'outstanding',
      queryParameters: queryParameters,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load outstanding report',
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