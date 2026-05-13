import 'package:shared_preferences/shared_preferences.dart';

class PairingService {
  static const String _keyServerIp = 'sync_server_ip';
  static const String _keyServerPort = 'sync_server_port';
  static const String _keyServerId = 'sync_server_id';
  static const String _keySecretKey = 'sync_secret_key';
  static const String _keyIsPaired = 'is_paired';

  static Future<void> savePairing(String payload) async {
    // Expected format: ID|Secret|IP|Port
    final parts = payload.split('|');
    if (parts.length != 4) throw Exception('Invalid pairing data format');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerId, parts[0]);
    await prefs.setString(_keySecretKey, parts[1]);
    await prefs.setString(_keyServerIp, parts[2]);
    await prefs.setString(_keyServerPort, parts[3]);
    await prefs.setBool(_keyIsPaired, true);
  }

  static Future<Map<String, String?>> getPairingInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'id': prefs.getString(_keyServerId),
      'secret': prefs.getString(_keySecretKey),
      'ip': prefs.getString(_keyServerIp),
      'port': prefs.getString(_keyServerPort),
    };
  }

  static Future<bool> isPaired() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsPaired) ?? false;
  }

  static Future<void> clearPairing() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServerId);
    await prefs.remove(_keySecretKey);
    await prefs.remove(_keyServerIp);
    await prefs.remove(_keyServerPort);
    await prefs.setBool(_keyIsPaired, false);
  }
}
