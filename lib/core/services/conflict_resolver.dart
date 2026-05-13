import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';

/// Layer 3 + Layer 5: Conflict Resolution (Android side).
/// Three-level strategy:
/// 1. AutoMerge — different fields modified → merge both
/// 2. LWW — same field modified → latest wins, loser to RevisionLog
/// 3. (Future) UserPrompt for financial fields
class ConflictResolverMobile {
  static final ConflictResolverMobile instance = ConflictResolverMobile._();
  ConflictResolverMobile._();

  static const _uuid = Uuid();

  /// Resolves a conflict between local and remote entity data.
  /// Returns the merged data map.
  Future<Map<String, dynamic>> resolve({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
    required String localChangedFields,
    required String remoteChangedFields,
    required DateTime localTimestamp,
    required DateTime remoteTimestamp,
  }) async {
    final localFields = _parseFields(localChangedFields);
    final remoteFields = _parseFields(remoteChangedFields);

    // If no field tracking, fall back to entity-level LWW
    if (localFields.isEmpty && remoteFields.isEmpty) {
      return await _entityLevelLWW(
        entityType, entityId, localData, remoteData,
        localTimestamp, remoteTimestamp,
      );
    }

    final merged = Map<String, dynamic>.from(localData);
    final overlapping = localFields.where((f) => remoteFields.contains(f)).toList();
    final remoteOnly = remoteFields.where((f) => !localFields.contains(f)).toList();

    // AutoMerge: fields only modified remotely
    for (final field in remoteOnly) {
      if (remoteData.containsKey(field)) {
        merged[field] = remoteData[field];
      }
    }

    // LWW on overlapping fields
    if (overlapping.isNotEmpty) {
      final winner = remoteTimestamp.isAfter(localTimestamp) ? 'windows' : 'android';

      for (final field in overlapping) {
        if (winner == 'windows' && remoteData.containsKey(field)) {
          merged[field] = remoteData[field];
        }
        // else keep local
      }

      // Save revision log
      await _saveRevision(
        entityType: entityType,
        entityId: entityId,
        oldData: localData,
        newData: remoteData,
        resolutionType: 'LWW',
        winner: winner,
        loser: winner == 'windows' ? 'android' : 'windows',
        conflictedFields: overlapping.join(','),
      );
    }

    return merged;
  }

  /// Entity-level LWW when no field-level tracking is available.
  Future<Map<String, dynamic>> _entityLevelLWW(
    String entityType,
    String entityId,
    Map<String, dynamic> localData,
    Map<String, dynamic> remoteData,
    DateTime localTimestamp,
    DateTime remoteTimestamp,
  ) async {
    final winner = remoteTimestamp.isAfter(localTimestamp) ? 'windows' : 'android';
    final result = winner == 'windows' ? remoteData : localData;

    // Find differing fields for the log
    final diffFields = <String>[];
    final allKeys = <String>{...localData.keys, ...remoteData.keys};
    for (final key in allKeys) {
      if (localData[key]?.toString() != remoteData[key]?.toString()) {
        diffFields.add(key);
      }
    }

    await _saveRevision(
      entityType: entityType,
      entityId: entityId,
      oldData: localData,
      newData: remoteData,
      resolutionType: 'LWW',
      winner: winner,
      loser: winner == 'windows' ? 'android' : 'windows',
      conflictedFields: diffFields.join(','),
    );

    return Map<String, dynamic>.from(result);
  }

  /// Persists a revision record for auditability.
  Future<void> _saveRevision({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> oldData,
    required Map<String, dynamic> newData,
    required String resolutionType,
    required String winner,
    required String loser,
    required String conflictedFields,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('RevisionLogs', {
        'Id': _uuid.v4(),
        'EntityId': entityId,
        'EntityType': entityType,
        'OldData': jsonEncode(oldData),
        'NewData': jsonEncode(newData),
        'ResolutionType': resolutionType,
        'WinnerDevice': winner,
        'LoserDevice': loser,
        'ConflictedFields': conflictedFields,
        'ResolvedAt': DateTime.now().toUtc().toIso8601String(),
      });
      debugPrint('[Conflict] Saved revision: $entityType/$entityId ($resolutionType, winner=$winner)');
    } catch (e) {
      debugPrint('[Conflict] Failed to save revision: $e');
    }
  }

  List<String> _parseFields(String csv) {
    if (csv.isEmpty) return [];
    return csv.split(',').map((f) => f.trim()).where((f) => f.isNotEmpty).toList();
  }
}
