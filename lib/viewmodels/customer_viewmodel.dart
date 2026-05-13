import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/database/database_helper.dart';
import '../models/customer_model.dart';
import 'auth_viewmodel.dart';
import '../core/services/sync_service.dart';
import '../core/services/operation_queue_service.dart';
import '../core/services/app_logger.dart';

class CustomerViewModel extends ChangeNotifier {
  final _dbHelper = DatabaseHelper.instance;
  final AuthViewModel _authViewModel;
  final _uuid = const Uuid();

  List<Customer> _customers = [];
  List<Customer> get customers => _customers;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _searchQuery = '';

  CustomerViewModel(this._authViewModel) {
    fetchCustomers();
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    fetchCustomers();
  }

  Future<void> fetchCustomers() async {
    final user = _authViewModel.currentUser;
    if (user == null) {
      _customers = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      List<Map<String, dynamic>> maps;

      if (_searchQuery.isEmpty) {
        maps = await db.rawQuery('''
          SELECT c.*, 
                 SUM(CASE WHEN inv.Currency = 'IQD' THEN i.Amount - i.PaidAmount ELSE 0 END) AS TotalDebtIQD,
                 SUM(CASE WHEN inv.Currency = 'USD' THEN i.Amount - i.PaidAmount ELSE 0 END) AS TotalDebtUSD
          FROM Customers c
          LEFT JOIN Invoices inv ON c.Id = inv.CustomerId AND inv.IsFullyPaid = 0 AND (inv.IsDeleted = 0 OR inv.IsDeleted IS NULL)
          LEFT JOIN Installments i ON inv.Id = i.InvoiceId AND i.IsPaid = 0 AND (i.IsDeleted = 0 OR i.IsDeleted IS NULL)
          WHERE c.UserId = ? AND (c.IsDeleted = 0 OR c.IsDeleted IS NULL)
          GROUP BY c.Id
          ORDER BY c.CreatedAt DESC
        ''', [user.id]);
      } else {
        maps = await db.rawQuery('''
          SELECT c.*, 
                 SUM(CASE WHEN inv.Currency = 'IQD' THEN i.Amount - i.PaidAmount ELSE 0 END) AS TotalDebtIQD,
                 SUM(CASE WHEN inv.Currency = 'USD' THEN i.Amount - i.PaidAmount ELSE 0 END) AS TotalDebtUSD
          FROM Customers c
          LEFT JOIN Invoices inv ON c.Id = inv.CustomerId AND inv.IsFullyPaid = 0 AND (inv.IsDeleted = 0 OR inv.IsDeleted IS NULL)
          LEFT JOIN Installments i ON inv.Id = i.InvoiceId AND i.IsPaid = 0 AND (i.IsDeleted = 0 OR i.IsDeleted IS NULL)
          WHERE c.UserId = ? AND (c.IsDeleted = 0 OR c.IsDeleted IS NULL) AND (c.Name LIKE ? OR c.Phone LIKE ?)
          GROUP BY c.Id
          ORDER BY c.CreatedAt DESC
        ''', [user.id, '%$_searchQuery%', '%$_searchQuery%']);
      }

      _customers = maps.map((e) => Customer.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error fetching customers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _lastError = '';
  String get lastError => _lastError;

  Future<bool> addCustomer({
    required String name,
    required String phone,
    String address = '',
    String notes = '',
  }) async {
    var user = _authViewModel.currentUser;
    if (user == null) {
      _lastError = 'لا يوجد مستخدم مسجل دخول';
      return false;
    }

    try {
      final newCustomer = Customer(
        id: _uuid.v4(),
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        userId: user.id,
        name: name,
        phone: phone,
        address: address,
        notes: notes,
      );

      final db = await _dbHelper.database;
      await db.insert('Customers', newCustomer.toMap());
      
      // Enqueue to sync queue
      await OperationQueueServiceMobile.instance.enqueue(
        entityType: 'Customer',
        entityId: newCustomer.id,
        operationType: 'Create',
        entitySnapshot: newCustomer.toMap(),
        changedFields: 'Name,Phone,Address,Notes',
      );
      
      AppLogger.userAction('إضافة عميل جديد', data: {'Name': name, 'Phone': phone, 'UserId': user.id});
      
      await fetchCustomers();
      
      // Trigger immediate sync
      SyncService.performSync();
      
      return true;
    } catch (e) {
      AppLogger.error('فشل إضافة العميل', e);
      debugPrint('Error adding customer: $e');
      
      // If FK error, try to find correct user ID
      if (e.toString().contains('FOREIGN KEY') || e.toString().contains('787')) {
        try {
          final db = await _dbHelper.database;
          final users = await db.query('Users', where: 'Username = ?', whereArgs: [user.username]);
          if (users.isNotEmpty) {
            final correctId = users.first['Id'] as String;
            _lastError = 'معرف المستخدم تغير بعد المزامنة. جاري التصحيح...';
            
            // Re-login with correct ID
            await _authViewModel.loginById(correctId, user.username);
            
            // Retry with correct ID
            final retryCustomer = Customer(
              id: _uuid.v4(),
              createdAt: DateTime.now(),
              lastModified: DateTime.now(),
              userId: correctId,
              name: name,
              phone: phone,
              address: address,
              notes: notes,
            );
            await db.insert('Customers', retryCustomer.toMap());
            await fetchCustomers();
            return true;
          }
        } catch (e2) {
          _lastError = 'خطأ في التصحيح: $e2';
        }
      }
      
      _lastError = '$e';
      return false;
    }
  }

  Future<bool> updateCustomer(
    String id, {
    required String name,
    required String phone,
    String address = '',
    String notes = '',
  }) async {
    final user = _authViewModel.currentUser;
    if (user == null) return false;

    try {
      final db = await _dbHelper.database;
      
      // Get existing customer to preserve CreatedAt
      final existing = await db.query('Customers', where: 'Id = ? AND UserId = ?', whereArgs: [id, user.id]);
      if (existing.isEmpty) return false;
      
      final oldCustomer = Customer.fromMap(existing.first);

      final updatedCustomer = Customer(
        id: oldCustomer.id,
        createdAt: oldCustomer.createdAt,
        lastModified: DateTime.now(),
        userId: user.id,
        name: name,
        phone: phone,
        address: address,
        notes: notes,
      );

      await db.update(
        'Customers',
        updatedCustomer.toMap(),
        where: 'Id = ? AND UserId = ?',
        whereArgs: [updatedCustomer.id, user.id],
      );
      
      // Enqueue to sync queue
      await OperationQueueServiceMobile.instance.enqueue(
        entityType: 'Customer',
        entityId: updatedCustomer.id,
        operationType: 'Update',
        entitySnapshot: updatedCustomer.toMap(),
        changedFields: 'Name,Phone,Address,Notes',
      );
      
      AppLogger.userAction('تحديث بيانات عميل', data: {'Id': id, 'Name': name});
      
      await fetchCustomers();
      
      // Trigger immediate sync
      SyncService.performSync();
      
      return true;
    } catch (e) {
      AppLogger.error('فشل تحديث بيانات العميل', e);
      debugPrint('Error updating customer: $e');
      return false;
    }
  }

  Future<bool> deleteCustomer(String id, String confirmName) async {
    final user = _authViewModel.currentUser;
    if (user == null) return false;

    try {
      final db = await _dbHelper.database;
      final existing = await db.query('Customers', where: 'Id = ? AND UserId = ?', whereArgs: [id, user.id]);
      if (existing.isEmpty) return false;

      final customer = Customer.fromMap(existing.first);
      if (customer.name != confirmName) return false;

      final now = DateTime.now().toIso8601String();
      // Soft delete: mark as deleted (syncable) instead of physical delete
      await db.update('Customers', {'IsDeleted': 1, 'LastModified': now}, where: 'Id = ?', whereArgs: [id]);
      
      // Enqueue customer delete
      await OperationQueueServiceMobile.instance.enqueue(
        entityType: 'Customer',
        entityId: id,
        operationType: 'Delete',
        entitySnapshot: {'Id': id, 'IsDeleted': 1, 'LastModified': now},
        changedFields: 'IsDeleted',
      );
      
      // Cascade soft delete to related records
      final invoices = await db.query('Invoices', where: 'CustomerId = ?', whereArgs: [id]);
      for (var inv in invoices) {
        await db.update('Invoices', {'IsDeleted': 1, 'LastModified': now}, where: 'Id = ?', whereArgs: [inv['Id']]);
        await OperationQueueServiceMobile.instance.enqueue(
          entityType: 'Invoice', entityId: inv['Id'] as String,
          operationType: 'Delete', entitySnapshot: {'Id': inv['Id'], 'IsDeleted': 1, 'LastModified': now},
          changedFields: 'IsDeleted',
        );
        
        await db.update('Installments', {'IsDeleted': 1, 'LastModified': now}, where: 'InvoiceId = ?', whereArgs: [inv['Id']]);
        await db.update('PaymentTransactions', {'IsDeleted': 1, 'LastModified': now}, where: 'InvoiceId = ?', whereArgs: [inv['Id']]);
      }

      AppLogger.userAction('حذف عميل', data: {'Id': id, 'Name': confirmName});
      
      await fetchCustomers();
      
      // Trigger immediate sync
      SyncService.performSync();
      
      return true;
    } catch (e) {
      AppLogger.error('فشل حذف العميل', e);
      debugPrint('Error deleting customer: $e');
      return false;
    }
  }
}
