import 'package:sas_app/models/purchase/purchase.dart';
import 'package:sas_app/models/sales/sales.dart';

class Global {
  static List<Sales> sales = [];
  static List<Purchase> purchases = [];

  // Add summary calculation methods
  static double get totalSales =>
      sales.fold(0, (sum, sale) => sum + (sale.totalAmount ?? 0));
  static int get totalSalesItems =>
      sales.fold(0, (sum, sale) => sum + sale.totalQuantity);

  static double get totalPurchases =>
      purchases.fold(0.0, (sum, purchase) => sum + (purchase.totalAmount ?? 0));
  static int get totalPurchaseItems =>
      purchases.fold(0.0, (sum, purchase) => sum + purchase.totalQuantity).toInt();
}

