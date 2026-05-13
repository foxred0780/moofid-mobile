import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/database/database_helper.dart';
import '../models/user_model.dart';
import '../models/system_setting_model.dart';
import '../core/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthViewModel extends ChangeNotifier {
  final _dbHelper = DatabaseHelper.instance;
  final _uuid = const Uuid();

  User? _currentUser;
  User? get currentUser => _currentUser;

  static const String _userIdKey = 'logged_in_user_id';

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'Users',
        where: 'Username = ? AND Password = ?',
        whereArgs: [username, password],
      );

      if (maps.isNotEmpty) {
        _currentUser = User.fromMap(maps.first);
        
        // Save session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userIdKey, _currentUser!.id);

        _isLoading = false;
        notifyListeners();
        
        // Trigger background sync automatic link
        SyncService.performSync();

        return true;
      } else {
        _errorMessage = 'اسم المستخدم أو كلمة المرور غير صحيحة';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء تسجيل الدخول: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> createAccount(String username, String password) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final db = await _dbHelper.database;

      // Check if username exists
      final List<Map<String, dynamic>> existing = await db.query(
        'Users',
        where: 'Username = ?',
        whereArgs: [username],
      );

      if (existing.isNotEmpty) {
        _errorMessage = 'اسم المستخدم موجود مسبقاً';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final newUser = User(
        id: _uuid.v4(),
        username: username,
        password: password, // Plain text as per PRD
        createdAt: DateTime.now(),
      );

      await db.insert('Users', newUser.toMap());

      // Create default systemic settings for this user
      final defaultSetting = SystemSetting(
        id: _uuid.v4(),
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        userId: newUser.id,
      );
      await db.insert('SystemSettings', defaultSetting.toMap());

      _currentUser = newUser;

      // Save session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, _currentUser!.id);

      _isLoading = false;
      notifyListeners();
      
      // Trigger background sync automatic link
      SyncService.performSync();

      return true;
    } catch (e) {
      _errorMessage = 'حدث خطأ أثناء إنشاء الحساب: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Auto-login by user ID (used after QR pairing)
  Future<void> loginById(String userId, String userName) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('Users', where: 'Id = ?', whereArgs: [userId]);
      if (maps.isNotEmpty) {
        _currentUser = User.fromMap(maps.first);
        
        // Save session for paired users too
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userIdKey, _currentUser!.id);
      } else {
        // User exists only from bridging
        _currentUser = User(id: userId, username: userName, password: 'paired-session', createdAt: DateTime.now());
      }
      notifyListeners();
      
      // Trigger background sync automatic link
      SyncService.performSync();
    } catch (e) {
      debugPrint('loginById error: $e');
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    notifyListeners();
  }

  /// Initial session check on app startup
  Future<bool> loadStoredSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_userIdKey);
      
      if (userId != null) {
        final db = await _dbHelper.database;
        final maps = await db.query('Users', where: 'Id = ?', whereArgs: [userId]);
        
        if (maps.isNotEmpty) {
          _currentUser = User.fromMap(maps.first);
          notifyListeners();
          
          // Re-trigger sync for restored session
          SyncService.performSync();
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error loading stored session: $e');
    }
    return false;
  }
}
