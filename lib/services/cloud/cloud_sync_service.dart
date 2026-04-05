import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../storage/database_service.dart';
import '../storage/encryption_service.dart';
import '../auth/key_derivation_service.dart';
import '../../models/task.dart';
import '../context/context_builder_service.dart';

class CloudSyncService {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  final _supabase = Supabase.instance.client;
  final _db = databaseServiceProvider;
  final _encryption = EncryptionService.instance;

  // In-memory sync state
  bool _isSyncingInProgress = false;

  // ── Aggregated Sync Engine ──────────────────────────────────────────

  Future<void> syncAll() async {
    if (_isSyncingInProgress || !_canSync) return;
    
    _isSyncingInProgress = true;
    try {
      // Fetch all historical data collections
      final wellbeing   = await _db.getWellbeingHistory(180); // 6 months
      final tasks       = await _db.getRecentTasks(200);      // Recent 200 tasks
      final xp          = await _db.getXPHistory(300);        // Recent 300 XP events
      final assessments = await _db.getAssessments();         // All assessments
      final profile     = await _db.getProfile();
      final capsule     = await ContextBuilderService.instance.buildWeeklyCapsule(_supabase.auth.currentUser!.id);

      // Perform aggregated JSON syncs (one row per type)
      await Future.wait([
        _syncCollection('wellbeing_history', {'records': wellbeing}),
        _syncCollection('tasks_cloud_sync',  {'records': tasks}),
        _syncCollection('xp_history',        {'records': xp}),
        _syncCollection('assessment_log',    {'records': assessments}),
        if (profile != null) _syncCollection('profile_main', profile),
        _syncCollection('context_capsule',   capsule.toMap()),
      ]);
      
      debugPrint('[Cloud] Aggregated sync successful ✅');
    } catch (e) {
      debugPrint('[Cloud] Sync routine error: $e');
    } finally {
      _isSyncingInProgress = false;
    }
  }

  /// Encrypt and sync a single data type as a massive JSON blob
  Future<void> _syncCollection(String type, Map<String, dynamic> data) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final encryptedBlob = await _encryption.encryptJson(data);
      final checksum = KeyDerivationService.computeChecksum(data.toString());

      // By using 'singleton' as record_date, we guarantee ONE row per type
      await _supabase.from('encrypted_records').upsert({
        'user_id': userId,
        'record_type': type,
        'record_date': 'singleton',
        'encrypted_blob': encryptedBlob,
        'checksum': checksum,
        'synced_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,record_type,record_date');
      
    } catch (e) {
      debugPrint('[Cloud] Aggregated upsert failed for $type: $e');
    }
  }

  // ── Aggregated Restoration ──────────────────────────────────────────

  Future<bool> restoreAll() async {
    if (!_canSync) return false;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    bool profileFound = false;
    try {
      final records = await _supabase
          .from('encrypted_records')
          .select()
          .eq('user_id', userId);

      if (records.isEmpty) return false;

      for (final record in records) {
        try {
          final data = await _encryption.decryptJson<Map<String, dynamic>>(
            record['encrypted_blob'] as String,
          );

          final type = record['record_type'] as String;
          if (type == 'profile_main') profileFound = true;

          await _restoreFromAggregatedData(type, data);
        } catch (e) {
          debugPrint('[Cloud] Failed to restore aggregated ${record['record_type']}: $e');
        }
      }
      return profileFound;
    } catch (e) {
      debugPrint('[Cloud] Aggregated restore failed: $e');
      return false;
    }
  }

  Future<void> _restoreFromAggregatedData(String type, Map<String, dynamic> data) async {
    final items = (data['records'] as List<dynamic>?) ?? [];

    switch (type) {
      case 'wellbeing_history':
        for (final item in items) {
          await _db.saveWellbeingRecord(Map<String, dynamic>.from(item));
        }
        break;
      case 'tasks_cloud_sync':
        for (final item in items) {
          await _db.saveTask(Task.fromMap(Map<String, dynamic>.from(item)));
        }
        break;
      case 'xp_history':
        for (final item in items) {
          await _db.addXP(item['action'] ?? 'SYNC', item['xp_gained'] ?? 0);
        }
        break;
      case 'assessment_log':
        for (final item in items) {
          await _db.saveAssessment(Map<String, dynamic>.from(item));
        }
        break;
      case 'profile_main':
        await _db.updateProfile(data);
        break;
      case 'context_capsule':
        await _db.saveContextCapsule(data);
        break;
    }
  }

  bool get _canSync =>
      _supabase.auth.currentUser != null &&
      _encryption.isInitialized;

  Future<void> syncWellbeingHistory() async {
    if (!_canSync) return;
    await syncAll();
  }

  Future<void> initialize() async {}
}

final cloudSyncService = CloudSyncService.instance;
