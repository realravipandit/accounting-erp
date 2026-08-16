class Customer {
  final String? id;
  final String? name;
  final String? phone;
  final String? email;

  Customer({
    this.id,
    this.name,
    this.phone,
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
