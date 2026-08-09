import 'package:workmanager/workmanager.dart';
import 'package:sas_akount_login/api_service.dart';
import 'package:sas_akount_login/db/db_helper.dart';
import 'package:sas_akount_login/models/sales.dart';
import 'package:sas_akount_login/models/purchase.dart';
import 'package:sas_akount_login/models/inventory.dart';

class SyncManager {
  static const syncTask = "syncTask";
  static const syncInterval = Duration(minutes: 15);

  static Future<void> initialize() async {
    // Initialize Workmanager for background processing
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  }

  static void startPeriodicSync() {
    Workmanager().registerPeriodicTask(
      "syncTask",
      syncTask,
      frequency: syncInterval,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  static Future<void> syncData() async {
    final api = ApiService();
    final db = DBHelper();

    try {
      // Sync sales
      final salesData = await api.fetchSales();
      final sales = salesData.map((map) => Sales.fromMap(map)).toList();
      await db.batchInsertSales(sales);

      // Sync purchases
      final purchasesData = await api.fetchPurchases();
      final purchases =
          purchasesData.map((map) => Purchase.fromMap(map)).toList();
      await db.batchInsertPurchases(purchases);

      // Sync inventory
      final inventoryData = await api.fetchInventory();
      final inventory =
          inventoryData.map((map) => Inventory.fromMap(map)).toList();
      await db.batchInsertInventory(inventory);

      print("Sync completed successfully");
    } catch (e) {
      print("Sync failed: $e");
    }
  }

  @pragma('vm:entry-point')
  static void callbackDispatcher() {
    Workmanager().executeTask((taskName, inputData) async {
      await syncData();
      return Future.value(true);
    });
  }
}
