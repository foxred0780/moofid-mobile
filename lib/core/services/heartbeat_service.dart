import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'app_logger.dart';
import 'package:flutter/foundation.dart';

/// Layer 1 + Layer 6: Device Discovery & Health Monitor (Android side).
/// Sends UDP heartbeats every 10 seconds, listens for Windows server heartbeats,
/// and detects connection/disconnection events.
class HeartbeatServiceMobile {
  static const int heartbeatPort = 5051;
  static const int intervalMs = 10000;    // 10 seconds
  static const int timeoutMs = 30000;     // 30 seconds → offline

  static final HeartbeatServiceMobile instance = HeartbeatServiceMobile._();
  HeartbeatServiceMobile._();

  RawDatagramSocket? _socket;
  Timer? _sendTimer;
  Timer? _monitorTimer;
  DateTime _lastRemoteHeartbeat = DateTime.fromMillisecondsSinceEpoch(0);

  // ── State ──
  bool _isRemoteOnline = false;
  bool get isRemoteOnline => _isRemoteOnline;
  String? remoteDeviceName;
  String? remoteIp;
  int? remotePort;
  int remotePendingOps = 0;
  DateTime get lastHeartbeatReceived => _lastRemoteHeartbeat;

  // ── Callbacks ──
  VoidCallback? onDeviceConnected;
  VoidCallback? onDeviceDisconnected;
  VoidCallback? onDeviceReconnected;

  /// Value notifier for UI binding
  final ValueNotifier<bool> connectionStatus = ValueNotifier(false);

  Future<void> start() async {
    if (_socket != null) return;

    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, heartbeatPort, reuseAddress: true);
      _socket!.broadcastEnabled = true;

      // Listen for incoming heartbeats
      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram == null) return;

          try {
            final json = jsonDecode(utf8.decode(datagram.data));
            final device = json['device'] as String?;

            // Ignore our own heartbeats
            if (device == 'android') return;

            final wasOffline = !_isRemoteOnline;

            _lastRemoteHeartbeat = DateTime.now();
            _isRemoteOnline = true;
            connectionStatus.value = true;
            remoteDeviceName = json['name'] as String?;
            remoteIp = json['ip'] as String?;
            remotePort = json['port'] as int?;
            remotePendingOps = json['pendingOps'] as int? ?? 0;

            if (wasOffline) {
              AppLogger.network('تم الاتصال بخادم وندوز', data: {'Name': remoteDeviceName, 'IP': remoteIp});
              debugPrint('[Heartbeat] Windows device CONNECTED: $remoteDeviceName @ $remoteIp');
              onDeviceConnected?.call();
              onDeviceReconnected?.call();
            }
          } catch (e) {
            AppLogger.error('خطأ في حزمة Heartbeat', e);
            debugPrint('[Heartbeat] Parse error: $e');
          }
        }
      });

      // Start sending our heartbeats
      _sendTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (_) => _sendHeartbeat());

      // Start monitoring timeout
      _monitorTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkTimeout());

      debugPrint('[Heartbeat] Mobile service started on port $heartbeatPort');
    } catch (e) {
      AppLogger.error('فشل تشغيل خدمة Heartbeat', e);
      debugPrint('[Heartbeat] Start error: $e');
    }
  }

  void _sendHeartbeat() {
    if (_socket == null) return;

    try {
      final heartbeat = jsonEncode({
        'device': 'android',
        'name': 'Moofid-Mobile',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });

      final bytes = utf8.encode(heartbeat);
      _socket!.send(bytes, InternetAddress('255.255.255.255'), heartbeatPort);
    } catch (e) {
      // AppLogger.error('فشل إرسال Heartbeat', e); // Don't spam error log with UDP fails
      debugPrint('[Heartbeat] Send error: $e');
    }
  }

  void _checkTimeout() {
    if (_isRemoteOnline && DateTime.now().difference(_lastRemoteHeartbeat).inMilliseconds > timeoutMs) {
      _isRemoteOnline = false;
      connectionStatus.value = false;
      AppLogger.network('فقد الاتصال بخادم وندوز (Timeout)', data: {'Device': remoteDeviceName});
      debugPrint('[Heartbeat] Windows device DISCONNECTED (timeout)');
      onDeviceDisconnected?.call();
    }
  }

  void stop() {
    _sendTimer?.cancel();
    _monitorTimer?.cancel();
    _socket?.close();
    _socket = null;
    _sendTimer = null;
    _monitorTimer = null;
    _isRemoteOnline = false;
    connectionStatus.value = false;
    debugPrint('[Heartbeat] Mobile service stopped.');
  }
}
