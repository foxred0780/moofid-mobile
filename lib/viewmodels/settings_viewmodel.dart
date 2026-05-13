import 'package:flutter/material.dart';
import '../core/database/database_helper.dart';
import '../models/system_setting_model.dart';
import 'auth_viewmodel.dart';
import '../core/services/operation_queue_service.dart';

class SettingsViewModel extends ChangeNotifier {
  final _dbHelper = DatabaseHelper.instance;
  final AuthViewModel _authViewModel;

  SystemSetting? _settings;
  SystemSetting? get settings => _settings;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  SettingsViewModel(this._authViewModel) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final user = _authViewModel.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'SystemSettings',
        where: 'UserId = ?',
        whereArgs: [user.id],
      );

      if (maps.isNotEmpty) {
        _settings = SystemSetting.fromMap(maps.first);
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSettings({
    String? storeName,
    String? storePhone,
    String? storeAddress,
    String? defaultCurrency,
    double? exchangeRate,
    bool? enableOverdueAlerts,
  }) async {
    if (_settings == null || _authViewModel.currentUser == null) return;

    final updatedSetting = SystemSetting(
      id: _settings!.id,
      createdAt: _settings!.createdAt,
      lastModified: DateTime.now(),
      userId: _settings!.userId,
      storeName: storeName ?? _settings!.storeName,
      storePhone: storePhone ?? _settings!.storePhone,
      storeAddress: storeAddress ?? _settings!.storeAddress,
      defaultCurrency: defaultCurrency ?? _settings!.defaultCurrency,
      exchangeRate: exchangeRate ?? _settings!.exchangeRate,
      enableOverdueAlerts: enableOverdueAlerts ?? _settings!.enableOverdueAlerts,
    );

    try {
      final db = await _dbHelper.database;
      await db.update(
        'SystemSettings',
        updatedSetting.toMap(),
        where: 'Id = ?',
        whereArgs: [updatedSetting.id],
      );
      _settings = updatedSetting;
      
      // Enqueue to sync queue
      await OperationQueueServiceMobile.instance.enqueue(
        entityType: 'SystemSetting',
        entityId: updatedSetting.id,
        operationType: 'Update',
        entitySnapshot: updatedSetting.toMap(),
        changedFields: 'StoreName,StorePhone,StoreAddress,DefaultCurrency,ExchangeRate,EnableOverdueAlerts',
      );
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating settings: $e');
    }
  }
}
