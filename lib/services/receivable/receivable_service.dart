import 'dart:convert';
import 'package:intl/intl.dart';
import '../../core/network/api_service.dart';

class ReceivableService {
  ReceivableService({
    ApiService? apiService,
  }) : _api = apiService ?? ApiService();
  final ApiService _api;

  static String _fmtDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

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
    // ---- old-software-parity params (from ageing_screen.dart) ----
    String? dateBasis, // 'bill' | 'due'
    DateTime? asOfDate,
    int? slab,
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
    if (dateBasis != null && dateBasis.isNotEmpty) {
      queryParameters['dateBasis'] = dateBasis;
    }
    if (asOfDate != null) {
      queryParameters['asOfDate'] = _fmtDate(asOfDate);
    }
    if (slab != null) {
      queryParameters['slab'] = slab;
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
    // ---- old-software-parity params (from outstanding_screen.dart) ----
    String? dateBasis, // 'bill' | 'due'
    DateTime? asOfDate,
    DateTime? fromDate,
    DateTime? toDate,
    // Controller only nests invoice-level detail when this is true --
    // OutstandingDetailsSheet needs it, so default to true here.
    bool includeInvoices = true,
  }) async {
    final queryParameters = <String, dynamic>{
      'page': page,
      'limit': limit,
      'sortBy': sortBy,
      'sortOrder': sortOrder,
      'includeInvoices': includeInvoices.toString(),
    };
    if (period != null && period.isNotEmpty) {
      queryParameters['period'] = period;
    }
    // NOTE: backend controller (getOutstanding) reads these as
    // startDate/endDate, not fromDate/toDate -- map them here so the
    // screen's fromDate/toDate params actually reach the SQL query.
    if (startDate != null && startDate.isNotEmpty) {
      queryParameters['startDate'] = startDate;
    } else if (fromDate != null) {
      queryParameters['startDate'] = _fmtDate(fromDate);
    }
    if (endDate != null && endDate.isNotEmpty) {
      queryParameters['endDate'] = endDate;
    } else if (toDate != null) {
      queryParameters['endDate'] = _fmtDate(toDate);
    }
    if (search != null && search.isNotEmpty) {
      queryParameters['search'] = search;
    }
    if (dateBasis != null && dateBasis.isNotEmpty) {
      queryParameters['dateBasis'] = dateBasis;
    }
    if (asOfDate != null) {
      queryParameters['asOfDate'] = _fmtDate(asOfDate);
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