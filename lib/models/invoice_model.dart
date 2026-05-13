class Invoice {
  final String id;
  final DateTime createdAt;
  final DateTime lastModified;
  final String customerId;
  final String itemName;
  final double totalAmount;
  final double downPayment;
  final String currency;
  final int numberOfMonths;
  final bool isFullyPaid;

  Invoice({
    required this.id,
    required this.createdAt,
    required this.lastModified,
    required this.customerId,
    required this.itemName,
    required this.totalAmount,
    this.downPayment = 0,
    this.currency = 'IQD',
    this.numberOfMonths = 0,
    this.isFullyPaid = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'Id': id,
      'CreatedAt': createdAt.toIso8601String(),
      'LastModified': lastModified.toIso8601String(),
      'CustomerId': customerId,
      'ItemName': itemName,
      'TotalAmount': totalAmount,
      'DownPayment': downPayment,
      'Currency': currency,
      'NumberOfMonths': numberOfMonths,
      'IsFullyPaid': isFullyPaid ? 1 : 0,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['Id'] ?? '',
      createdAt: DateTime.parse(map['CreatedAt']),
      lastModified: DateTime.parse(map['LastModified']),
      customerId: map['CustomerId'] ?? '',
      itemName: map['ItemName'] ?? '',
      totalAmount: (map['TotalAmount'] ?? 0).toDouble(),
      downPayment: (map['DownPayment'] ?? 0).toDouble(),
      currency: map['Currency'] ?? 'IQD',
      numberOfMonths: map['NumberOfMonths'] ?? 0,
      isFullyPaid: (map['IsFullyPaid'] == 1),
    );
  }
}
