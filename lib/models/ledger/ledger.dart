class Ledger {
  final int? id;
  final String? ledgerName;
  final String? ledgerCode;
  final String? ledgerType;
  final String? panNo;
  final String? cashBank;
  final String? ledgerAddress;
  final String? phoneNo;
  final String? ledgerEmail;

  Ledger({
    this.id,
    this.ledgerName,
    this.ledgerCode,
    this.ledgerType,
    this.panNo,
    this.cashBank,
    this.ledgerAddress,
    this.phoneNo,
    this.ledgerEmail,
  });

  factory Ledger.fromMap(Map<String, dynamic> map) {
    return Ledger(
      id: map['LedgerID'] ?? map['id'],
      ledgerName: map['LedgerName']?.toString() ?? map['ledgerName']?.toString(),
      ledgerCode: map['LedgerCode']?.toString() ?? map['ledgerCode']?.toString(),
      ledgerType: map['LedgerType']?.toString() ?? map['ledgerType']?.toString(),
      panNo: map['PanNo']?.toString() ?? map['panNo']?.toString(),
      cashBank: map['CashBank']?.toString() ?? map['cashBank']?.toString(),
      ledgerAddress: map['LedgerAddress']?.toString() ?? map['ledgerAddress']?.toString(),
      phoneNo: map['PhoneNo']?.toString() ?? map['MobileNo']?.toString() ?? map['phoneNo']?.toString(),
      ledgerEmail: map['LedgerEmail']?.toString() ?? map['ledgerEmail']?.toString(),
    );
  }

  // Helper to interpret LedgerType (Customer, Vendor, Both, Others)
  String get formattedType {
    switch (ledgerType?.toLowerCase().trim()) {
      case 'c':
      case 'customer':
        return 'Customer';
      case 'v':
      case 'vendor':
        return 'Vendor';
      case 'b':
      case 'both':
        return 'Both';
      default:
        return 'Other';
    }
  }
}