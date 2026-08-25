import 'item.dart';

class Sales {
  final String? id;
  final String? invoiceNumber;
  final String? customerName;
  final DateTime? date;
  final double? totalAmount;
  final String? paymentMethod;
  final List<Item> items;

  Sales({
    this.id,
    this.invoiceNumber,
    this.customerName,
    this.date,
    this.totalAmount,
    this.paymentMethod,
    required this.items,
  });

  factory Sales.fromJson(Map<String, dynamic> json) {
    return Sales(
      id: json['id'],
      invoiceNumber: json['invoiceNumber'],
      customerName: json['customerName'],
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
      totalAmount: (json['totalAmount'] as num?)?.toDouble(),
      paymentMethod: json['paymentMethod'],
      items: (json['items'] as List?)
              ?.map((item) => Item.fromJson(item))
              .toList() ??
          [],
    );
  }

  int get totalQuantity =>
      items.fold(0, (sum, item) => sum + (item.quantity ?? 0));

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'customerName': customerName,
      'date': date?.toIso8601String(),
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}
