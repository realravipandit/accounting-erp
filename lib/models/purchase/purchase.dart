class PurchaseItem {
  final int? itemId;
  final String? productName;
  final double? quantity;
  final double? price;

  PurchaseItem({this.itemId, this.productName, this.quantity, this.price});

  factory PurchaseItem.fromJson(Map<String, dynamic> json) {
    return PurchaseItem(
      itemId: json['ItemID'] ?? json['itemId'],
      productName: json['ItemName'] ?? json['productName'],
      quantity: (json['Qty'] ?? json['quantity'] as num?)?.toDouble(),
      price: (json['Rate'] ?? json['price'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
    };
  }
}

class Purchase {
  final String? invoiceNumber;
  final String? supplierName;
  final DateTime? date;
  final double? totalAmount;
  final List<PurchaseItem> items;

  Purchase({
    this.invoiceNumber,
    this.supplierName,
    this.date,
    this.totalAmount,
    this.items = const [],
  });

  // 👈 Fixes the 'id' getter error in pdf_service.dart
  String? get id => invoiceNumber;

  // 👈 Fixes the 'totalQuantity' getter & int return type error in global.dart
  double get totalQuantity {
    return items.fold(0.0, (sum, item) => sum + (item.quantity ?? 0.0));
  }

  factory Purchase.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    try {
      final dateStr = json['VoucherDate']?.toString().split('T')[0] ?? '';
      final timeStr = json['VoucherTime']?.toString() ?? '00:00:00';
      if (dateStr.isNotEmpty) {
        parsedDate = DateTime.parse('$dateStr $timeStr');
      }
    } catch (_) {
      parsedDate = json['VoucherDate'] != null ? DateTime.tryParse(json['VoucherDate']) : null;
    }

    var itemsList = <PurchaseItem>[];
    if (json['items'] != null && json['items'] is List) {
      itemsList = (json['items'] as List)
          .map((i) => PurchaseItem.fromJson(i))
          .toList();
    }

    return Purchase(
      invoiceNumber: json['invoiceNumber'] ?? json['VoucherID'],
      supplierName: json['supplierName'] ?? json['PartyName'],
      date: parsedDate,
      totalAmount: (json['totalAmount'] ?? json['NetAmount'] as num?)?.toDouble() ?? 0.0,
      items: itemsList,
    );
  }

  // 👈 Fixes the 'toJson()' method error in db_helper.dart
  Map<String, dynamic> toJson() {
    return {
      'invoiceNumber': invoiceNumber,
      'supplierName': supplierName,
      'date': date?.toIso8601String(),
      'totalAmount': totalAmount,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }
}