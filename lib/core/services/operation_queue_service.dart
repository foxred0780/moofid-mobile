import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';

/// Layer 2: Offline Operation Queue (Android side).
/// Records every data mutation as a SyncOperation, manages vector clocks,
/// handles batch creation, and provides pending operations for sync.
class OperationQueueServiceMobile {
  static final OperationQueueServiceMobile instance = OperationQueueServiceMobile._();
  OperationQueueServiceMobile._();

  static const _uuid = Uuid();
  static const String localDeviceId = 'android';

  /// Records a data mutation. Call this after every Create/Update/Delete.
  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operationType,
    required Map<String, dynamic> entitySnapshot,
    String changedFields = '',
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final vectorClock = await _getAndIncrementClock(db, entityId, entityType);
      final clockJson = jsonEncode(vectorClock);

      await db.insert('SyncOperations', {
        'Id': _uuid.v4(),
        'Timestamp': DateTime.now().toUtc().toIso8601String(),
        'DeviceId': localDeviceId,
        'EntityType': entityType,
        'EntityId': entityId,
        'OperationType': operationType,
        'Data': jsonEncode(entitySnapshot),
        'ChangedFields': changedFields,
        'Status': 'Pending',
        'VectorClock': clockJson,
      });

      // CRITICAL: Also update the entity's own VectorClock column
      // so that PULL comparisons know this entity was locally modified
      final tableName = _getTableName(entityType);
      if (tableName != null) {
        await db.update(
          tableName,
          {'VectorClock': clockJson},
          where: 'Id = ?',
          whereArgs: [entityId],
        );
      }

      debugPrint('[Queue] Enqueued $operationType on $entityType/$entityId (VC: $clockJson)');
    } catch (e) {
      debugPrint('[Queue] Enqueue error: $e');
    }
  }

  /// Gets all pending operations, ordered by timestamp.
  Future<List<Map<String, dynamic>>> getPending() async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
      'SyncOperations',
      where: "Status = 'Pending'",
      orderBy: 'Timestamp ASC',
    );
  }

  /// Creates a batch from pending operations and assigns a BatchId.
  Future<Map<String, dynamic>> createBatch() async {
    final db = await DatabaseHelper.instance.database;
    final batchId = _uuid.v4();

    final pending = await db.query(
      'SyncOperations',
      where: "Status = 'Pending'",
      orderBy: 'Timestamp ASC',
    );

    for (final op in pending) {
      await db.update(
        'SyncOperations',
        {'BatchId': batchId},
        where: 'Id = ?',
        whereArgs: [op['Id']],
      );
    }

    return {'batchId': batchId, 'operations': pending};
  }

  /// Marks a batch as synced after receiving ACK.
  Future<void> acknowledgeBatch(String batchId) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'SyncOperations',
      {
        'Status': 'Synced',
        'AcknowledgedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: "BatchId = ? AND Status = 'Pending'",
      whereArgs: [batchId],
    );
    debugPrint('[Queue] Batch $batchId acknowledged');
  }

  /// Marks a single operation as synced.
  Future<void> markSynced(String operationId) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'SyncOperations',
      {
        'Status': 'Synced',
        'AcknowledgedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'Id = ?',
      whereArgs: [operationId],
    );
  }

  /// Cleans up synced operations older than the specified number of days.
  Future<void> cleanup({int olderThanDays = 7}) async {
    final db = await DatabaseHelper.instance.database;
    final cutoff = DateTime.now().toUtc().subtract(Duration(days: olderThanDays)).toIso8601String();
    final deleted = await db.delete(
      'SyncOperations',
      where: "Status = 'Synced' AND AcknowledgedAt < ?",
      whereArgs: [cutoff],
    );
    if (deleted > 0) {
      debugPrint('[Queue] Cleaned up $deleted old synced operations');
    }
  }

  /// Returns count of pending operations.
  Future<int> getPendingCount() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery("SELECT COUNT(*) as cnt FROM SyncOperations WHERE Status = 'Pending'");
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Gets and increments the vector clock for an entity.
  Future<Map<String, int>> _getAndIncrementClock(Database db, String entityId, String entityType) async {
    Map<String, int> clock = {};

    // Try to get the latest vector clock for this entity from the queue
    final lastOp = await db.query(
      'SyncOperations',
      where: 'EntityId = ? AND EntityType = ?',
      whereArgs: [entityId, entityType],
      orderBy: 'Timestamp DESC',
      limit: 1,
    );

    if (lastOp.isNotEmpty && lastOp.first['VectorClock'] != null) {
      try {
        final parsed = jsonDecode(lastOp.first['VectorClock'] as String);
        clock = Map<String, int>.from(parsed);
      } catch (_) {}
    }

    // If no queue entry, try to get from the entity's own VectorClock column
    if (clock.isEmpty) {
      try {
        final tableName = _getTableName(entityType);
        if (tableName != null) {
          final entity = await db.query(tableName, where: 'Id = ?', whereArgs: [entityId], limit: 1);
          if (entity.isNotEmpty && entity.first['VectorClock'] != null) {
            final parsed = jsonDecode(entity.first['VectorClock'] as String);
            clock = Map<String, int>.from(parsed);
          }
        }
      } catch (_) {}
    }

    // Increment local counter
    clock[localDeviceId] = (clock[localDeviceId] ?? 0) + 1;

    return clock;
  }

  /// Compares two vector clocks. Returns:
  /// "equal", "local", "remote", or "conflict".
  static String compareVectorClocks(Map<String, int> local, Map<String, int> remote) {
    bool localGreater = false;
    bool remoteGreater = false;

    final allKeys = <String>{...local.keys, ...remote.keys};
    for (final key in allKeys) {
      final l = local[key] ?? 0;
      final r = remote[key] ?? 0;
      if (l > r) localGreater = true;
      if (r > l) remoteGreater = true;
    }

    if (!localGreater && !remoteGreater) return 'equal';
    if (localGreater && !remoteGreater) return 'local';
    if (!localGreater && remoteGreater) return 'remote';
    return 'conflict';
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
