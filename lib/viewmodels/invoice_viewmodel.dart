import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/database/database_helper.dart';
import '../models/invoice_model.dart';
import '../models/installment_model.dart';
import '../core/services/sync_service.dart';
import '../core/services/operation_queue_service.dart';
import '../core/services/app_logger.dart';
import 'auth_viewmodel.dart';

class InvoiceViewModel extends ChangeNotifier {
  final _dbHelper = DatabaseHelper.instance;
  final _uuid = const Uuid();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // New Sale Previews
  List<Installment> _previewInstallments = [];
  List<Installment> get previewInstallments => _previewInstallments;

  void calculateInstallmentsPreview({
    required double totalAmount,
    required double downPayment,
    required int numberOfMonths,
  }) {
    if (numberOfMonths <= 0 || totalAmount <= downPayment) {
      _previewInstallments = [];
      notifyListeners();
      return;
    }

    final double remainingAmount = totalAmount - downPayment;
    final double monthlyAmountRaw = remainingAmount / numberOfMonths;
    // PRD: Rounded to 2 decimals
    final double monthlyAmount = double.parse(monthlyAmountRaw.toStringAsFixed(2));

    List<Installment> previews = [];
    final now = DateTime.now();

    for (int i = 1; i <= numberOfMonths; i++) {
      double amount = monthlyAmount;

      // PRD calculation: adjust the last installment
      if (i == numberOfMonths) {
        amount = remainingAmount - (monthlyAmount * (numberOfMonths - 1));
        amount = double.parse(amount.toStringAsFixed(2));
      }

      previews.add(Installment(
        id: 'preview_$i', // temporary placeholder id
        createdAt: now,
        lastModified: now,
        invoiceId: 'preview',
        installmentNumber: i,
        amount: amount,
        dueDate: _addMonths(now, i),
      ));
    }

    _previewInstallments = previews;
    notifyListeners();
  }

  DateTime _addMonths(DateTime date, int months) {
    // Simple month addition (approximates due date)
    int newMonth = date.month + months;
    int newYear = date.year;
    while (newMonth > 12) {
      newMonth -= 12;
      newYear++;
    }
    // Handle days overflow (e.g., Jan 31 + 1 month = Feb 28/29)
    int newDay = date.day;
    int daysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;
    if (newDay > daysInNewMonth) {
      newDay = daysInNewMonth;
    }
    return DateTime(newYear, newMonth, newDay, date.hour, date.minute);
  }

