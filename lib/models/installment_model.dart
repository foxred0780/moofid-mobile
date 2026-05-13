class Installment {
  final String id;
  final DateTime createdAt;
  final DateTime lastModified;
  final String invoiceId;
  final int installmentNumber;
  final double amount;
  final double paidAmount;
  final DateTime dueDate;
  final bool isPaid;
  final DateTime? paidDate;

  Installment({
    required this.id,
    required this.createdAt,
    required this.lastModified,
    required this.invoiceId,
    required this.installmentNumber,
    required this.amount,
    this.paidAmount = 0,
    required this.dueDate,
    this.isPaid = false,
    this.paidDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'Id': id,
      'CreatedAt': createdAt.toIso8601String(),
      'LastModified': lastModified.toIso8601String(),
      'InvoiceId': invoiceId,
      'InstallmentNumber': installmentNumber,
      'Amount': amount,
      'PaidAmount': paidAmount,
      'DueDate': dueDate.toIso8601String(),
      'IsPaid': isPaid ? 1 : 0,
      'PaidDate': paidDate?.toIso8601String(),
    };
  }

  factory Installment.fromMap(Map<String, dynamic> map) {
    return Installment(
      id: map['Id'] ?? '',
      createdAt: DateTime.parse(map['CreatedAt']),
      lastModified: DateTime.parse(map['LastModified']),
      invoiceId: map['InvoiceId'] ?? '',
      installmentNumber: map['InstallmentNumber'] ?? 0,
      amount: (map['Amount'] ?? 0).toDouble(),
      paidAmount: (map['PaidAmount'] ?? 0).toDouble(),
      dueDate: DateTime.parse(map['DueDate']),
      isPaid: (map['IsPaid'] == 1),
      paidDate: map['PaidDate'] != null ? DateTime.parse(map['PaidDate']) : null,
    );
  }

  double get remainingAmount => amount - paidAmount;
}
