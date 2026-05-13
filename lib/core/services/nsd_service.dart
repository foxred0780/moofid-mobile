import 'dart:async';
import 'package:nsd/nsd.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NsdService {
  static const String serviceType = '_moofid-sync._tcp';

  /// Periodically searches for the sync server if the IP is unknown or changed.
  static Future<String?> discoverServerIp() async {
    final discovery = await startDiscovery(serviceType);
    final completer = Completer<String?>();

    discovery.addServiceListener((service, status) {
      if (status == ServiceStatus.found) {
        // We found a service! We take the first available IP.
        final ip = service.addresses?.first.address;
        if (ip != null) {
          updateStoredIp(ip);
          completer.complete(ip);
          stopDiscovery(discovery);
        }
      }
    });

    // Timeout after 5 seconds
    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
      stopDiscovery(discovery);
      return null;
    });
  }

  static Future<void> updateStoredIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_server_ip', ip);
  }
}
