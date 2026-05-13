import 'package:signalr_netcore/signalr_client.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/foundation.dart';
import 'sync_service.dart';
import 'notification_service.dart';
import 'heartbeat_service.dart';
import 'app_logger.dart';
import 'operation_queue_service.dart';

class SignalRService {
  static HubConnection? _hubConnection;
  static bool _isConnected = false;

  static Future<void> connect(String baseUrl) async {
    if (_hubConnection != null && _isConnected) return;
    
    if (_hubConnection != null) {
      await stop();
    }

    final hubUrl = "$baseUrl/sync/realtime";
    AppLogger.network('بدء الاتصال بـ SignalR', data: {'Url': hubUrl});

    _hubConnection = HubConnectionBuilder()
        .withUrl(hubUrl)
        .withAutomaticReconnect()
        .build();

    // Real-time data update from Windows (existing)
    _hubConnection?.on("DataUpdate", _handleDataUpdate);

    // New: Queue update — Windows has pending operations for us
    _hubConnection?.on("QueueUpdate", _handleQueueUpdate);

    // New: Conflict detected — server resolved a conflict we should know about
    _hubConnection?.on("ConflictResolved", _handleConflictResolved);
    
    _hubConnection?.onreconnecting(({error}) {
      _isConnected = false;
      AppLogger.network('إعادة الاتصال بـ SignalR...', data: {'Error': error});
      debugPrint("[SignalR] Reconnecting... $error");
    });

    _hubConnection?.onreconnected(({connectionId}) {
      _isConnected = true;
      AppLogger.network('تم إعادة الاتصال بـ SignalR', data: {'ConnectionId': connectionId});
      debugPrint("[SignalR] Reconnected! ID: $connectionId");
      NotificationService.showInfo("تم استعادة الاتصال", "متصل الآن بالمزامنة اللحظية للحاسبة");
      
      // On reconnection, trigger a full sync to catch up
      _triggerSync();
    });

    try {
      await _hubConnection?.start();
      _isConnected = true;
      AppLogger.network('تم الاتصال بـ SignalR بنجاح');
      debugPrint("[SignalR] Connected successfully.");
      NotificationService.showInfo("متصل", "تم تفعيل المزامنة اللحظية بنجاح");

      // Also start heartbeat service when SignalR connects
      HeartbeatServiceMobile.instance.start();
      
      // Set up heartbeat reconnection callback
      HeartbeatServiceMobile.instance.onDeviceReconnected = () {
        debugPrint("[SignalR] Heartbeat detected Windows reconnection — triggering sync");
        _triggerSync();
      };
    } catch (e) {
      _isConnected = false;
      debugPrint("[SignalR] Connection error: $e");
    }

    _hubConnection?.onclose(({error}) {
      _isConnected = false;
      debugPrint("[SignalR] Connection closed. $error");
    });
  }

  static Future<void> stop() async {
    await _hubConnection?.stop();
    _hubConnection = null;
    _isConnected = false;
    HeartbeatServiceMobile.instance.stop();
  }

  /// Handle DataUpdate signal — Windows made data changes
  static void _handleDataUpdate(List<Object?>? arguments) async {
    debugPrint("[SignalR] Received DataUpdate signal from server.");
    await _triggerSync();
  }

  /// Handle QueueUpdate signal — Windows has queued operations for us
  static void _handleQueueUpdate(List<Object?>? arguments) async {
    debugPrint("[SignalR] Received QueueUpdate — server has pending operations.");
    
    final pendingCount = await OperationQueueServiceMobile.instance.getPendingCount();
    debugPrint("[SignalR] Local pending: $pendingCount, Server signaled queue update.");
    
    await _triggerSync();
  }

  /// Handle ConflictResolved signal — server resolved a conflict
  static void _handleConflictResolved(List<Object?>? arguments) async {
    debugPrint("[SignalR] Received ConflictResolved signal.");
    
    String details = "";
    if (arguments != null && arguments.isNotEmpty) {
      details = arguments.first?.toString() ?? "";
    }
    
    NotificationService.showInfo("تم حل تعارض", details.isNotEmpty ? details : "تم حل تعارض في البيانات تلقائياً");
    
    // Sync to get the resolved data
    await _triggerSync();
  }

  /// Centralized sync trigger with haptic feedback
  static Future<void> _triggerSync() async {
    await SyncService.performSync();

    // Haptic Feedback (Vibration)
    if ((await Vibration.hasVibrator()) == true) {
      Vibration.vibrate(duration: 300);
    }
  }

  static bool get isConnected => _isConnected;
}
