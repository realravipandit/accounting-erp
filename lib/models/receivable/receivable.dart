class Receivable {
  final String? id;
  final String? customerName;
  final double? receivableAmount;
  final List<ReceivableTransaction> transactions;

  Receivable({
    this.id,
    this.customerName,
    this.receivableAmount,
    this.transactions = const [],
  });

  factory Receivable.fromMap(Map<String, dynamic> map) {
    return Receivable(
      id: map['id']?.toString(),
      customerName: map['customerName']?.toString(),
      receivableAmount: (map['receivableAmount'] as num?)?.toDouble(),
      // Explicitly casting to avoid Type errors
      transactions: map['transactions'] != null 
          ? (map['transactions'] as List<dynamic>)
              .map((x) => ReceivableTransaction.fromMap(x as Map<String, dynamic>))
              .toList() 
          : [],
    );
  }
}

class ReceivableTransaction {
  final String? voucherId;
  final double? amount;

  ReceivableTransaction({this.voucherId, this.amount});

  factory ReceivableTransaction.fromMap(Map<String, dynamic> map) {
    return ReceivableTransaction(
      voucherId: map['voucherId']?.toString(),
      amount: (map['amount'] as num?)?.toDouble(),
    );
  }
}