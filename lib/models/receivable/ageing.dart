class AgeingAccount {
  final String? id;
  final String? name;
  final String? type;
  final double? totalAmount;
  final double? bucket0_30;
  final double? bucket31_60;
  final double? bucket61_90;
  final double? bucket90_plus;
  final List<AgeingInvoice> invoices;

  AgeingAccount({
    this.id,
    this.name,
    this.type,
    this.totalAmount,
    this.bucket0_30,
    this.bucket31_60,
    this.bucket61_90,
    this.bucket90_plus,
    this.invoices = const [],
  });

  factory AgeingAccount.fromMap(Map<String, dynamic> map) {
    return AgeingAccount(
      id: map['id']?.toString(),
      name: map['name']?.toString(),
      type: map['type']?.toString(),
      totalAmount: (map['totalAmount'] as num?)?.toDouble(),
      bucket0_30: (map['bucket0_30'] as num?)?.toDouble(),
      bucket31_60: (map['bucket31_60'] as num?)?.toDouble(),
      bucket61_90: (map['bucket61_90'] as num?)?.toDouble(),
      bucket90_plus: (map['bucket90_plus'] as num?)?.toDouble(),
      invoices: map['invoices'] != null
          ? (map['invoices'] as List<dynamic>)
              .map((x) => AgeingInvoice.fromMap(x as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}

class AgeingInvoice {
  final String? invoiceNumber;
  final String? date;
  final double? amount;
  final int? daysOverdue;

  AgeingInvoice({this.invoiceNumber, this.date, this.amount, this.daysOverdue});

  factory AgeingInvoice.fromMap(Map<String, dynamic> map) {
    return AgeingInvoice(
      invoiceNumber: map['invoiceNumber']?.toString(),
      date: map['date']?.toString(),
      amount: (map['amount'] as num?)?.toDouble(),
      daysOverdue: (map['daysOverdue'] as num?)?.toInt(),
    );
  }
}