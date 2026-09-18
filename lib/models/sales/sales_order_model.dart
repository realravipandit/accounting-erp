// ============================================================================
// SALES ORDER MODEL
//
// Mirrors the real API shape from GET /sales-order (list) and
// GET /sales-order/:orderId (detail). Status is just IsAproved (Y/N) on
// tblSOMaster --- there's no separate multi-state status column.
// ============================================================================

class SalesOrder {
  final String orderNumber;
  final DateTime orderDate;
  final String customerName;
  final bool isApproved;
  final double total;
  final int itemCount;
  final double totalQty;

  const SalesOrder({
    required this.orderNumber,
    required this.orderDate,
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

class SalesOrderLineItem {
  final int srNo;
  final int itemId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double lineTotal;

  const SalesOrderLineItem({
    required this.srNo,
    required this.itemId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory SalesOrderLineItem.fromJson(Map<String, dynamic> json) {
    return SalesOrderLineItem(
      srNo: (json['srNo'] as num?)?.toInt() ?? 0,
      itemId: (json['itemId'] as num?)?.toInt() ?? 0,
      productName: json['productName']?.toString() ?? 'Unknown item',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      lineTotal: (json['lineTotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// Detail response = the order header (same shape as SalesOrder, plus
// remarks) + its line items.
class SalesOrderDetail {
  final SalesOrder order;
  final String remarks;
  final List<SalesOrderLineItem> lineItems;

  const SalesOrderDetail({
    required this.order,
    required this.remarks,
    required this.lineItems,
  });

  factory SalesOrderDetail.fromJson(Map<String, dynamic> json) {
    final orderJson = Map<String, dynamic>.from(json['order'] as Map);
    final itemsJson = (json['lineItems'] as List? ?? [])
        .map((e) => SalesOrderLineItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return SalesOrderDetail(
      order: SalesOrder.fromJson({
        ...orderJson,
        // detail response has no itemCount/totalQty --- derive from lineItems
        'itemCount': itemsJson.length,
        'totalQty': itemsJson.fold<double>(0, (sum, i) => sum + i.quantity),
      }),
      remarks: orderJson['remarks']?.toString() ?? '',
      lineItems: itemsJson,
    );
  }
}