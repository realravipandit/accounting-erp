class Payable {
  final String? id;
  final String? vendorName;
  final double? payableAmount;
  final List<PayableTransaction> transactions;

  Payable({
    this.id,
    this.vendorName,
    this.payableAmount,
    this.transactions = const [],
  });

  factory Payable.fromMap(Map<String, dynamic> map) {
    return Payable(
      id: map['id']?.toString(),
      vendorName: map['vendorName'],
      payableAmount: (map['payableAmount'] as num?)?.toDouble(),
      transactions: map['transactions'] != null 
          ? List<PayableTransaction>.from(
              map['transactions'].map((x) => PayableTransaction.fromMap(x))) 
          : [],
    );
  }
}

class PayableTransaction {
  final String? voucherId;
  final double? amount;

  PayableTransaction({this.voucherId, this.amount});

  factory PayableTransaction.fromMap(Map<String, dynamic> map) {
    return PayableTransaction(
      voucherId: map['voucherId']?.toString(),
      amount: (map['amount'] as num?)?.toDouble(),
    );
  }
}