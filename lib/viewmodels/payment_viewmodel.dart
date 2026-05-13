import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/database/database_helper.dart';
import '../models/payment_transaction_model.dart';
import '../models/installment_model.dart';
import 'auth_viewmodel.dart';
import '../core/services/sync_service.dart';
import '../core/services/operation_queue_service.dart';
import '../core/services/app_logger.dart';

class PaymentViewModel extends ChangeNotifier {
  final _dbHelper = DatabaseHelper.instance;
  final AuthViewModel _authViewModel;
  final _uuid = const Uuid();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  PaymentViewModel(this._authViewModel);

  Future<bool> payInstallment({
    required Installment installment,
    required double paymentAmount,
  }) async {
    final user = _authViewModel.currentUser;
    if (user == null || paymentAmount <= 0) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      final now = DateTime.now();

      // PRD Logic:
      // 1. Verify amount
      // 2. Reduce to remaining if it exceeds
      double remaining = installment.amount - installment.paidAmount;
      double actualPayment = paymentAmount > remaining ? remaining : paymentAmount;

      double newPaidAmount = installment.paidAmount + actualPayment;
      bool isPaid = newPaidAmount >= installment.amount; 
      // Floating point math might be tricky so >= is safer.

      String paymentTxnId = '';
      Map<String, dynamic> paymentTxnMap = {};

      await db.transaction((txn) async {
        // 1. Update Installment
        await txn.update(
          'Installments',
          {
            'PaidAmount': newPaidAmount,
            'IsPaid': isPaid ? 1 : 0,
            'PaidDate': isPaid ? now.toIso8601String() : installment.paidDate?.toIso8601String(),
            'LastModified': now.toIso8601String(),
          },
          where: 'Id = ?',
          whereArgs: [installment.id],
        );

        // 2. Insert Transaction Record
        final transaction = PaymentTransaction(
          id: _uuid.v4(),
          createdAt: now,
          lastModified: now,
          userId: user.id,
          invoiceId: installment.invoiceId,
          installmentId: installment.id,
          amountPaid: actualPayment,
          paymentDate: now,
        );
        paymentTxnId = transaction.id;
        paymentTxnMap = transaction.toMap();

        await txn.insert('PaymentTransactions', transaction.toMap());

        // 3. Check Invoice Completion
        // If all installments for this invoice are paid, mark invoice as paid
        final allInsts = await txn.query(
          'Installments',
          where: 'InvoiceId = ?',
          whereArgs: [installment.invoiceId]
        );
        
        bool allPaid = true;
        for (var instMap in allInsts) {
          if (instMap['IsPaid'] == 0) {
            allPaid = false;
            break;
          }
        }

        if (allPaid) {
          await txn.update(
            'Invoices',
            {'IsFullyPaid': 1, 'LastModified': now.toIso8601String()},
            where: 'Id = ?',
            whereArgs: [installment.invoiceId]
          );
        }
      });

      // Enqueue installment update and payment creation
      await OperationQueueServiceMobile.instance.enqueue(
        entityType: 'Installment',
        entityId: installment.id,
        operationType: 'Update',
        entitySnapshot: {
          'Id': installment.id, 
          'InvoiceId': installment.invoiceId,
          'InstallmentNumber': installment.installmentNumber,
          'Amount': installment.amount,
          'DueDate': installment.dueDate.toIso8601String(),
          'PaidAmount': newPaidAmount, 
          'IsPaid': isPaid ? 1 : 0,
          'PaidDate': isPaid ? now.toIso8601String() : null,
          'LastModified': now.toIso8601String(),
        },
        changedFields: 'PaidAmount,IsPaid,PaidDate',
      );
      await OperationQueueServiceMobile.instance.enqueue(
        entityType: 'PaymentTransaction',
        entityId: paymentTxnId,
        operationType: 'Create',
        entitySnapshot: paymentTxnMap,
        changedFields: 'AmountPaid,PaymentDate',
      );

      AppLogger.userAction('تسديد قسط مفرد', data: {
        'Amount': actualPayment,
        'InstallmentId': installment.id,
        'InvoiceId': installment.invoiceId
      });

      _isLoading = false;
      notifyListeners();
      
      // Trigger sync
      SyncService.performSync();
      
      return true;
    } catch (e) {
      AppLogger.error('فشل تسديد القسط', e);
      debugPrint('Error paying installment: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> payAmountForCustomer({
    required String customerId,
    required double totalAmount,
    String? currency,
  }) async {
    final user = _authViewModel.currentUser;
    if (user == null || totalAmount <= 0) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      final now = DateTime.now();

      // Get pending installments ordered by oldest first
      final String currencyFilter = currency != null ? 'AND inv.Currency = ?' : '';
      final List<dynamic> queryArgs = currency != null ? [customerId, currency] : [customerId];

      final pendingRaw = await db.rawQuery('''
        SELECT i.*, inv.ItemName 
        FROM Installments i
        JOIN Invoices inv ON i.InvoiceId = inv.Id
        WHERE inv.CustomerId = ? AND i.IsPaid = 0 $currencyFilter
        ORDER BY i.DueDate ASC
      ''', queryArgs);

      if (pendingRaw.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final List<Map<String, dynamic>> bulkOps = [];
      await db.transaction((txn) async {
        double remainingToPay = totalAmount;

        for (var instMap in pendingRaw) {
          if (remainingToPay <= 0) break;

          final inst = Installment.fromMap(instMap);
          double debt = inst.amount - inst.paidAmount;
          double paymentForThis = remainingToPay > debt ? debt : remainingToPay;

          double newPaidAmount = inst.paidAmount + paymentForThis;
          bool isPaid = newPaidAmount >= inst.amount;

          // 1. Update Installment
          final instUpdate = {
            'Id': inst.id,
            'InvoiceId': inst.invoiceId,
            'InstallmentNumber': inst.installmentNumber,
            'Amount': inst.amount,
            'DueDate': inst.dueDate.toIso8601String(),
            'PaidAmount': newPaidAmount,
            'IsPaid': isPaid ? 1 : 0,
            'PaidDate': isPaid ? now.toIso8601String() : inst.paidDate?.toIso8601String(),
            'LastModified': now.toIso8601String(),
          };
          await txn.update(
            'Installments',
            instUpdate,
            where: 'Id = ?',
            whereArgs: [inst.id],
          );
          
          bulkOps.add({
            'EntityType': 'Installment',
            'EntityId': inst.id,
            'OperationType': 'Update',
            'Snapshot': instUpdate,
            'ChangedFields': 'PaidAmount,IsPaid,PaidDate',
          });

          // 2. Insert Transaction Record
          final transaction = PaymentTransaction(
            id: _uuid.v4(),
            createdAt: now,
            lastModified: now,
            userId: user.id,
            invoiceId: inst.invoiceId,
            installmentId: inst.id,
            amountPaid: paymentForThis,
            paymentDate: now,
          );
          final txnMap = transaction.toMap();
          await txn.insert('PaymentTransactions', txnMap);
          
          bulkOps.add({
            'EntityType': 'PaymentTransaction',
            'EntityId': transaction.id,
            'OperationType': 'Create',
            'Snapshot': txnMap,
            'ChangedFields': 'AmountPaid,PaymentDate,InstallmentId,InvoiceId,Notes',
          });

          // 3. Check Invoice Completion
          final invoiceInsts = await txn.query('Installments', where: 'InvoiceId = ?', whereArgs: [inst.invoiceId]);
          bool allInvoicePaid = invoiceInsts.every((m) => m['IsPaid'] == 1);
          if (allInvoicePaid) {
            await txn.update('Invoices', {'IsFullyPaid': 1, 'LastModified': now.toIso8601String()}, where: 'Id = ?', whereArgs: [inst.invoiceId]);
          }

          remainingToPay -= paymentForThis;
        }
      });

      // Instead of fake Customer enqueue, PUSH the actual transactions and installments!
      for (var op in bulkOps) {
        await OperationQueueServiceMobile.instance.enqueue(
          entityType: op['EntityType'],
          entityId: op['EntityId'],
          operationType: op['OperationType'],
          entitySnapshot: op['Snapshot'],
          changedFields: op['ChangedFields'],
        );
      }

      AppLogger.userAction('تسديد مبلغ إجمالي لعميل', data: {
        'Amount': totalAmount,
        'CustomerId': customerId,
        'OperationsCount': bulkOps.length
      });

      _isLoading = false;
      notifyListeners();
      
      // Trigger sync
      SyncService.performSync();
      
      return true;
    } catch (e) {
      AppLogger.error('فشل التسديد الإجمالي للعميل', e);
      debugPrint('Error in bulk payment: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateInstallmentAmount(String installmentId, double newAmount) async {
    if (newAmount < 0) return false;
    _isLoading = true;
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      final now = DateTime.now();

      // Get current paid amount to check if newAmount makes it paid
      final current = await db.query('Installments', where: 'Id = ?', whereArgs: [installmentId]);
      if (current.isEmpty) return false;
      
      double paid = (current.first['PaidAmount'] as num?)?.toDouble() ?? 0;
      bool isPaid = paid >= newAmount && newAmount > 0;

      await db.update(
        'Installments',
        {
          'Amount': newAmount,
          'IsPaid': isPaid ? 1 : 0,
          'LastModified': now.toIso8601String(),
        },
        where: 'Id = ?',
        whereArgs: [installmentId],
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating installment amount: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePaymentTransaction(String transactionId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      final now = DateTime.now();

      await db.transaction((txn) async {
        // 1. Get transaction details
        final txns = await txn.query('PaymentTransactions', where: 'Id = ?', whereArgs: [transactionId]);
        if (txns.isEmpty) throw Exception('Transaction not found');
        final tx = txns.first;
        final String instId = tx['InstallmentId'] as String;
        final String invoiceId = tx['InvoiceId'] as String;
        final double amountToRevert = (tx['AmountPaid'] as num).toDouble();

        // 2. Fetch current installment state
        final installments = await txn.query('Installments', where: 'Id = ?', whereArgs: [instId]);
        if (installments.isNotEmpty) {
          final inst = installments.first;
          double currentPaid = (inst['PaidAmount'] as num).toDouble();
          double newPaidAmount = currentPaid - amountToRevert;
          if (newPaidAmount < 0) newPaidAmount = 0;

          // Update Installment
          await txn.update(
            'Installments',
            {
              'PaidAmount': newPaidAmount,
              'IsPaid': 0, // Since we reverted a payment, it's safer to mark as unpaid
              'PaidDate': null,
              'LastModified': now.toIso8601String(),
            },
            where: 'Id = ?',
            whereArgs: [instId],
          );
        }

        // 3. Revert Invoice IsFullyPaid status
        await txn.update(
          'Invoices',
          {'IsFullyPaid': 0, 'LastModified': now.toIso8601String()},
          where: 'Id = ?',
          whereArgs: [invoiceId],
        );

        // 4. Soft-delete the transaction record (so it syncs to Windows)
        await txn.update('PaymentTransactions', {
          'IsDeleted': 1,
          'LastModified': now.toIso8601String(),
        }, where: 'Id = ?', whereArgs: [transactionId]);
      });

      // Enqueue delete and revert
      await OperationQueueServiceMobile.instance.enqueue(
        entityType: 'PaymentTransaction',
        entityId: transactionId,
        operationType: 'Delete',
        entitySnapshot: {'Id': transactionId, 'IsDeleted': 1, 'LastModified': now.toIso8601String()},
        changedFields: 'IsDeleted',
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
