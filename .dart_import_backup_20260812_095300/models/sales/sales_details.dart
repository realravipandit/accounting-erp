library;

class SalesDetail {
  final String customerName;
  final String items;
  final int qty;
  final double netAmount;
  final DateTime date;

  SalesDetail({
    required this.customerName,
    required this.items,
    required this.qty,
    required this.netAmount,
    required this.date,
  });

  factory SalesDetail.fromJson(Map<String, dynamic> json) {
    return SalesDetail(
      customerName: json['Customer Name'] ?? 'Unknown',
      items: json['Items'] ?? 'Unknown',
      qty: (json['Qty'] as num?)?.toInt() ?? 0,
      netAmount: (json['NetAmount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.parse(json['Date'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['Customer Name'] = customerName;
    map['Items'] = items;
    map['Qty'] = qty;
    map['NetAmount'] = netAmount;
    map['Date'] = date.toIso8601String();
    return map;
  }
}
