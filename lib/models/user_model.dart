class User {
  final int? id; // Nullable for new users
  final String phoneNumber;
  final String password;
  final String? email; // Optional email field

  User({this.id, required this.phoneNumber, required this.password, this.email});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'password': password,
      'email': email, // Include email in the map
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      phoneNumber: map['phoneNumber'],
      password: map['password'],
      email: map['email'], // Include email when creating a User from map
    );
  }
}
