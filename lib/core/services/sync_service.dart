import 'package:flutter/foundation.dart';

import 'package:sas_app/core/database/db_helper.dart';
import 'package:sas_app/core/state/global.dart';

import 'package:sas_app/services/sales/sales_service.dart';
import 'package:sas_app/services/purchase/purchase_service.dart';

import 'package:sas_app/models/sales/sales.dart';
import 'package:sas_app/models/purchase/purchase.dart';

import 'package:sas_app/models/common/record_query.dart';

class SyncService {
  final SalesService _salesService;
  final PurchaseService _purchaseService;
  final DBHelper _dbHelper;

  SyncService({
    SalesService? salesService,
    PurchaseService? purchaseService,
    DBHelper? dbHelper,
  })  : _salesService = salesService ?? SalesService(),
        _purchaseService = purchaseService ?? PurchaseService(),
        _dbHelper = dbHelper ?? DBHelper();

  Future<bool> syncAll() async {
    try {
      // ----------------------------------------------------------
      // SALES
      // ----------------------------------------------------------

      final salesResponse = await _salesService.fetchSales(
        RecordQuery(
          page: 1, 
          limit: 100, // Or whatever limit you want for the background sync
          sortField: 'VoucherDate', 
          sortOrder: 'desc'
        )
      );

      final salesRecords =
          salesResponse['records'] is List
              ? salesResponse['records'] as List
              : <dynamic>[];

      final sales = salesRecords
          .whereType<Map>()
          .map(
            (json) => Sales.fromJson(
              Map<String, dynamic>.from(json),
            ),
          )
          .toList();

      Global.sales = sales;

      for (final sale in sales) {
        await _dbHelper.insertSale(sale);
      }

      // ----------------------------------------------------------
      // PURCHASES
      // ----------------------------------------------------------

      final purchaseResponse =
          await _purchaseService.fetchPurchases();

      final purchaseRecords =
          purchaseResponse['records'] is List
              ? purchaseResponse['records'] as List
              : <dynamic>[];

      final purchases = purchaseRecords
          .whereType<Map>()
          .map(
            (json) => Purchase.fromJson(
              Map<String, dynamic>.from(json),
            ),
          )
          .toList();

      Global.purchases = purchases;

      for (final purchase in purchases) {
        await _dbHelper.insertPurchase(purchase);
      }

      return true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Sync Error: $e');
        debugPrintStack(stackTrace: stackTrace);
      }

      return false;
    }
  }
}