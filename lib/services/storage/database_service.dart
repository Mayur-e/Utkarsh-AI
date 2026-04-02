import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'encryption_service.dart';
import '../../models/emotion.dart';
import '../../models/intent.dart';
import '../../core/utils/helpers.dart';
import 'package:intl/intl.dart';

class DatabaseService {
  static Database? _database;
  final EncryptionService _encryptionService = encryptionService;
  bool _initialized = false;

  bool get isReady => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    
    await _encryptionService.initialize();
    
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'utkarsh_v2.db');
    
    _database = await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    
    _initialized = true;
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS xp_events (
          id TEXT PRIMARY KEY,
          action TEXT NOT NULL,
          xp_gained INTEGER NOT NULL,
          earned_at INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE assessments ADD COLUMN triggered_by TEXT DEFAULT "manual"');
      await db.execute('ALTER TABLE assessments ADD COLUMN duration_seconds INTEGER');
      await db.execute('ALTER TABLE assessments ADD COLUMN date TEXT');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS assessment_schedule (
          id              TEXT PRIMARY KEY,
          assessment_type TEXT NOT NULL,
          scheduled_date  TEXT NOT NULL,   -- YYYY-MM-DD
          completed_at    INTEGER,
          skipped         INTEGER DEFAULT 0,
          triggered_by    TEXT             -- 'auto', 'manual', 'notification'
        )
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // ── messages ─────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        role TEXT NOT NULL CHECK(role IN ('user','assistant','system')),
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        emotion_label TEXT,
        stress_level REAL,
        intent_class TEXT,
        session_id TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_msg_session ON messages(session_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_msg_timestamp ON messages(timestamp DESC)');

    // ── wellbeing_records ─────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wellbeing_records (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL UNIQUE,
        cws_score REAL NOT NULL,
        emotion_score REAL,
        stress_score REAL,
        task_score REAL,
        activity_score REAL,
        routine_score REAL,
        behavior_score REAL,
        growth_score REAL,
        risk_level TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_wb_date ON wellbeing_records(date DESC)');

    // ── tasks ────────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        deadline INTEGER,
        priority INTEGER DEFAULT 2,
        status TEXT DEFAULT 'pending',
        extracted_from_chat INTEGER DEFAULT 0,
        pre_mood INTEGER,
        post_mood INTEGER,
        created_at INTEGER NOT NULL,
        completed_at INTEGER
      )
    ''');

    // ── xp_events ────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS xp_events (
        id TEXT PRIMARY KEY,
        action TEXT NOT NULL,
        xp_gained INTEGER NOT NULL,
        earned_at INTEGER NOT NULL
      )
    ''');

    // ── xp_records (legacy) ──────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS xp_records (
        id TEXT PRIMARY KEY,
        action TEXT NOT NULL,
        xp_gained INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        metadata TEXT
      )
    ''');

    // ── assessments ──────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS assessments (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        responses TEXT NOT NULL,
        score REAL,
        severity TEXT,
        timestamp INTEGER NOT NULL
      )
    ''');

    // ── behavior_events ──────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS behavior_events (
        id TEXT PRIMARY KEY,
        event_type TEXT NOT NULL,
        intensity REAL DEFAULT 0.5,
        metadata TEXT,
        timestamp INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_behavior_type ON behavior_events(event_type)');

    // ── user_profile ─────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        id TEXT PRIMARY KEY DEFAULT 'local_user',
        display_name TEXT,
        total_xp INTEGER DEFAULT 0,
        current_level TEXT DEFAULT 'Awareness',
        onboarding_done INTEGER DEFAULT 0,
        voice_enabled INTEGER DEFAULT 0,
        tts_enabled INTEGER DEFAULT 1,
        cloud_sync_enabled INTEGER DEFAULT 0,
        notifications_on INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL,
        last_active_at INTEGER
      )
    ''');

    await db.execute('''
      INSERT OR IGNORE INTO user_profile (id, created_at)
      VALUES ('local_user', ?)
    ''', [DateTime.now().millisecondsSinceEpoch]);
  }

  Database get _db {
    if (_database == null) throw Exception('Database not initialized');
    return _database!;
  }

  // ── DAO: Messages ──────────────────────────────────────────────────

  Future<void> saveMessage({
    required String role,
    required String content,
    required String sessionId,
    Emotion? emotion,
    double? stress,
    IntentClass? intent,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final encrypted = await _encryptionService.encryptText(content);
    
    await _db.insert('messages', {
      'id': id,
      'role': role,
      'content': encrypted,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'emotion_label': emotion?.name,
      'stress_level': stress,
      'intent_class': intent?.name,
      'session_id': sessionId,
    });
  }

  Future<List<Map<String, dynamic>>> getRecentMessages({String? sessionId, int limit = 50}) async {
    final rows = await _db.query(
      'messages',
      where: sessionId != null ? 'session_id = ?' : null,
      whereArgs: sessionId != null ? [sessionId] : null,
      orderBy: 'timestamp ASC',
      limit: limit,
    );

    final List<Map<String, dynamic>> results = [];
    for (final r in rows) {
      final content = r['content'] as String;
      final decrypted = await _encryptionService.decryptText(content);
      results.add({
        ...r,
        'content': decrypted,
      });
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> getMessagesLastNDays(int days) async {
    final since = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final rows = await _db.query(
      'messages',
      where: 'timestamp >= ?',
      whereArgs: [since],
      orderBy: 'timestamp DESC',
    );

    final List<Map<String, dynamic>> results = [];
    for (final r in rows) {
      final String content = r['content'] as String;
      try {
        final decrypted = await _encryptionService.decryptText(content);
        results.add({
          ...r,
          'content': decrypted,
        });
      } catch (e) {
        results.add({
          ...r,
          'content': '[DECRYPTION_ERROR]',
        });
      }
    }
    return results;
  }

  // ── DAO: Wellbeing Records ──────────────────────────────────────────

  Future<void> saveWellbeingRecord(Map<String, dynamic> record) async {
    await _db.insert('wellbeing_records', record, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getWellbeingHistory(int days) async {
    return await _db.query(
      'wellbeing_records',
      orderBy: 'date DESC',
      limit: days,
    );
  }

  // ── DAO: Tasks ──────────────────────────────────────────────────────

  Future<void> saveTask(Map<String, dynamic> task) async {
    await _db.insert('tasks', {
      ...task,
      'id': task['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getActiveTasks() async {
    return await _db.query(
      'tasks',
      where: "status IN ('pending', 'in_progress')",
      orderBy: 'priority DESC, deadline ASC',
    );
  }

  Future<void> updateTaskDeadline(String id, int deadline) async {
    await _db.update(
      'tasks',
      {'deadline': deadline},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTaskPriority(String id, int priority) async {
    await _db.update(
      'tasks',
      {'priority': priority},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getRecentTasks(int limit) async {
    return await _db.query(
      'tasks',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getCompletedTasks() async {
    return await _db.query(
      'tasks',
      where: "status = 'completed'",
      orderBy: 'completed_at DESC',
      limit: 50,
    );
  }

  Future<void> updateTaskStatus(String id, String status) async {
    await _db.update(
      'tasks',
      {
        'status': status,
        if (status == 'completed')
          'completed_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTask(String id) async {
    await _db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // ── DAO: Behavior Events ───────────────────────────────────────────

  Future<void> saveBehaviorEvent({
    required String type,
    required double intensity,
    String? metadata,
  }) async {
    await _db.insert('behavior_events', {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'event_type': type,
      'intensity': intensity,
      'metadata': metadata,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getRecentBehaviorEvents(int hours) async {
    final since = DateTime.now().millisecondsSinceEpoch - (hours * 3600 * 1000);
    return await _db.query(
      'behavior_events',
      where: 'timestamp > ?',
      whereArgs: [since],
      orderBy: 'timestamp DESC',
    );
  }

  // ── DAO: XP Events ─────────────────────────────────────────────────

  Future<void> addXP(String action, int xpGained) async {
    await _db.insert('xp_events', {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'action': action,
      'xp_gained': xpGained,
      'earned_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<int> getTotalXP() async {
    final result = await _db.rawQuery(
        'SELECT COALESCE(SUM(xp_gained), 0) as total FROM xp_events');
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> getXPHistory(int limit) async {
    return await _db.query(
      'xp_events',
      orderBy: 'earned_at DESC',
      limit: limit,
    );
  }

  Future<bool> hasAwardedDailyCheckinToday() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = startOfDay + 86400000;
    
    final res = await _db.query(
      'xp_events',
      where: 'action = ? AND earned_at >= ? AND earned_at < ?',
      whereArgs: ['DAILY_CHECKIN', startOfDay, endOfDay],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  // ── DAO: Assessments ───────────────────────────────────────────────

  Future<void> saveAssessment(Map<String, dynamic> data) async {
    await _db.insert('assessments', {
      'id': data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'type': data['type'],
      'responses': data['responses'],
      'score': data['score'],
      'severity': data['severity'],
      'timestamp': data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      'date': data['date'] ?? todayString(),
      'triggered_by': data['triggered_by'] ?? 'manual',
      'duration_seconds': data['duration_seconds'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAssessments() async {
    return await _db.query('assessments', orderBy: 'timestamp DESC');
  }

  Future<List<Map<String, dynamic>>> getAssessmentsForDate(String date) async {
    return await _db.query(
      'assessments',
      where: 'date = ?',
      whereArgs: [date],
    );
  }

  Future<Map<String, dynamic>?> getLatestAssessmentOfType(String type) async {
    final res = await _db.query(
      'assessments',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<Map<String, dynamic>?> getAssessmentTypeForWeek(String type) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekStr = DateFormat('yyyy-MM-dd').format(startOfWeek);
    
    final res = await _db.query(
      'assessments',
      where: 'type = ? AND date >= ?',
      whereArgs: [type, startOfWeekStr],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  // ── DAO: User Profile ──────────────────────────────────────────────

  Future<Map<String, dynamic>?> getProfile() async {
    final res = await _db.query('user_profile', limit: 1);
    if (res.isNotEmpty) return res.first;
    return null;
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    final existing = await getProfile();
    if (existing == null) {
      await _db.insert('user_profile', {
        'id': 'user_1',
        ...updates,
      });
    } else {
      await _db.update(
        'user_profile',
        updates,
        where: 'id = ?',
        whereArgs: [existing['id']],
      );
    }
  }

  Future<void> clearChatHistory() async {
    await _db.execute('DELETE FROM messages;');
    // We can keep tasks and behavior events, or clear them. A user usually means LLM messages.
    // For privacy, we'll wipe messages.
  }

  Future<void> clearAllData() async {
    await _db.execute('DELETE FROM messages;');
    await _db.execute('DELETE FROM tasks;');
    await _db.execute('DELETE FROM wellbeing_records;');
    await _db.execute('DELETE FROM xp_events;');
    await _db.execute('DELETE FROM assessments;');
    await _db.execute('DELETE FROM behavior_events;');
    // Reset profile totally but keep the row
    await _db.execute('''
      UPDATE user_profile 
      SET total_xp = 0, 
          current_level = 'Awareness', 
          onboarding_done = 0
    ''');
  }

  Future<String> exportData() async {
    final tables = [
      'messages',
      'tasks',
      'wellbeing_records',
      'assessments',
      'user_profile',
      'xp_events',
      'behavior_events',
      'xp_records'
    ];
    final Map<String, dynamic> result = {};
    for (final table in tables) {
      try {
        final rows = await _db.query(table);
        if (table == 'messages') {
          final List<Map<String, dynamic>> decrypted = [];
          for (final r in rows) {
            final content = r['content'] as String;
            try {
              final text = await _encryptionService.decryptText(content);
              decrypted.add({...r, 'content': text});
            } catch (e) {
              decrypted.add({...r, 'content': '[DECRYPTION_ERROR]'});
            }
          }
          result[table] = decrypted;
        } else {
          result[table] = rows;
        }
      } catch (e) {
        result[table] = [];
      }
    }
    return jsonEncode(result);
  }
}

final databaseServiceProvider = DatabaseService();
