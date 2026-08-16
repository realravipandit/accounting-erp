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
      name: map['name']?.toString(),
      outstandingAmount:
          (map['outstandingAmount'] as num?)?.toDouble(),
      type: map['type']?.toString(),
      invoices: map['invoices'] != null
          ? (map['invoices'] as List<dynamic>)
              .map(
                (x) => OutstandingInvoice.fromMap(
                  x as Map<String, dynamic>,
                ),
              )
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'outstandingAmount': outstandingAmount,
      'type': type,
      'invoices': invoices.map((invoice) => invoice.toMap()).toList(),
    };
  }
}

class OutstandingInvoice {
  final String? invoiceNumber;
  final String? date;
  final double? amount;

  OutstandingInvoice({
    this.invoiceNumber,
    this.date,
    this.amount,
  });

  factory OutstandingInvoice.fromMap(Map<String, dynamic> map) {
    return OutstandingInvoice(
      invoiceNumber: map['invoiceNumber']?.toString(),
      date: map['date']?.toString(),
      amount: (map['amount'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'invoiceNumber': invoiceNumber,
      'date': date,
      'amount': amount,
    };
  }
}