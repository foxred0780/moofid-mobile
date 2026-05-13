class Customer {
  final String id;
  final DateTime createdAt;
  final DateTime lastModified;
  final String userId;
  final String name;
  final String phone;
  final String address;
  final String notes;
  final double totalDebtIQD;
  final double totalDebtUSD;
  final bool isDeleted;

  Customer({
    required this.id,
    required this.createdAt,
    required this.lastModified,
    required this.userId,
    required this.name,
    this.phone = '',
    this.address = '',
    this.notes = '',
    this.totalDebtIQD = 0.0,
    this.totalDebtUSD = 0.0,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'Id': id,
      'CreatedAt': createdAt.toIso8601String(),
      'LastModified': lastModified.toIso8601String(),
      'UserId': userId,
      'Name': name,
      'Phone': phone,
      'Address': address,
      'Notes': notes,
      'IsDeleted': isDeleted ? 1 : 0,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['Id'] ?? '',
      createdAt: DateTime.parse(map['CreatedAt']),
      lastModified: DateTime.parse(map['LastModified']),
      userId: map['UserId'] ?? '',
      name: map['Name'] ?? '',
      phone: map['Phone'] ?? '',
      address: map['Address'] ?? '',
      notes: map['Notes'] ?? '',
      totalDebtIQD: (map['TotalDebtIQD'] as num?)?.toDouble() ?? 0.0,
      totalDebtUSD: (map['TotalDebtUSD'] as num?)?.toDouble() ?? 0.0,
      isDeleted: map['IsDeleted'] == 1,
    );
  }
}

