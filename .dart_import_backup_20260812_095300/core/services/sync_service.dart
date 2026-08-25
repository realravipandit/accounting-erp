import 'package:flutter/foundation.dart';

import 'package:sas_akount_login/core/database/db_helper.dart';
import 'package:sas_akount_login/core/network/api_service.dart';
import 'package:sas_akount_login/core/state/global.dart';
import 'package:sas_akount_login/models/purchase/purchase.dart';
import 'package:sas_akount_login/models/sales/sales.dart';

class SyncService {
  final ApiService _apiService = ApiService();
  final DBHelper _dbHelper = DBHelper();

  Future<bool> syncAll() async {
    try {
      // -----------------------------------------------------------------------
      // SALES
      // -----------------------------------------------------------------------
      final salesData = await _apiService.fetchSales();

      final sales = salesData
          .map((json) => Sales.fromJson(json))
          .toList();

      Global.sales = sales;

      for (final sale in sales) {
        await _dbHelper.insertSale(sale);
      }

      // -----------------------------------------------------------------------
      // PURCHASES
      // -----------------------------------------------------------------------
      final purchaseData = await _apiService.fetchPurchases();

      final purchases = purchaseData
          .map((json) => Purchase.fromJson(json))
          .toList();

      Global.purchases = purchases;

      for (final purchase in purchases) {
        await _dbHelper.insertPurchase(purchase);
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Sync Error: $e');
      }

      return false;
    }
  }
}