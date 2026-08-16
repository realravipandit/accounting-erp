class Item {
  final String? productId;
  final String? productName;
  final int? quantity;
  final double? price;

  Item({
    this.productId,
    this.productName,
    this.quantity,
    this.price,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      productId: json['productId']?.toString() ?? json['itemId']?.toString(),
      productName: json['productName']?.toString() ?? json['itemName']?.toString(),
      
      // BULLETPROOF FALLBACK: Checks 'quantity', 'qty', and 'Quantity'
      quantity: (json['quantity'] as num?)?.toInt() ?? 
                (json['qty'] as num?)?.toInt() ?? 
                (json['Quantity'] as num?)?.toInt() ?? 0,
                
      // BULLETPROOF FALLBACK: Checks 'price' and 'rate'
      price: (json['price'] as num?)?.toDouble() ?? 
             (json['rate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
    };
  }
}