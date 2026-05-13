 class User {
  final String id;
  final String username;
  final String password;
  final String storeName;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.password,
    this.storeName = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'Id': id,
      'Username': username,
      'Password': password,
      'StoreName': storeName,
      'CreatedAt': createdAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['Id'] ?? '',
      username: map['Username'] ?? '',
      password: map['Password'] ?? '',
      storeName: map['StoreName'] ?? '',
      createdAt: DateTime.parse(map['CreatedAt']),
    );
  }
}
