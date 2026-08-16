// // Sale Model
// class Sale {
//   final int? id;
//   // final int customerId;
//   final double quantity;
//   final double totalAmount;
//   // final String date;
//
//   Sale({
//     this.id,
//     // required this.customerId,
//     required this.quantity,
//     required this.totalAmount,
//     // required this.date,
//   });
//
//   // Convert Sale object to Map (for local database)
//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       // 'customerId': customerId,
//       'Qty': quantity,
//       'totalAmount': totalAmount,
//       // 'date': date,
//     };
//   }
//
//   // Create a Sale object from a Map (for local database)
//   factory Sale.fromMap(Map<String, dynamic> map) {
//     return Sale(
//       id: map['id'],
//       // customerId: map['customerId'],
//       quantity: map['Qty'],
//       totalAmount: map['totalAmount'],
//       // date: map['date'],
//     );
//   }
//
//   // Create a Sale object from JSON (for API response)
//   factory Sale.fromJson(Map<String, dynamic> json) {
//     return Sale(
//       id: json['id'],
//       // customerId: json['customerId'],
//       quantity: json['Qty'],
//       totalAmount: (json['totalAmount'] as num).toDouble(),
//       // date: json['date'],
//     );
//   }
// }

// // Purchase Model
// class Purchase {
//   final int? id;
//   final int vendorId;
//   final double totalAmount;
//   final String date;
//
//   Purchase({
//     this.id,
//     required this.vendorId,
//     required this.totalAmount,
//     required this.date,
//   });
//
//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'vendorId': vendorId,
//       'totalAmount': totalAmount,
//       'date': date,
//     };
//   }
//
//   factory Purchase.fromMap(Map<String, dynamic> map) {
//     return Purchase(
//       id: map['id'],
//       vendorId: map['vendorId'],
//       totalAmount: map['totalAmount'],
//       date: map['date'],
//     );
//   }
// }

// Outstanding Model
class Outstanding {
  final int? id;
  final int? customerId;
  final int? vendorId;
  final double outstandingAmount;
  final String type; // "customer" or "vendor"
  final String date;

  Outstanding({
    this.id,
    this.customerId,
    this.vendorId,
    required this.outstandingAmount,
    required this.type,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'vendorId': vendorId,
      'outstandingAmount': outstandingAmount,
      'type': type,
      'date': date,
    };
  }

  factory Outstanding.fromMap(Map<String, dynamic> map) {
    return Outstanding(
      id: map['id'],
      customerId: map['customerId'],
      vendorId: map['vendorId'],
      outstandingAmount: map['outstandingAmount'],
      type: map['type'],
      date: map['date'],
    );
  }
}

// Inventory Model
class Inventory {
  final int? id;
  final String itemName;
  final int quantity;
  final double price;

  Inventory({
    this.id,
    required this.itemName,
    required this.quantity,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemName': itemName,
      'quantity': quantity,
      'price': price,
    };
  }

  factory Inventory.fromMap(Map<String, dynamic> map) {
    return Inventory(
      id: map['id'],
      itemName: map['itemName'],
      quantity: map['quantity'],
      price: map['price'],
    );
  }
}

// Customer Model
class Customer {
  final int? id;
  final String name;
  final String phone;
  final String? email;

  Customer({
    this.id,
    required this.name,
    required this.phone,
    this.email,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      email: map['email'],
    );
  }
}

// Vendor Model
class Vendor {
  final int? id;
  final String name;
  final String phone;
  final String? email;

  Vendor({
    this.id,
    required this.name,
    required this.phone,
    this.email,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
    };
  }

  factory Vendor.fromMap(Map<String, dynamic> map) {
    return Vendor(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      email: map['email'],
    );
  }
}

// User Model
class DashBoardUser {
  final int? id;
  final String phone;
  final String password;

  DashBoardUser({
    this.id,
    required this.phone,
    required this.password,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phone': phone,
      'password': password,
    };
  }

  factory DashBoardUser.fromMap(Map<String, dynamic> map) {
    return DashBoardUser(
      id: map['id'],
      phone: map['phone'],
      password: map['password'],
    );
  }
}
