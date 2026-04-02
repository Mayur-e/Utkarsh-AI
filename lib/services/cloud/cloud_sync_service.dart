import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../storage/database_service.dart';
import '../storage/encryption_service.dart';
import '../auth/key_derivation_service.dart';

class CloudSyncService {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  final _supabase = Supabase.instance.client;
  final _db = databaseServiceProvider;
  final _encryption = EncryptionService.instance;

  // In-memory sync state
  DateTime? _lastSyncTime;
  bool      _isSyncingInProgress = false;

  // ── Upload ─────────────────────────────────────────────────────────────

  Future<void> syncAll() async {
    if (_isSyncingInProgress || !_canSync) return;
    
    _isSyncingInProgress = true;
    try {
    // Throttle 30 mins for auto-sync
    if (_lastSyncTime != null &&
        DateTime.now().difference(_lastSyncTime!).inMinutes < 30) {
      return;
    }
    _lastSyncTime = DateTime.now();

      await Future.wait([
        _syncWellbeingRecords(),
        _syncTasks(),
        _syncXPRecords(),
        _syncAssessments(),
        _syncUserProfile(),
      ]);
    } finally {
      _isSyncingInProgress = false;
    }
  }

  Future<void> _syncWellbeingRecords() async {
    final records = await _db.getWellbeingHistory(90);  // Last 90 days
    for (final r in records) {
      await _upsertRecord(
        recordType: 'wellbeing',
        recordDate: r['date'] as String,
        data: r,
      );
      // Yield to main thread to prevent ANR during bulk crypto/sync
      await Future.delayed(const Duration(milliseconds: 30));
    }
  }

  Future<void> _syncTasks() async {
    final tasks = await _db.getRecentTasks(100);
    for (final t in tasks) {
      await _upsertRecord(
        recordType: 'task',
        recordDate: t['id'] as String,
        data: t,
      );
    }
  }

  Future<void> _syncXPRecords() async {
    final xpHistory = await _db.getXPHistory(200);
    for (final r in xpHistory) {
      await _upsertRecord(
        recordType: 'xp',
        recordDate: r['id'] as String,
        data: r,
      );
    }
  }

  Future<void> _syncAssessments() async {
    final assessments = await _db.getAssessments();
    for (final a in assessments) {
      await _upsertRecord(
        recordType: 'assessment',
        recordDate: a['id'] as String,
        data: a,
      );
    }
  }

  Future<void> _syncUserProfile() async {
    final profile = await _db.getProfile();
    if (profile == null) {
      return;
    }
    await _upsertRecord(
      recordType: 'profile',
      recordDate: 'singleton',
      data: profile,
    );
  }

  /// Encrypt data and upsert to Supabase.
  Future<void> _upsertRecord({
    required String recordType,
    required String recordDate,
    required Map<String, dynamic> data,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final plaintext = data.toString();
      final encryptedBlob = await _encryption.encryptJson(data);
      final checksum = KeyDerivationService.computeChecksum(plaintext);

      await _supabase.from('encrypted_records').upsert({
        'user_id': userId,
        'record_type': recordType,
        'record_date': recordDate,
        'encrypted_blob': encryptedBlob,
        'checksum': checksum,
        'synced_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,record_type,record_date');
    } catch (e) {
      debugPrint('[Cloud] Upsert failed for $recordType ($recordDate): $e');
    }
  }

  // ── Download (restore on new device) ──────────────────────────────────

  Future<void> restoreAll() async {
    if (!_canSync) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final List<dynamic> records = await _supabase
          .from('encrypted_records')
          .select()
          .eq('user_id', userId)
          .order('uploaded_at');

      for (final record in records) {
        try {
          final data = await _encryption.decryptJson<Map<String, dynamic>>(
            record['encrypted_blob'] as String,
          );

          // Verify integrity
          final checksum = record['checksum'] as String?;
          if (checksum != null) {
            // Re-stringify for verification. Ensure consistency.
            // Note: toString() on a Map is often safe enough if deterministic, 
            // but for real production, jsonEncode might be better.
            // Using data.toString() as requested.
            if (!KeyDerivationService.verifyChecksum(data.toString(), checksum)) {
              debugPrint('[Cloud] Checksum mismatch for ${record['record_type']} ${record['record_date']}');
              continue;
            }
          }

          await _restoreToLocal(
            recordType: record['record_type'] as String,
            data: data,
          );
        } catch (e) {
          debugPrint('[Cloud] Failed to decrypt/restore ${record['record_type']}: $e');
        }
      }
    } catch (e) {
      debugPrint('[Cloud] Restore overall failed: $e');
    }
  }

  Future<void> _restoreToLocal({
    required String recordType,
    required Map<String, dynamic> data,
  }) async {
    switch (recordType) {
      case 'wellbeing':
        await _db.saveWellbeingRecord(data);
        break;
      case 'task':
        await _db.saveTask(data);
        break;
      case 'xp':
        // Restore XP event
        await _db.addXP(data['action'] ?? 'SYNC', data['xp_gained'] ?? 0);
        break;
      case 'assessment':
        await _db.saveAssessment(data);
        break;
      case 'profile':
        await _db.updateProfile(data);
        break;
    }
  }

  bool get _canSync =>
      _supabase.auth.currentUser != null &&
      _encryption.isInitialized;

  // ── Backward Compatibility & Manual Sync ──────────────────────────────

  Future<void> syncWellbeingHistory() async {
    if (!_canSync) return;
    await _syncWellbeingRecords();
  }

  // Backward compatibility
  Future<void> initialize() async {}
}

final cloudSyncService = CloudSyncService.instance;
