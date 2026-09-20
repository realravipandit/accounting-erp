// ============================================================================
// SALES ORDER MODEL
//
// Mirrors the real API shape from GET /sales-order (list) and
// GET /sales-order/:orderId (detail). Status is just IsAproved (Y/N) on
// tblSOMaster --- there's no separate multi-state status column.
//
// Terms (discounts, VAT, etc.) come from tblSOTerm:
//   * bill-level terms  -> SalesOrderDetail.billTerms   (TermType 'B')
//   * item-wise terms   -> SalesOrderLineItem.itemTerms (TermType 'P')
// The API sends the amount as an absolute value plus a sign ('+' / '-').
// ============================================================================

class SalesOrder {
  final String orderNumber;
  final DateTime orderDate;
  final String miti;
  final String customerName;
  final bool isApproved;
  final double total;
  final int itemCount;
  final double totalQty;

  const SalesOrder({
    required this.orderNumber,
    required this.orderDate,
    required this.miti,
    required this.customerName,
    required this.isApproved,
    required this.total,
    required this.itemCount,
    required this.totalQty,
  });

  factory SalesOrder.fromJson(Map<String, dynamic> json) {
    return SalesOrder(
      orderNumber: json['orderNumber']?.toString() ?? '',
      orderDate: DateTime.tryParse(json['orderDate']?.toString() ?? '') ?? DateTime.now(),
      miti: json['miti']?.toString() ?? '',
      customerName: (json['customerName']?.toString().trim().isNotEmpty ?? false)
          ? json['customerName'].toString()
          : 'Cash',
      isApproved: (json['isApproved']?.toString().toUpperCase() ?? 'N') == 'Y',
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      totalQty: (json['totalQty'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// One term row (a bill-level term or an item-wise term).
class SalesOrderTerm {
  final int termId;
  final String termName;
  final double rate; // percent, e.g. 5 or 13
  final double amount; // always absolute
  final String sign; // '+' or '-'

  const SalesOrderTerm({
    required this.termId,
    required this.termName,
    required this.rate,
    required this.amount,
    required this.sign,
  });

  bool get isDeduction => sign == '-';

  double get signedAmount => isDeduction ? -amount : amount;

  // e.g. "BDISCOUNT (5%)" --- percent is omitted when the rate is 0.
  String get label {
    if (rate <= 0) return termName;
    final pct = rate == rate.truncateToDouble() ? rate.toStringAsFixed(0) : rate.toStringAsFixed(2);
    return '$termName ($pct%)';
  }

  factory SalesOrderTerm.fromJson(Map<String, dynamic> json) {
    final name = json['termName']?.toString().trim() ?? '';
    return SalesOrderTerm(
      termId: (json['termId'] as num?)?.toInt() ?? 0,
      termName: name.isNotEmpty ? name : 'Term',
      rate: (json['termRate'] as num?)?.toDouble() ?? 0.0,
      amount: (json['termAmount'] as num?)?.toDouble() ?? 0.0,
      sign: (json['termSign']?.toString().trim() ?? '+') == '-' ? '-' : '+',
    );
  }
}

class SalesOrderLineItem {
  final int srNo;
  final int itemId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double lineTotal; // net of item-wise terms (tblSODetails.NetAmount)
  final String unitCode;
  final List<SalesOrderTerm> itemTerms;

  const SalesOrderLineItem({
    required this.srNo,
    required this.itemId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.unitCode,
    this.itemTerms = const [],
  });

  // Signed sum of this line's item-wise terms (discounts negative).
  double get termTotal => itemTerms.fold<double>(0, (sum, t) => sum + t.signedAmount);

  factory SalesOrderLineItem.fromJson(Map<String, dynamic> json) {
    return SalesOrderLineItem(
      srNo: (json['srNo'] as num?)?.toInt() ?? 0,
      itemId: (json['itemId'] as num?)?.toInt() ?? 0,
      productName: json['productName']?.toString() ?? 'Unknown item',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      lineTotal: (json['lineTotal'] as num?)?.toDouble() ?? 0.0,
      unitCode: json['unitCode']?.toString().trim() ?? '',
      itemTerms: (json['itemTerms'] as List? ?? [])
          .map((e) => SalesOrderTerm.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

// Detail response = the order header (same shape as SalesOrder, plus
// remarks) + its line items + its bill-level terms.
class SalesOrderDetail {
  final SalesOrder order;
  final String remarks;
  final List<SalesOrderLineItem> lineItems;
  final List<SalesOrderTerm> billTerms;
  final double basicAmount; // sum of line totals (tblSOMaster.BasicAmount)
  final double termAmount; // signed net of bill terms (tblSOMaster.TermAmount)

  const SalesOrderDetail({
    required this.order,
    required this.remarks,
    required this.lineItems,
    this.billTerms = const [],
    this.basicAmount = 0.0,
    this.termAmount = 0.0,
  });

  factory SalesOrderDetail.fromJson(Map<String, dynamic> json) {
    final orderJson = Map<String, dynamic>.from(json['order'] as Map);
    final itemsJson = (json['lineItems'] as List? ?? [])
        .map((e) => SalesOrderLineItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final termsJson = (json['terms'] as List? ?? [])
        .map((e) => SalesOrderTerm.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final itemsTotal = itemsJson.fold<double>(0, (sum, i) => sum + i.lineTotal);

    return SalesOrderDetail(
      order: SalesOrder.fromJson({
        ...orderJson,
        // detail response has no itemCount/totalQty --- derive from lineItems
        'itemCount': itemsJson.length,
        'totalQty': itemsJson.fold<double>(0, (sum, i) => sum + i.quantity),
      }),
      remarks: orderJson['remarks']?.toString() ?? '',
      lineItems: itemsJson,
      billTerms: termsJson,
      basicAmount: (orderJson['basicAmount'] as num?)?.toDouble() ?? itemsTotal,
      termAmount: (orderJson['termAmount'] as num?)?.toDouble() ??
          termsJson.fold<double>(0, (sum, t) => sum + t.signedAmount),
    );
  }
}