class Outstanding {
  final String? id;
  final String? name;
  final double? outstandingAmount;
  final String? type;
  final List<OutstandingInvoice> invoices;

  Outstanding({
    this.id,
    this.name,
    this.outstandingAmount,
    this.type,
    this.invoices = const [],
  });

  factory Outstanding.fromMap(Map<String, dynamic> map) {
    return Outstanding(
      id: map['id']?.toString(),
      name: map['name'],
      outstandingAmount: (map['outstandingAmount'] as num?)?.toDouble(),
      type: map['type'],
      invoices: map['invoices'] != null 
          ? List<OutstandingInvoice>.from(map['invoices'].map((x) => OutstandingInvoice.fromMap(x))) 
          : [],
    );
  }
}

class OutstandingInvoice {
  final String? invoiceNumber;
  final String? date;
  final double? amount;

  OutstandingInvoice({this.invoiceNumber, this.date, this.amount});

  factory OutstandingInvoice.fromMap(Map<String, dynamic> map) {
    return OutstandingInvoice(
      invoiceNumber: map['invoiceNumber']?.toString(),
      date: map['date']?.toString(),
      amount: (map['amount'] as num?)?.toDouble(),
    );
  }
}