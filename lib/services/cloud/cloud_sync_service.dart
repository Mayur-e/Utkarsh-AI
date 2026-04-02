import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../storage/encryption_service.dart';
import '../storage/database_service.dart';

class CloudSyncService {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  SupabaseClient? _client;
  String? _userId;
  bool _enabled = false;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (url.isEmpty || anonKey.isEmpty) {
      debugPrint('[Cloud] Missing SUPABASE_URL or SUPABASE_ANON_KEY');
      return;
    }

    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
      _client = Supabase.instance.client;
      
      final session = _client!.auth.currentSession;
      if (session?.user != null) {
        _userId = session!.user.id;
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[Cloud] Init Failed: $e');
    }
  }

  Future<String> signInAnonymously() async {
    if (_client == null) throw Exception('Cloud sync not fully configured in .env');
    
    final response = await _client!.auth.signInAnonymously();
    if (response.user == null) {
      throw Exception('Sign in failed');
    }
    _userId = response.user!.id;
    return _userId!;
  }

  Future<void> syncWellbeingHistory() async {
    if (!_enabled || _client == null || _userId == null) return;

    final records = await databaseServiceProvider.getWellbeingHistory(30);
    
    for (final record in records) {
      final encryptedBlob = await encryptionService.encryptJson({
        'date': record['date'],
        'cws_score': record['cws_score'],
        'risk_level': record['risk_level'],
        'emotion_score': record['emotion_score'],
      });

      try {
        await _client!.from('encrypted_records').upsert({
          'user_id': _userId,
          'record_type': 'wellbeing',
          'record_date': record['date'],
          'encrypted_blob': encryptedBlob,
          'uploaded_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id,record_type,record_date');
      } catch (e) {
        debugPrint('[Cloud] Sync error: $e');
      }
    }
  }

  Future<void> restoreWellbeingHistory() async {
    if (_client == null || _userId == null) return;

    try {
      final data = await _client!
          .from('encrypted_records')
          .select('*')
          .eq('user_id', _userId!)
          .eq('record_type', 'wellbeing') as List<dynamic>;

      for (final row in data) {
        try {
          final record = await encryptionService.decryptJson(row['encrypted_blob']);
          await databaseServiceProvider.saveWellbeingRecord({
            'date': record['date'],
            'cws_score': record['cws_score'],
            'risk_level': record['risk_level'],
            'emotion_score': record['emotion_score'],
          });
        } catch (e) {
          debugPrint('[Cloud] Decrypt error for row ${row['id']}');
        }
      }
    } catch (e) {
      debugPrint('[Cloud] Restore error: $e');
    }
  }

  void setEnabled(bool v) {
    _enabled = v;
  }

  bool get isEnabled => _enabled;
  bool get isSignedIn => _userId != null;
}

final cloudSyncService = CloudSyncService.instance;
