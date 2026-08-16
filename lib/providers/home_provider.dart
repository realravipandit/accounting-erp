import 'package:flutter/foundation.dart';
import 'package:sas_akount_login/services/dashboard/dashboard_service.dart';
import 'package:sas_akount_login/models/dashboard/home_summary.dart';

class HomeProvider with ChangeNotifier {
  final DashboardService _apiService;
  HomeSummary? _summary;
  bool _isLoading = false;
  String? _error;

  HomeProvider(this._apiService);

  HomeSummary? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchSummary() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.fetchDashboardSummary();
      _summary = HomeSummary.fromJson(data);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await fetchSummary();
  }
}
