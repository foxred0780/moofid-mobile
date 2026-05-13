import 'package:flutter/material.dart';
import '../core/database/database_helper.dart';
import 'auth_viewmodel.dart';
import '../models/installment_model.dart';

class DashboardViewModel extends ChangeNotifier {
  final _dbHelper = DatabaseHelper.instance;
  final AuthViewModel _authViewModel;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  double _totalPendingIQD = 0;
  double get totalPendingIQD => _totalPendingIQD;

  double _totalPendingUSD = 0;
  double get totalPendingUSD => _totalPendingUSD;

  double _totalCollectedIQD = 0;
  double get totalCollectedIQD => _totalCollectedIQD;

  double _totalCollectedUSD = 0;
  double get totalCollectedUSD => _totalCollectedUSD;

  List<Map<String, dynamic>> _overdueInstallments = [];
  List<Map<String, dynamic>> get overdueInstallments => _overdueInstallments;

  DashboardViewModel(this._authViewModel) {
    loadDashboard();
  }

  double _totalCombinedPending = 0;
  double get totalCombinedPending => _totalCombinedPending;

  double _totalCombinedCollected = 0;
  double get totalCombinedCollected => _totalCombinedCollected;

  Future<void> loadDashboard() async {
    final user = _authViewModel.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      final now = DateTime.now();

      // Fetch exchange rate to calculate consolidated totals
      final settingsResult = await db.query('SystemSettings', where: 'UserId = ?', whereArgs: [user.id]);
      double rate = 0;
      String defCurrency = 'IQD';
      if (settingsResult.isNotEmpty) {
        rate = (settingsResult.first['ExchangeRate'] as num?)?.toDouble() ?? 0.0;
        defCurrency = settingsResult.first['DefaultCurrency'] as String? ?? 'IQD';
      }

      // 1. Total Collected (by currency) = Invoices.DownPayment + Installments.PaidAmount
      final collectedResult = await db.rawQuery('''
        SELECT 
          (SELECT SUM(CASE WHEN inv1.Currency = 'IQD' THEN inv1.DownPayment ELSE 0 END) 
           FROM Invoices inv1 
           INNER JOIN Customers c1 ON inv1.CustomerId = c1.Id 
           WHERE c1.UserId = ? AND (inv1.IsDeleted = 0 OR inv1.IsDeleted IS NULL) AND (c1.IsDeleted = 0 OR c1.IsDeleted IS NULL)) as DownPaymentIQD,
           
          (SELECT SUM(CASE WHEN inv2.Currency = 'USD' THEN inv2.DownPayment ELSE 0 END) 
           FROM Invoices inv2 
           INNER JOIN Customers c2 ON inv2.CustomerId = c2.Id 
           WHERE c2.UserId = ? AND (inv2.IsDeleted = 0 OR inv2.IsDeleted IS NULL) AND (c2.IsDeleted = 0 OR c2.IsDeleted IS NULL)) as DownPaymentUSD,

          (SELECT SUM(CASE WHEN inv3.Currency = 'IQD' THEN i1.PaidAmount ELSE 0 END) 
           FROM Installments i1 
           INNER JOIN Invoices inv3 ON i1.InvoiceId = inv3.Id
           INNER JOIN Customers c3 ON inv3.CustomerId = c3.Id
           WHERE c3.UserId = ? AND (i1.IsDeleted = 0 OR i1.IsDeleted IS NULL) AND (inv3.IsDeleted = 0 OR inv3.IsDeleted IS NULL) AND (c3.IsDeleted = 0 OR c3.IsDeleted IS NULL)) as InstallmentPaidIQD,

          (SELECT SUM(CASE WHEN inv4.Currency = 'USD' THEN i2.PaidAmount ELSE 0 END) 
           FROM Installments i2 
           INNER JOIN Invoices inv4 ON i2.InvoiceId = inv4.Id
           INNER JOIN Customers c4 ON inv4.CustomerId = c4.Id
           WHERE c4.UserId = ? AND (i2.IsDeleted = 0 OR i2.IsDeleted IS NULL) AND (inv4.IsDeleted = 0 OR inv4.IsDeleted IS NULL) AND (c4.IsDeleted = 0 OR c4.IsDeleted IS NULL)) as InstallmentPaidUSD
      ''', [user.id, user.id, user.id, user.id]);

      double dpIqd = (collectedResult.first['DownPaymentIQD'] as num?)?.toDouble() ?? 0.0;
      double dpUsd = (collectedResult.first['DownPaymentUSD'] as num?)?.toDouble() ?? 0.0;
      double instIqd = (collectedResult.first['InstallmentPaidIQD'] as num?)?.toDouble() ?? 0.0;
      double instUsd = (collectedResult.first['InstallmentPaidUSD'] as num?)?.toDouble() ?? 0.0;

      _totalCollectedIQD = dpIqd + instIqd;
      _totalCollectedUSD = dpUsd + instUsd;

      // 2. Total Pending (Unpaid) = Sum of Installments (Amount - PaidAmount) (by currency)
      final pendingResult = await db.rawQuery('''
        SELECT 
          SUM(CASE WHEN inv.Currency = 'IQD' THEN i.Amount - i.PaidAmount ELSE 0 END) as TotalIQD,
          SUM(CASE WHEN inv.Currency = 'USD' THEN i.Amount - i.PaidAmount ELSE 0 END) as TotalUSD
        FROM Installments i
        INNER JOIN Invoices inv ON i.InvoiceId = inv.Id
        INNER JOIN Customers c ON inv.CustomerId = c.Id
        WHERE c.UserId = ? AND i.IsPaid = 0 AND (i.IsDeleted = 0 OR i.IsDeleted IS NULL) AND (inv.IsDeleted = 0 OR inv.IsDeleted IS NULL) AND (c.IsDeleted = 0 OR c.IsDeleted IS NULL)
      ''', [user.id]);
      _totalPendingIQD = (pendingResult.first['TotalIQD'] as num?)?.toDouble() ?? 0.0;
      _totalPendingUSD = (pendingResult.first['TotalUSD'] as num?)?.toDouble() ?? 0.0;

      // Calculate Combined Totals if rate exists
      // Assuming rate is for 100 USD as per settings UI label "سعر الصرف (للـ 100$)"
      final double singleDollarRate = rate / 100.0;
      
      if (defCurrency == 'IQD') {
        _totalCombinedPending = _totalPendingIQD + (_totalPendingUSD * singleDollarRate);
        _totalCombinedCollected = _totalCollectedIQD + (_totalCollectedUSD * singleDollarRate);
      } else {
        // Default is USD
        _totalCombinedPending = _totalPendingUSD + (singleDollarRate > 0 ? (_totalPendingIQD / singleDollarRate) : 0);
        _totalCombinedCollected = _totalCollectedUSD + (singleDollarRate > 0 ? (_totalCollectedIQD / singleDollarRate) : 0);
      }

      // 3. Overdue Installments (DueDate <= Today - 3 days)
      final overdueDate = now.subtract(const Duration(days: 3)).toIso8601String();
      final overdueMaps = await db.rawQuery('''
        SELECT i.*, c.Name as CustomerName, c.Id as CustomerId, inv.ItemName 
        FROM Installments i
        INNER JOIN Invoices inv ON i.InvoiceId = inv.Id
        INNER JOIN Customers c ON inv.CustomerId = c.Id
        WHERE c.UserId = ? AND i.IsPaid = 0 AND i.DueDate <= ? AND (i.IsDeleted = 0 OR i.IsDeleted IS NULL) AND (inv.IsDeleted = 0 OR inv.IsDeleted IS NULL) AND (c.IsDeleted = 0 OR c.IsDeleted IS NULL)
        ORDER BY i.DueDate ASC
      ''', [user.id, overdueDate]);

      _overdueInstallments = overdueMaps;

    } catch (e) {
      debugPrint('Error loading dashboard: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