  Future<bool> saveInvoice({
    required String customerId,
    required String itemName,
    required double totalAmount,
    required double downPayment,
    required String currency,
    required int numberOfMonths,
  }) async {
    if (_previewInstallments.isEmpty || numberOfMonths != _previewInstallments.length) {
      return false; 
    }

    _isLoading = true;
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      final invoiceId = _uuid.v4();
      final now = DateTime.now();

      final invoice = Invoice(
        id: invoiceId,
        createdAt: now,
        lastModified: now,
        customerId: customerId,
        itemName: itemName,
        totalAmount: totalAmount,
        downPayment: downPayment,
        currency: currency,
        numberOfMonths: numberOfMonths,
        isFullyPaid: false,
      );

      // Create the final installment models before the transaction to resolve their IDs once.
      List<Installment> finalInstallments = [];
      for (var preview in _previewInstallments) {
        final finalId = preview.id.startsWith('preview_') ? _uuid.v4() : preview.id;
        finalInstallments.add(Installment(
          id: finalId,
          createdAt: now,
          lastModified: now,
          invoiceId: invoiceId,
          installmentNumber: preview.installmentNumber,
          amount: preview.amount,
          dueDate: preview.dueDate,
        ));
      }

      await db.transaction((txn) async {
        // Save Invoice
        await txn.insert('Invoices', invoice.toMap());

        // Save Installments
        for (var inst in finalInstallments) {
          await txn.insert('Installments', inst.toMap());
        }
      });

      // Enqueue invoice to sync queue
      await OperationQueueServiceMobile.instance.enqueue(
        entityType: 'Invoice',
        entityId: invoiceId,
        operationType: 'Create',
        entitySnapshot: invoice.toMap(),
        changedFields: 'ItemName,TotalAmount,DownPayment,Currency,NumberOfMonths',
      );

      // Enqueue each installment
      for (var inst in finalInstallments) {
        await OperationQueueServiceMobile.instance.enqueue(
          entityType: 'Installment',
          entityId: inst.id,
          operationType: 'Create',
          entitySnapshot: {
            'Id': inst.id,
            'InvoiceId': invoiceId,
            'InstallmentNumber': inst.installmentNumber,
            'Amount': inst.amount,
            'DueDate': inst.dueDate.toIso8601String(),
            'PaidAmount': 0.0,
            'IsPaid': 0,
            'CreatedAt': now.toIso8601String(),
            'LastModified': now.toIso8601String(),
          },
          changedFields: 'Id,InvoiceId,InstallmentNumber,Amount,DueDate,PaidAmount,IsPaid,CreatedAt,LastModified',
        );
      }

      AppLogger.userAction('إضافة فاتورة جديدة', data: {
        'ItemName': itemName,
        'TotalAmount': totalAmount,
        'CustomerId': customerId,
        'Installments': _previewInstallments.length
      });

      _isLoading = false;
      notifyListeners();
      
      // Trigger immediate sync
      SyncService.performSync();
      
      return true;
    } catch (e) {
      AppLogger.error('فشل حفظ الفاتورة', e);
      debugPrint('Error saving invoice: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Ledger Activities
  List<Map<String, dynamic>> _ledger = [];
  List<Map<String, dynamic>> get ledger => _ledger;

  Future<void> fetchLedger(String customerId) async {
    _isLoading = true;
    _ledger = [];
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      
      // 1. Fetch Invoices for this customer
      final invoices = await db.query(
        'Invoices',
        where: 'CustomerId = ? AND (IsDeleted = 0 OR IsDeleted IS NULL)',
        whereArgs: [customerId],
        orderBy: 'CreatedAt DESC',
      );

      // 2. Fetch Payments for all invoices of this customer
      final payments = await db.rawQuery('''
        SELECT pt.*, inv.ItemName 
        FROM PaymentTransactions pt
        JOIN Invoices inv ON pt.InvoiceId = inv.Id
        WHERE inv.CustomerId = ? AND (pt.IsDeleted = 0 OR pt.IsDeleted IS NULL) AND (inv.IsDeleted = 0 OR inv.IsDeleted IS NULL)
        ORDER BY pt.PaymentDate DESC
      ''', [customerId]);

      List<Map<String, dynamic>> activities = [];

      for (var inv in invoices) {
        activities.add({
          'type': 'invoice',
          'date': DateTime.parse(inv['CreatedAt'] as String),
          'amount': inv['TotalAmount'],
          'title': 'فاتورة: ${inv['ItemName']}',
          'data': inv,
        });
        
        // Downpayment if exists
        if ((inv['DownPayment'] as num) > 0) {
           activities.add({
            'type': 'payment',
            'date': DateTime.parse(inv['CreatedAt'] as String),
            'amount': inv['DownPayment'],
            'title': 'دفعة مقدمة: ${inv['ItemName']}',
            'data': inv,
          });
        }
      }

      for (var pt in payments) {
        activities.add({
          'type': 'payment',
          'date': DateTime.parse(pt['PaymentDate'] as String),
          'amount': pt['AmountPaid'],
          'title': 'سداد قسط: ${pt['ItemName']}',
          'data': pt,
        });
      }

      // Sort by date newest first
      activities.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      
      _ledger = activities;
    } catch (e) {
      debugPrint('Error fetching ledger: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearPreview() {
    _previewInstallments = [];
    notifyListeners();
  }

  // Pending Installments for Payment
  Future<List<Map<String, dynamic>>> getPendingInstallments(String customerId) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.rawQuery('''
        SELECT i.*, inv.ItemName, inv.Currency
        FROM Installments i
        JOIN Invoices inv ON i.InvoiceId = inv.Id
        WHERE inv.CustomerId = ? AND i.IsPaid = 0
        ORDER BY i.DueDate ASC
      ''', [customerId]);
      return results;
    } catch (e) {
      debugPrint('Error getting pending installments: $e');
      return [];
    }
  }

  // All Invoices for Summary
  Future<List<Map<String, dynamic>>> getInvoices(String customerId) async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        'Invoices',
        where: 'CustomerId = ?',
        whereArgs: [customerId],
        orderBy: 'CreatedAt DESC',
      );
    } catch (e) {
      debugPrint('Error getting invoices: $e');
      return [];
    }
  }

  // All Installments for Statement
  Future<List<Map<String, dynamic>>> getAllInstallments(String customerId) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.rawQuery('''
        SELECT i.*, inv.ItemName, inv.Currency
        FROM Installments i
        JOIN Invoices inv ON i.InvoiceId = inv.Id
        WHERE inv.CustomerId = ?
        ORDER BY i.DueDate ASC
      ''', [customerId]);
      return results;
    } catch (e) {
      debugPrint('Error getting all installments: $e');
      return [];
    }
  }

  // Last payment date
  Future<DateTime?> getLastPaymentDate(String customerId) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.rawQuery('''
        SELECT pt.PaymentDate 
        FROM PaymentTransactions pt
        JOIN Invoices inv ON pt.InvoiceId = inv.Id
        WHERE inv.CustomerId = ?
        ORDER BY pt.PaymentDate DESC
        LIMIT 1
      ''', [customerId]);
      
      if (results.isNotEmpty) {
        return DateTime.parse(results.first['PaymentDate'] as String);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting last payment date: $e');
      return null;
    }
  }
}

