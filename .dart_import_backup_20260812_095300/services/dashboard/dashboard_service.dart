import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/network/api_service.dart';

class DashboardService {
  DashboardService({
    ApiService? apiService,
  }) : _api = apiService ?? ApiService();

  final ApiService _api;

  Future<Map<String, dynamic>> fetchDashboardSummary({
    String? period,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParameters = <String, dynamic>{};

      if (period != null && period.isNotEmpty) {
        queryParameters['period'] = period;
      }

      if (startDate != null && endDate != null) {
        queryParameters['startDate'] =
            _formatDate(startDate);
        queryParameters['endDate'] =
            _formatDate(endDate);
      }

      final response = await _api.get(
        'dashboard',
        queryParameters: queryParameters,
      );

      debugPrint(
        'Dashboard Status: ${response.statusCode}',
      );

      if (response.statusCode != 200) {
        return {};
      }

      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is List &&
          decoded.isNotEmpty &&
          decoded.first is Map<String, dynamic>) {
        return Map<String, dynamic>.from(
          decoded.first,
        );
      }

      return {};
    } catch (e) {
      debugPrint(
        'Dashboard Error: $e',
      );

      return {};
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}