class SystemSetting {
  final String id;
  final DateTime createdAt;
  final DateTime lastModified;
  final String userId;
  final String storeName;
  final String storePhone;
  final String storeAddress;
  final String defaultCurrency;
  final double exchangeRate;
  final bool enableOverdueAlerts;

  SystemSetting({
    required this.id,
    required this.createdAt,
    required this.lastModified,
    required this.userId,
    this.storeName = '',
    this.storePhone = '',
    this.storeAddress = '',
    this.defaultCurrency = 'IQD',
    this.exchangeRate = 0,
    this.enableOverdueAlerts = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'Id': id,
      'CreatedAt': createdAt.toIso8601String(),
      'LastModified': lastModified.toIso8601String(),
      'UserId': userId,
      'StoreName': storeName,
      'StorePhone': storePhone,
      'StoreAddress': storeAddress,
      'DefaultCurrency': defaultCurrency,
      'ExchangeRate': exchangeRate,
      'EnableOverdueAlerts': enableOverdueAlerts ? 1 : 0,
    };
  }

  factory SystemSetting.fromMap(Map<String, dynamic> map) {
    return SystemSetting(
      id: map['Id'] ?? '',
      createdAt: DateTime.parse(map['CreatedAt']),
      lastModified: DateTime.parse(map['LastModified']),
      userId: map['UserId'] ?? '',
      storeName: map['StoreName'] ?? '',
      storePhone: map['StorePhone'] ?? '',
      storeAddress: map['StoreAddress'] ?? '',
      defaultCurrency: map['DefaultCurrency'] ?? 'IQD',
      exchangeRate: (map['ExchangeRate'] ?? 0).toDouble(),
      enableOverdueAlerts: (map['EnableOverdueAlerts'] == 1),
    );
  }
}
