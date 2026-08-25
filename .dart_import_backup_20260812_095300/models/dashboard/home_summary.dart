class HomeSummary {
  final double totalSales;
  final int salesCount;
  final double totalPurchases;
  final int purchasesCount;
  final double totalReceivables;
  final double totalPayables;
  final double inventoryValue;

  HomeSummary({
    required this.totalSales,
    required this.salesCount,
    required this.totalPurchases,
    required this.purchasesCount,
    required this.totalReceivables,
    required this.totalPayables,
    required this.inventoryValue,
  });

  factory HomeSummary.fromJson(Map<String, dynamic> json) {
    return HomeSummary(
      totalSales: (json['totalSales'] as num).toDouble(),
      salesCount: json['salesCount'] as int,
      totalPurchases: (json['totalPurchases'] as num).toDouble(),
      purchasesCount: json['purchasesCount'] as int,
      totalReceivables: (json['totalReceivables'] as num).toDouble(),
      totalPayables: (json['totalPayables'] as num).toDouble(),
      inventoryValue: (json['inventoryValue'] as num).toDouble(),
    );
  }
}
