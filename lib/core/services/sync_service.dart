import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import 'pairing_service.dart';
import 'nsd_service.dart';
import 'app_logger.dart';
import 'notification_service.dart';
import 'signalr_service.dart';
import 'operation_queue_service.dart';

class SyncService {
  /// Check if the paired Windows server is reachable
  static Future<Map<String, dynamic>?> checkServerStatus() async {
    try {
      final pairing = await PairingService.getPairingInfo();
      if (pairing['ip'] == null || pairing['port'] == null) return null;
      final response = await http.get(
        Uri.parse("http://${pairing['ip']}:${pairing['port']}/sync/hello"),
      ).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (_) {}
    return null;
  }

  /// Main sync entry point - returns null on success, error string on failure
  static Future<String?> performSync() async {
    AppLogger.clear();
    AppLogger.info('بدء المزامنة...');
    
    final pairing = await PairingService.getPairingInfo();
    AppLogger.sync('جلب معلومات الاقتران', data: {'ip': pairing['ip'], 'port': pairing['port']});

    if (pairing['ip'] == null) {
      AppLogger.auto('محاولة اكتشاف الخادم تلقائياً...');
      final newIp = await NsdService.discoverServerIp();
      if (newIp == null) {
        AppLogger.error('لا يوجد IP محفوظ ولم يتم اكتشاف الخادم');
        return AppLogger.getFullLog();
      }
      AppLogger.sync('تم اكتشاف الخادم', data: {'ip': newIp});
      pairing['ip'] = newIp;
    }

    final String baseUrl = "http://${pairing['ip']}:${pairing['port']}";
    final String secret = pairing['secret'] ?? "";

    // Initialize Real-time SignalR if not connected
    if (!SignalRService.isConnected) {
      SignalRService.connect(baseUrl);
    }
    
    if (secret.isEmpty) {
      AppLogger.error('المفتاح السري فارغ');
      return AppLogger.getFullLog();
    }
    
    final dbHelper = DatabaseHelper.instance;
    final database = await dbHelper.database;

    try {
      // 0. Bridge session - ensure local user matches server
      try {
        final serverInfo = await checkServerStatus();
        if (serverInfo != null && 
            serverInfo['userId'] != null && 
            serverInfo['userId'] != '00000000-0000-0000-0000-000000000000') {
          await bridgeSession(serverInfo);
          AppLogger.info('تم التحقق من هوية المستخدم بنجاح');
        } else if (serverInfo != null) {
          AppLogger.warn('الخادم متصل ولكن لم يتم تسجيل الدخول على الكمبيوتر');
          return 'يرجى تسجيل الدخول على برنامج الكمبيوتر أولاً لإتمام المزامنة';
        }
      } catch (e) {
        AppLogger.warn('فشل التحقق من الهوية: $e');
      }

      // 1. Get last sync time
      DateTime? lastSync;
      try {
        final meta = await database.rawQuery("SELECT LastSyncTime FROM SyncMetadata LIMIT 1");
        if (meta.isNotEmpty && meta[0]['LastSyncTime'] != null) {
          lastSync = DateTime.parse(meta[0]['LastSyncTime'] as String);
        }
      } catch (_) {}
      AppLogger.info('آخر مزامنة: ${lastSync?.toIso8601String() ?? "أول مزامنة"}');

      // 2. PUSH local queue to server (batch mode with ACK)
      AppLogger.sync('بدء رفع البيانات المحلية (PUSH)...');
      await _pushQueueToServer(database, baseUrl, secret);

      // 3. PULL server's pending queue + data
      AppLogger.sync('بدء سحب البيانات من السيرفر (PULL)...');
      final Map<String, dynamic>? pullResult = await _pullFromServer(database, baseUrl, secret, lastSync);
      
      // Handle server time parsing flexibly (case-insensitive)
      final String? serverTime = pullResult?['serverTime'] ?? pullResult?['ServerTime'];
      final List<String> syncedNames = pullResult?['names'] ?? [];

      // 4. Fetch and process server's pending operations
      await _fetchServerPending(database, baseUrl, secret);

      // 5. Update sync metadata
      final nextSyncTime = serverTime ?? DateTime.now().toIso8601String();
      
      // Notify mobile user
      if (syncedNames.isNotEmpty) {
        String summary = syncedNames.take(3).join("، ");
        if (syncedNames.length > 3) summary += "...";
        NotificationService.showInfo("تم التحديث من الحاسبة", summary);
      }
      final existing = await database.rawQuery("SELECT COUNT(*) as cnt FROM SyncMetadata");
      final count = Sqflite.firstIntValue(existing) ?? 0;
      if (count > 0) {
        await database.execute("UPDATE SyncMetadata SET LastSyncTime = ?", [nextSyncTime]);
      } else {
        await database.insert('SyncMetadata', {
          'ServerId': pairing['id'] ?? '',
          'SyncSecretKey': secret,
          'ServerIp': pairing['ip'] ?? '',
          'LastSyncTime': nextSyncTime,
        });
      }

      // 6. Periodic cleanup
      await OperationQueueServiceMobile.instance.cleanup();

      if (AppLogger.hasErrors) {
        AppLogger.warn('المزامنة انتهت مع ${AppLogger.errorCount} أخطاء');
        return AppLogger.getFullLog();
      }
      
      AppLogger.success('المزامنة اكتملت بنجاح ✓');
      return null;
    } catch (e) {
      AppLogger.error('خطأ عام في المزامنة', e);
      return AppLogger.getFullLog();
    }
  }

  /// PUSH local operation queue to server as a batch with ACK
  static Future<void> _pushQueueToServer(Database db, String baseUrl, String secret) async {
    try {
      final queueService = OperationQueueServiceMobile.instance;
      final pending = await queueService.getPending();

      if (pending.isEmpty) {
        AppLogger.info('PUSH: لا توجد عمليات معلقة في الطابور');
        // Legacy push removed — all changes go through queue now
        return;
      }

      final batchData = await queueService.createBatch();
      final batchId = batchData['batchId'] as String;
      final operations = batchData['operations'] as List<Map<String, dynamic>>;

      AppLogger.info('PUSH: إرسال ${operations.length} عملية من الطابور (Batch: ${batchId.substring(0, 8)}...)');

      final response = await http.post(
        Uri.parse("$baseUrl/sync/queue"),
        headers: {
          "Content-Type": "application/json",
          "Sync-Secret-Key": secret,
        },
        body: jsonEncode({
          "BatchId": batchId,
          "Operations": operations.map((op) => {
            "EntityType": op['EntityType'],
            "EntityId": op['EntityId'],
            "OperationType": op['OperationType'],
            "Data": op['Data'],
            "ChangedFields": op['ChangedFields'] ?? '',
            "VectorClock": op['VectorClock'] ?? '{}',
            "Timestamp": op['Timestamp'],
          }).toList(),
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final serverBatchId = result['BatchId'] as String?;

        // ACK the batch
        if (serverBatchId != null) {
          await queueService.acknowledgeBatch(batchId);
        }

        // Log results
        final results = (result['results'] ?? result['Results']) as List? ?? [];
        int applied = 0, rejected = 0, skipped = 0;
        for (final r in results) {
          final status = r['status'] ?? r['Status'];
          switch (status) {
            case 'Applied': applied++; break;
            case 'Rejected': rejected++; break;
            case 'Skipped': skipped++; break;
          }
        }

        AppLogger.success('PUSH: تم (✓$applied ✗$rejected ⊘$skipped)');
      } else {
        AppLogger.error('PUSH فشل (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      AppLogger.error('PUSH خطأ', e);
    }
  }



  /// Fetch and process server's pending operations
  static Future<void> _fetchServerPending(Database db, String baseUrl, String secret) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/sync/pending"),
        headers: {"Sync-Secret-Key": secret},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        AppLogger.warn('PENDING: فشل جلب العمليات المعلقة (${response.statusCode})');
        return;
      }

      final data = jsonDecode(response.body);
      final batchId = data['BatchId'] as String?;
      final operations = data['Operations'] as List? ?? [];

      if (operations.isEmpty) {
        AppLogger.info('PENDING: لا توجد عمليات معلقة من الخادم');
        return;
      }

      AppLogger.info('PENDING: معالجة ${operations.length} عملية من الخادم');

      await db.execute('PRAGMA foreign_keys = OFF');
      try {
        for (final op in operations) {
          try {
            final entityType = op['EntityType'] as String? ?? '';
            final entityId = op['EntityId'] as String? ?? '';
            final dataStr = op['Data'] as String? ?? '{}';
            final vcStr = op['VectorClock'] as String? ?? '{}';

            final tableName = _getTableName(entityType);
            if (tableName == null || entityId.isEmpty) continue;

            final remoteData = jsonDecode(dataStr) as Map<String, dynamic>;
            final remoteClock = Map<String, int>.from(jsonDecode(vcStr) as Map? ?? {});

            // Get local entity
            final existing = await db.query(tableName, where: 'Id = ?', whereArgs: [entityId]);

            if (existing.isEmpty) {
              // New entity - insert
              final map = _convertKeysForDb(remoteData);
              map['VectorClock'] = vcStr;
              await db.insert(tableName, map, conflictAlgorithm: ConflictAlgorithm.replace);
            } else {
              // Compare vector clocks
              final localVcStr = existing.first['VectorClock'] as String? ?? '{}';
              final localClock = Map<String, int>.from(jsonDecode(localVcStr) as Map? ?? {});
              final comparison = OperationQueueServiceMobile.compareVectorClocks(localClock, remoteClock);

              if (comparison == 'equal') {
                // Same version — skip
              } else if (comparison == 'remote') {
                final map = _convertKeysForDb(remoteData);
                map['VectorClock'] = vcStr;
                await db.update(tableName, map, where: 'Id = ?', whereArgs: [entityId]);
              } else if (comparison == 'conflict') {
                // LWW using timestamps
                final localModified = existing.first['LastModified'] as String?;
                final remoteModified = remoteData['LastModified'] as String? ?? remoteData['lastModified'] as String?;
                
                if (localModified != null && remoteModified != null) {
                  final localTime = DateTime.tryParse(localModified);
                  final remoteTime = DateTime.tryParse(remoteModified);
                  
                  if (remoteTime != null && (localTime == null || remoteTime.isAfter(localTime))) {
                    final map = _convertKeysForDb(remoteData);
                    map['VectorClock'] = vcStr;
                    await db.update(tableName, map, where: 'Id = ?', whereArgs: [entityId]);
                  }
                }
                // Save revision regardless
                await db.insert('RevisionLogs', {
                  'Id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'EntityId': entityId,
                  'EntityType': entityType,
                  'OldData': jsonEncode(existing.first),
                  'NewData': dataStr,
                  'ResolutionType': 'LWW',
                  'WinnerDevice': 'auto',
                  'LoserDevice': 'auto',
                  'ConflictedFields': '',
                  'ResolvedAt': DateTime.now().toUtc().toIso8601String(),
                });
              }
              // else comparison == 'local' → skip
            }
          } catch (e) {
            AppLogger.error('خطأ في معالجة عملية معلقة', e);
          }
        }
      } finally {
        await db.execute('PRAGMA foreign_keys = ON');
      }

      // ACK the batch
      if (batchId != null) {
        try {
          await http.post(
            Uri.parse("$baseUrl/sync/ack"),
            headers: {
              "Content-Type": "application/json",
              "Sync-Secret-Key": secret,
            },
            body: jsonEncode({"BatchId": batchId}),
          ).timeout(const Duration(seconds: 5));
          AppLogger.info('PENDING: ACK sent for batch ${batchId.substring(0, 8)}...');
        } catch (e) {
          AppLogger.warn('PENDING: فشل إرسال ACK: $e');
        }
      }

      AppLogger.success('PENDING: تمت معالجة ${operations.length} عملية');
    } catch (e) {
      AppLogger.error('PENDING خطأ', e);
    }
  }

  /// PULL all server changes to local - returns Map with serverTime and lists of names
  static Future<Map<String, dynamic>?> _pullFromServer(Database db, String baseUrl, String secret, DateTime? lastSync) async {
    try {
      final pullResponse = await http.post(
        Uri.parse("$baseUrl/sync/pull"),
        headers: {
          "Content-Type": "application/json",
          "Sync-Secret-Key": secret,
        },
        body: jsonEncode({"lastSyncTime": lastSync?.toIso8601String()}),
      ).timeout(const Duration(seconds: 15));

      if (pullResponse.statusCode != 200) {
        AppLogger.error('PULL فشل (${pullResponse.statusCode}): ${pullResponse.body}');
        return null;
      }

      final data = jsonDecode(pullResponse.body);
      // Support both PascalCase and camelCase from server
      final serverTime = data['ServerTime'] ?? data['serverTime'];
      AppLogger.info('PULL: وقت الخادم: $serverTime');

      // Disable FK constraints during data processing
      await db.execute('PRAGMA foreign_keys = OFF');
      try {
        List<String> names = [];
        names.addAll(await _upsertTable(db, 'Customers', data['Customers'] ?? data['customers']));
        names.addAll(await _upsertTable(db, 'Invoices', data['Invoices'] ?? data['invoices']));
        
        await _upsertTable(db, 'Installments', data['Installments'] ?? data['installments']);
        await _upsertTable(db, 'PaymentTransactions', data['Transactions'] ?? data['transactions']);
        
        AppLogger.success('PULL: تم استلام ومعالجة ${names.length} سجلات قابلة للتعريف');
        return {
          'serverTime': serverTime,
          'names': names.where((n) => n.isNotEmpty).toList(),
        }; 
      } finally {
        await db.execute('PRAGMA foreign_keys = ON');
      }
    } catch (e) {
      AppLogger.error('PULL خطأ', e);
      return null;
    }
  }

  /// Upsert records using Vector Clock comparison + LWW fallback
  static Future<List<String>> _upsertTable(Database db, String tableName, dynamic records) async {
    if (records == null || records is! List || records.isEmpty) return [];
    
    List<String> syncedNames = [];
    for (var record in records) {
      try {
        final map = _convertKeysForDb(record as Map<String, dynamic>);
        final id = map['Id'];
        if (id == null) continue;

        String? nameHint;
        if (tableName == 'Customers') nameHint = map['Name'];
        if (tableName == 'Invoices') nameHint = map['ItemName'];

        // Check if record exists locally
        final existing = await db.query(tableName, where: 'Id = ?', whereArgs: [id]);
        
        bool didUpdate = false;
        if (existing.isEmpty) {
          // New record - insert it
          await db.insert(tableName, map, conflictAlgorithm: ConflictAlgorithm.replace);
          didUpdate = true;
        } else {
          // Compare vector clocks first
          final localVcStr = existing.first['VectorClock'] as String? ?? '{}';
          final remoteVcStr = map['VectorClock'] as String? ?? '{}';

          Map<String, int> localClock = {};
          Map<String, int> remoteClock = {};
          try { localClock = Map<String, int>.from(jsonDecode(localVcStr)); } catch (_) {}
          try { remoteClock = Map<String, int>.from(jsonDecode(remoteVcStr)); } catch (_) {}

          final comparison = OperationQueueServiceMobile.compareVectorClocks(localClock, remoteClock);

          if (comparison == 'equal') {
            // Both sides have the same version — skip (no change needed)
            continue;
          } else if (comparison == 'remote') {
            // Remote dominates → apply
            await db.update(tableName, map, where: 'Id = ?', whereArgs: [id]);
            didUpdate = true;
          } else if (comparison == 'conflict') {
            // True conflict → LWW with timestamps
            final localModified = existing.first['LastModified'] as String?;
            final remoteModified = map['LastModified'] as String?;
            
            if (localModified != null && remoteModified != null) {
              final localTime = DateTime.tryParse(localModified);
              final remoteTime = DateTime.tryParse(remoteModified);
              
              if (localTime != null && remoteTime != null && remoteTime.isAfter(localTime)) {
                await db.update(tableName, map, where: 'Id = ?', whereArgs: [id]);
                didUpdate = true;
              }
            } else {
              // Can't compare - use remote (safe fallback)
              await db.update(tableName, map, where: 'Id = ?', whereArgs: [id]);
              didUpdate = true;
            }

            // Save revision log for the conflict
            try {
              await db.insert('RevisionLogs', {
                'Id': DateTime.now().millisecondsSinceEpoch.toString() + id.toString(),
                'EntityId': id.toString(),
                'EntityType': tableName.replaceAll(r's$', ''),
                'OldData': jsonEncode(existing.first),
                'NewData': jsonEncode(map),
                'ResolutionType': 'LWW',
                'WinnerDevice': 'auto',
                'LoserDevice': 'auto',
                'ConflictedFields': '',
                'ResolvedAt': DateTime.now().toUtc().toIso8601String(),
              });
            } catch (_) {}
          }
          // else comparison == 'local' → skip (local dominates)
        }

        if (didUpdate && nameHint != null) {
          syncedNames.add(nameHint);
        }
      } catch (e) {
        AppLogger.error('خطأ في معالجة سجل ($tableName)', e);
      }
    }
    
    if (syncedNames.isNotEmpty) {
      AppLogger.info('$tableName: ${syncedNames.length} سجل جديد/محدث');
    }
    return syncedNames;
  }

  /// Ensures a local user exists matching the paired Windows user.
  static Future<void> bridgeSession(Map<String, dynamic> serverInfo) async {
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;
    final userId = serverInfo['userId'];
    final userName = serverInfo['userName'] ?? "User";

    // Check if user exists locally by ID
    final existingById = await db.query('Users', where: 'Id = ?', whereArgs: [userId]);
    
    if (existingById.isEmpty) {
      // Check if username exists with a different ID
      final existingByName = await db.query('Users', where: 'Username = ?', whereArgs: [userName]);
      
      if (existingByName.isNotEmpty) {
        final oldId = existingByName.first['Id'];
        
        await db.execute('PRAGMA foreign_keys = OFF');
        try {
          await db.transaction((txn) async {
            await txn.update('Customers', {'UserId': userId}, where: 'UserId = ?', whereArgs: [oldId]);
            await txn.update('PaymentTransactions', {'UserId': userId}, where: 'UserId = ?', whereArgs: [oldId]);
            await txn.update('SystemSettings', {'Id': userId, 'UserId': userId}, where: 'UserId = ?', whereArgs: [oldId]);
            await txn.update('Users', {'Id': userId}, where: 'Id = ?', whereArgs: [oldId]);
          });
        } finally {
          await db.execute('PRAGMA foreign_keys = ON');
        }
      } else {
        // New user entirely
        await db.insert('Users', {
          'Id': userId,
          'Username': userName,
          'Password': userName, // Use username as default password for paired sessions
          'CreatedAt': DateTime.now().toIso8601String(),
        });
        
        await db.execute('PRAGMA foreign_keys = OFF');
        try {
          await db.insert('SystemSettings', {
            'Id': userId,
            'UserId': userId,
            'CreatedAt': DateTime.now().toIso8601String(),
            'LastModified': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
        await db.execute('PRAGMA foreign_keys = ON');
      }
    }
  }

  /// Converts server's JSON keys to PascalCase DB column names and normalizes GUIDs
  static Map<String, dynamic> _convertKeysForDb(Map<String, dynamic> input) {
    final Map<String, dynamic> result = {};
    for (final entry in input.entries) {
      final key = entry.key[0].toUpperCase() + entry.key.substring(1);
      var value = entry.value;
      
      // Normalize GUIDs to lowercase to prevent case-sensitive mismatches in SQLite
      if (value is String && (key == 'Id' || key == 'CustomerId' || key == 'InvoiceId' || key == 'InstallmentId' || key == 'UserId')) {
        value = value.toLowerCase();
      }
      
      result[key] = value;
    }
    return result;
  }

  static String? _getTableName(String entityType) {
    switch (entityType) {
      case 'Customer': return 'Customers';
      case 'Invoice': return 'Invoices';
      case 'Installment': return 'Installments';
      case 'PaymentTransaction': return 'PaymentTransactions';
      default: return null;
    }
  }
}
