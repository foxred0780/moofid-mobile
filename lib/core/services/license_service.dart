import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';

enum LicenseStatus {
  licensed,
  trialActive,
  trialExpired,
  trialNotStarted,
}

class LicenseService {
  // مفتاح سري قوي (يجب تغييره إلى شيء معقد جداً ولا تشاركه أبداً مع أي شخص)
  static const String _secretKey = "Mofid_Offline_App_Secret_Key_2026"; 
  static const String _licenseStorageKey = "app_activation_license_key";
  static const String _firstOpenDateKey = "app_first_open_date";
  static const String _lastOpenDateKey = "app_last_open_date";
  
  // مدة الفترة التجريبية بالأيام (تم تغييرها إلى يوم واحد)
  static const int _trialDays = 1; 

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// جلب الرقم المميز للجهاز (Device ID)
  Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? "unknown_ios_device";
      } else if (Platform.isWindows) {
        WindowsDeviceInfo windowsInfo = await _deviceInfo.windowsInfo;
        return windowsInfo.deviceId;
      }
      return "unsupported_device";
    } catch (e) {
      return "error_getting_device_id";
    }
  }

  /// توليد كود التفعيل المتوقع بناءً على رقم الجهاز
  String _generateExpectedKey(String deviceId) {
    var key = utf8.encode(_secretKey);
    var bytes = utf8.encode(deviceId);

    var hmacSha256 = Hmac(sha256, key); // HMAC-SHA256
    var digest = hmacSha256.convert(bytes);

    return digest.toString().substring(0, 12).toUpperCase();
  }

  /// التحقق من حالة الترخيص الحالية للتطبيق
  Future<LicenseStatus> getLicenseStatus() async {
    // 1. التحقق أولاً من وجود تفعيل دائم
    String? storedLicense = await _secureStorage.read(key: _licenseStorageKey);
    if (storedLicense != null && storedLicense.isNotEmpty) {
      String deviceId = await getDeviceId();
      if (storedLicense == _generateExpectedKey(deviceId)) {
        return LicenseStatus.licensed; // التطبيق مفعل تفعيل دائم
      }
    }

    // 2. التحقق من الفترة التجريبية
    String? firstOpenStr = await _secureStorage.read(key: _firstOpenDateKey);
    String? lastOpenStr = await _secureStorage.read(key: _lastOpenDateKey);

    // إذا لم يبدأ المستخدم التجربة بعد
    if (firstOpenStr == null) {
      return LicenseStatus.trialNotStarted;
    }

    DateTime now = DateTime.now();
    DateTime firstOpenDate = DateTime.parse(firstOpenStr);
    
    // حماية ضد التلاعب بالوقت
    if (lastOpenStr != null) {
      DateTime lastOpenDate = DateTime.parse(lastOpenStr);
      if (now.isBefore(lastOpenDate)) {
        return LicenseStatus.trialExpired; // اكتشفنا تلاعب، ننهي التجربة
      }
    }

    // تحديث تاريخ آخر فتح للتطبيق
    await _secureStorage.write(key: _lastOpenDateKey, value: now.toIso8601String());

    // حساب الأيام المتبقية
    int daysPassed = now.difference(firstOpenDate).inDays;
    
    if (daysPassed < _trialDays) {
      return LicenseStatus.trialActive; // لا زال في الفترة التجريبية
    } else {
      return LicenseStatus.trialExpired; // انتهت التجربة
    }
  }

  /// بدء الفترة التجريبية بناءً على طلب المستخدم
  Future<void> startTrial() async {
    DateTime now = DateTime.now();
    await _secureStorage.write(key: _firstOpenDateKey, value: now.toIso8601String());
    await _secureStorage.write(key: _lastOpenDateKey, value: now.toIso8601String());
  }

  /// تفعيل التطبيق بالكود المدخل من قبل المستخدم
  Future<bool> activateApp(String enteredKey) async {
    String deviceId = await getDeviceId();
    String expectedKey = _generateExpectedKey(deviceId);

    String cleanEnteredKey = enteredKey.trim().toUpperCase();

    if (cleanEnteredKey == expectedKey) {
      await _secureStorage.write(key: _licenseStorageKey, value: expectedKey);
      return true;
    }
    return false;
  }

  /// إلغاء التفعيل 
  Future<void> deactivateApp() async {
    await _secureStorage.delete(key: _licenseStorageKey);
  }
}
