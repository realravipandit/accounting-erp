import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../../models/inventory/inventory.dart';
import '../../models/purchase/purchase.dart';
import '../../models/sales/sales.dart';
import '../database/db_helper.dart';
import '../network/api_service.dart';

class SyncManager {
  static const String syncTask = 'syncTask';

  static const Duration syncInterval = Duration(
    minutes: 15,
  );

  // ---------------------------------------------------------------------------
  // INITIALIZE BACKGROUND SYNC
  // ---------------------------------------------------------------------------

  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  }

  // ---------------------------------------------------------------------------
  // START PERIODIC SYNC
  // ---------------------------------------------------------------------------

  static Future<void> startPeriodicSync() async {
    await Workmanager().registerPeriodicTask(
      'sas-akount-periodic-sync',
      syncTask,
      frequency: syncInterval,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MANUAL / BACKGROUND SYNC
  // ---------------------------------------------------------------------------

  static Future<void> syncData() async {
    final ApiService api = ApiService();
    final DBHelper db = DBHelper();

    try {
      await _syncSales(api, db);
      await _syncPurchases(api, db);
      await _syncInventory(api, db);

      debugPrint('Sync completed successfully.');
    } catch (error, stackTrace) {
      debugPrint('Sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ---------------------------------------------------------------------------
  // SALES
  // ---------------------------------------------------------------------------

  static Future<void> _syncSales(
    ApiService api,
    DBHelper db,
  ) async {
    final response = await api.get('sales');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Sales sync failed. HTTP ${response.statusCode}',
      );
    }

    final dynamic decoded = api.decodeResponse(response);

    final List<dynamic> records = _extractList(decoded);

    for (final dynamic record in records) {
      if (record is Map<String, dynamic>) {
        final Sales sale = Sales.fromJson(record);
        await db.insertSale(sale);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // PURCHASES
  // ---------------------------------------------------------------------------

  static Future<void> _syncPurchases(
    ApiService api,
    DBHelper db,
  ) async {
    final response = await api.get('purchase');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Purchase sync failed. HTTP ${response.statusCode}',
      );
    }

    final dynamic decoded = api.decodeResponse(response);

    final List<dynamic> records = _extractList(decoded);

    for (final dynamic record in records) {
      if (record is Map<String, dynamic>) {
        final Purchase purchase = Purchase.fromJson(record);
        await db.insertPurchase(purchase);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // INVENTORY
  // ---------------------------------------------------------------------------

  static Future<void> _syncInventory(
    ApiService api,
    DBHelper db,
  ) async {
    final response = await api.get('inventory');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Inventory sync failed. HTTP ${response.statusCode}',
      );
    }

    final dynamic decoded = api.decodeResponse(response);

    final List<dynamic> records = _extractList(decoded);

    for (final dynamic record in records) {
      if (record is Map<String, dynamic>) {
        final Inventory inventory = Inventory.fromMap(record);
        await db.insertInventory(inventory);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // RESPONSE NORMALIZATION
  // ---------------------------------------------------------------------------

  static List<dynamic> _extractList(dynamic decoded) {
    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      final dynamic data = decoded['data'];

      if (data is List) {
        return data;
      }

      final dynamic records = decoded['records'];

      if (records is List) {
        return records;
      }
    }

    return <dynamic>[];
  }

  // ---------------------------------------------------------------------------
  // WORKMANAGER CALLBACK
  // ---------------------------------------------------------------------------

  @pragma('vm:entry-point')
  static void callbackDispatcher() {
    Workmanager().executeTask(
      (String taskName, Map<String, dynamic>? inputData) async {
        if (taskName == syncTask) {
          await syncData();
        }

        return true;
      },
    );
  }
}