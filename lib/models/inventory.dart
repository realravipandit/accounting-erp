class Inventory {
  final String? id;
  final String? itemName;
  final double? stockQty;
  final double? totalValue;
  final List<InventoryDetail> details;

  Inventory({
    this.id,
    this.itemName,
    this.stockQty,
    this.totalValue,
    this.details = const [],
  });

  factory Inventory.fromMap(Map<String, dynamic> map) {
    return Inventory(
      id: map['id']?.toString(),
      itemName: map['itemName']?.toString(),
      stockQty: (map['stockQty'] as num?)?.toDouble(),
      totalValue: (map['totalValue'] as num?)?.toDouble(),
      details: map['details'] != null
          ? (map['details'] as List<dynamic>)
              .map((x) => InventoryDetail.fromMap(x as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}

class InventoryDetail {
  final String? voucherId;
  final double? qty;
  final double? value;

  InventoryDetail({this.voucherId, this.qty, this.value});

  factory InventoryDetail.fromMap(Map<String, dynamic> map) {
    return InventoryDetail(
      voucherId: map['voucherId']?.toString(),
      qty: (map['qty'] as num?)?.toDouble(),
      value: (map['value'] as num?)?.toDouble(),
    );
  }
}