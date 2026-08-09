import 'package:sas_akount_login/api_service.dart';
import 'package:sas_akount_login/db/db_helper.dart';
import 'package:sas_akount_login/models/global.dart';
import 'package:sas_akount_login/models/sales.dart';
import 'package:sas_akount_login/models/purchase.dart';
import 'package:flutter/foundation.dart';

class SyncService {
  final ApiService _apiService = ApiService();
  final DBHelper _dbHelper = DBHelper();

  Future<bool> syncAll() async {
    try {
      // Fetch Sales
      final salesData = await _apiService.fetchSales();
      final sales = salesData.map((json) => Sales.fromJson(json)).toList();
      Global.sales = sales;
      for (var sale in sales) {
        await _dbHelper.insertSale(sale);
      }

      // Fetch Purchases
      final purchaseData = await _apiService.fetchPurchases();
      final purchases = purchaseData.map((json) => Purchase.fromJson(json)).toList();
      Global.purchases = purchases;
      for (var purchase in purchases) {
        await _dbHelper.insertPurchase(purchase);
      }

      // Add more sync logic here for other modules (inventory, customers, etc.)

      return true;
    } catch (e) {
      if (kDebugMode) print('Sync Error: $e');
      return false;
    }
  }
}
