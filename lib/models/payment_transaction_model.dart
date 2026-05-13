class PaymentTransaction {
  final String id;
  final DateTime createdAt;
  final DateTime lastModified;
  final String userId;
  final String invoiceId;
  final String? installmentId;
  final double amountPaid;
  final DateTime paymentDate;
  final String notes;

  PaymentTransaction({
    required this.id,
    required this.createdAt,
    required this.lastModified,
    required this.userId,
    required this.invoiceId,
    this.installmentId,
    required this.amountPaid,
    required this.paymentDate,
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'Id': id,
      'CreatedAt': createdAt.toIso8601String(),
      'LastModified': lastModified.toIso8601String(),
      'UserId': userId,
      'InvoiceId': invoiceId,
      'InstallmentId': installmentId,
      'AmountPaid': amountPaid,
      'PaymentDate': paymentDate.toIso8601String(),
      'Notes': notes,
    };
  }

  factory PaymentTransaction.fromMap(Map<String, dynamic> map) {
    return PaymentTransaction(
      id: map['Id'] ?? '',
      createdAt: DateTime.parse(map['CreatedAt']),
      lastModified: DateTime.parse(map['LastModified']),
      userId: map['UserId'] ?? '',
      invoiceId: map['InvoiceId'] ?? '',
      installmentId: map['InstallmentId'],
      amountPaid: (map['AmountPaid'] ?? 0).toDouble(),
      paymentDate: DateTime.parse(map['PaymentDate']),
      notes: map['Notes'] ?? '',
    );
  }
}
