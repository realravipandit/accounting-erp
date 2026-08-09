library;

class PurchaseDetail {
  final String customerName;
  final String items;
  final int qty;
  final double netAmount;

  PurchaseDetail({
    required this.customerName,
    required this.items,
    required this.qty,
    required this.netAmount,
  });

  factory PurchaseDetail.fromJson(Map<String, dynamic> json) {
    return PurchaseDetail(
      customerName: json['Customer Name'] ?? 'Unknown',
      items: json['Items'] ?? 'Unknown',
      qty: (json['Qty'] as num?)?.toInt() ?? 0,
      netAmount: (json['NetAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['Customer Name'] = customerName;
    map['Items'] = items;
    map['Qty'] = qty;
    map['NetAmount'] = netAmount;
    return map;
  }
}
