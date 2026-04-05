import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'encryption_service.dart';
import '../../models/emotion.dart';
import '../../models/intent.dart';
import '../../core/utils/helpers.dart';
import '../../models/task.dart';
import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';
import '../../models/context_capsule.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? get database => _database;

  Future<bool> hasCompletedCheckInToday(String? userId) async {
    final db = _database;
    if (db == null) return false;
    final today = DateTime.now().toIso8601String().split('T')[0];
    final res = await db.query(
      'assessments',
      where: 'user_id = ? AND date = ? AND (type = ? OR type = ?)',
      whereArgs: [userId ?? 'local_user', today, 'dailyMood', 'dailyStress'],
    );
    return res.isNotEmpty;
  }

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
      version: 11,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        // PROACTIVE HARD REPAIR: Ensure all columns exist before ANY other service uses the DB
        final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='user_profile'");
        if (tables.isNotEmpty) {
          final columns = await db.rawQuery("PRAGMA table_info(user_profile)");
          final colNames = columns.map((c) => c['name'] as String).toList();
          
          final missing = ['name', 'username', 'goals', 'professional_context', 'streak_days', 'total_xp', 'current_level'];
          for (final col in missing) {
            if (!colNames.contains(col)) {
              try {
                String type = (col == 'streak_days' || col == 'total_xp') ? 'INTEGER' : 'TEXT';
                String def = (col == 'streak_days' || col == 'total_xp') ? 'DEFAULT 0' : '';
                if (col == 'current_level') def = "DEFAULT 'Awareness'";
                await db.execute('ALTER TABLE user_profile ADD COLUMN $col $type $def');
                debugPrint('[DatabaseService] 🛠️ Repaired missing column: $col');
              } catch (e) {
                debugPrint('[DatabaseService] ❌ Failed to repair column $col: $e');
              }
            }
          }
        }
        
        // Safety check for 'wellbeing_records'
        final wbTables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='wellbeing_records'");
        if (wbTables.isNotEmpty) {
          final columns = await db.rawQuery("PRAGMA table_info(wellbeing_records)");
          final colNames = columns.map((c) => c['name'] as String).toList();
          
          final missing = ['sentiment', 'risk_level', 'growth_score', 'behavior_score', 'routine_score', 'activity_score', 'task_score', 'stress_score', 'emotion_score'];
          for (final col in missing) {
            if (!colNames.contains(col)) {
              try {
                String type = (col == 'sentiment' || col == 'risk_level') ? 'TEXT' : 'REAL';
                await db.execute('ALTER TABLE wellbeing_records ADD COLUMN $col $type'); 
                debugPrint('[DatabaseService] 🛠️ Repaired missing WB column: $col');
              } catch (e) {
                debugPrint('[DatabaseService] ❌ Failed to repair WB column $col: $e');
              }
            }
          }
        }
      },
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
          scheduled_date  TEXT NOT NULL,
          completed_at    INTEGER,
          skipped         INTEGER DEFAULT 0,
          triggered_by    TEXT
        )
      ''');
    }
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN name TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN username TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN professional_context TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN goals TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN email TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN age INTEGER');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN preferred_language TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN profession TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN college_profile TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN school_profile TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN professional_profile TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN wake_time_hour INTEGER');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN wake_time_minute INTEGER');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN sleep_time_hour INTEGER');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN sleep_time_minute INTEGER');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN daily_hours REAL');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN activity_level TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN social_preference TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN stress_triggers TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN response_style TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN baseline_stress INTEGER');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN baseline_sleep INTEGER');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN health_notes TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN last_active_date TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN daily_mood_notification INTEGER DEFAULT 1');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN weekly_review_notification INTEGER DEFAULT 1');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN task_reminders INTEGER DEFAULT 1');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profile ADD COLUMN streak_reminders INTEGER DEFAULT 1');
    } catch (_) {}
    try { await db.execute('ALTER TABLE user_profile ADD COLUMN name TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE user_profile ADD COLUMN username TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE user_profile ADD COLUMN goals TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE user_profile ADD COLUMN professional_context TEXT'); } catch (_) {}
    try { await db.execute('ALTER TABLE user_profile ADD COLUMN streak_days INTEGER DEFAULT 0'); } catch (_) {}
    try { await db.execute('ALTER TABLE user_profile ADD COLUMN total_xp INTEGER DEFAULT 0'); } catch (_) {}
    try { await db.execute('ALTER TABLE user_profile ADD COLUMN current_level TEXT DEFAULT \'Awareness\''); } catch (_) {}
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE tasks ADD COLUMN category TEXT DEFAULT \'academic\'');
      await db.execute('ALTER TABLE tasks ADD COLUMN complexity TEXT DEFAULT \'medium\'');
      await db.execute('ALTER TABLE tasks ADD COLUMN snoozed_until INTEGER');
      await db.execute('ALTER TABLE tasks ADD COLUMN deferred_to INTEGER');
      await db.execute('ALTER TABLE tasks ADD COLUMN subtasks TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN estimated_minutes INTEGER DEFAULT 30');
      await db.execute('ALTER TABLE tasks ADD COLUMN scheduled_for INTEGER');
      await db.execute('ALTER TABLE tasks ADD COLUMN priority_score REAL DEFAULT 50.0');
      await db.execute('ALTER TABLE tasks ADD COLUMN stress_adjusted INTEGER DEFAULT 0');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS context_capsules (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          date TEXT NOT NULL,
          dominant_emotion TEXT,
          average_stress_level REAL,
          primary_intent TEXT,
          behavioral_flags TEXT,
          session_themes TEXT,
          consecutive_negative_days INTEGER,
          total_messages_this_week INTEGER,
          cws_trend REAL,
          intent_frequency TEXT,
          streak_days INTEGER,
          total_xp INTEGER,
          current_level TEXT,
          synced_at INTEGER
        )
      ''');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE user_profile ADD COLUMN ai_learning_enabled INTEGER DEFAULT 1');
    }
    if (oldVersion < 9) {
      await db.execute('ALTER TABLE user_profile ADD COLUMN emergency_contacts TEXT');
    }
    if (oldVersion < 10) {
      await db.execute('ALTER TABLE user_profile ADD COLUMN online_ai_enabled INTEGER DEFAULT 1');
      await db.execute('ALTER TABLE user_profile ADD COLUMN offline_llm_enabled INTEGER DEFAULT 1');
    }
    if (oldVersion < 11) {
      await db.execute('ALTER TABLE messages ADD COLUMN user_id TEXT NOT NULL DEFAULT "local_user"');
      await db.execute('ALTER TABLE wellbeing_records ADD COLUMN user_id TEXT NOT NULL DEFAULT "local_user"');
      await db.execute('ALTER TABLE tasks ADD COLUMN user_id TEXT NOT NULL DEFAULT "local_user"');
      await db.execute('ALTER TABLE xp_events ADD COLUMN user_id TEXT NOT NULL DEFAULT "local_user"');
      await db.execute('ALTER TABLE assessments ADD COLUMN user_id TEXT NOT NULL DEFAULT "local_user"');
      await db.execute('ALTER TABLE behavior_events ADD COLUMN user_id TEXT NOT NULL DEFAULT "local_user"');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL DEFAULT 'local_user',
        role TEXT NOT NULL CHECK(role IN ('user','assistant','system')),
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        emotion_label TEXT,
        stress_level REAL,
        intent_class TEXT,
        session_id TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wellbeing_records (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL DEFAULT 'local_user',
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
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL DEFAULT 'local_user',
        title TEXT NOT NULL,
        description TEXT,
        deadline INTEGER,
        priority INTEGER DEFAULT 2,
        status TEXT DEFAULT 'pending',
        extracted_from_chat INTEGER DEFAULT 0,
        pre_mood INTEGER,
        post_mood INTEGER,
        created_at INTEGER NOT NULL,
        completed_at INTEGER,
        category TEXT DEFAULT 'academic',
        complexity TEXT DEFAULT 'medium',
        snoozed_until INTEGER,
        deferred_to INTEGER,
        subtasks TEXT,
        estimated_minutes INTEGER DEFAULT 30,
        scheduled_for INTEGER,
        priority_score REAL DEFAULT 50.0,
        stress_adjusted INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS xp_events (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL DEFAULT 'local_user',
        action TEXT NOT NULL,
        xp_gained INTEGER NOT NULL,
        earned_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS assessments (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL DEFAULT 'local_user',
        type TEXT NOT NULL,
        responses TEXT NOT NULL,
        score REAL,
        severity TEXT,
        timestamp INTEGER NOT NULL,
        triggered_by TEXT DEFAULT 'manual',
        duration_seconds INTEGER,
        date TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS behavior_events (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL DEFAULT 'local_user',
        event_type TEXT NOT NULL,
        intensity REAL DEFAULT 0.5,
        metadata TEXT,
        timestamp INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        id TEXT PRIMARY KEY DEFAULT 'local_user',
        display_name TEXT,
        age INTEGER,
        gender TEXT,
        preferred_language TEXT,
        profession TEXT,
        college_profile TEXT,
        school_profile TEXT,
        professional_profile TEXT,
        name TEXT,
        username TEXT,
        professional_context TEXT,
        wake_time_hour INTEGER,
        wake_time_minute INTEGER,
        sleep_time_hour INTEGER,
        sleep_time_minute INTEGER,
        daily_hours REAL,
        activity_level TEXT,
        social_preference TEXT,
        stress_triggers TEXT,
        response_style TEXT,
        voice_enabled INTEGER DEFAULT 0,
        tts_enabled INTEGER DEFAULT 1,
        baseline_stress INTEGER,
        baseline_sleep INTEGER,
        health_notes TEXT,
        total_xp INTEGER DEFAULT 0,
        current_level TEXT DEFAULT 'Awareness',
        onboarding_done INTEGER DEFAULT 0,
        streak_days INTEGER DEFAULT 0,
        last_active_date TEXT,
        notifications_enabled INTEGER DEFAULT 1,
        daily_mood_notification INTEGER DEFAULT 1,
        weekly_review_notification INTEGER DEFAULT 1,
        task_reminders INTEGER DEFAULT 1,
        streak_reminders INTEGER DEFAULT 1,
        ai_learning_enabled INTEGER DEFAULT 1,
        online_ai_enabled INTEGER DEFAULT 1,
        offline_llm_enabled INTEGER DEFAULT 1,
        emergency_contacts TEXT,
        created_at INTEGER NOT NULL,
        last_active_at INTEGER
      )
    ''');
    await db.execute('''
      INSERT OR IGNORE INTO user_profile (id, created_at)
      VALUES ('local_user', ?)
    ''', [DateTime.now().millisecondsSinceEpoch]);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS context_capsules (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        date TEXT NOT NULL,
        dominant_emotion TEXT,
        average_stress_level REAL,
        primary_intent TEXT,
        behavioral_flags TEXT,
        session_themes TEXT,
        consecutive_negative_days INTEGER,
        total_messages_this_week INTEGER,
        cws_trend REAL,
        intent_frequency TEXT,
        streak_days INTEGER,
        total_xp INTEGER,
        current_level TEXT,
        synced_at INTEGER
      )
    ''');
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
    String? userId,
  }) async {
    final uid = userId ?? 'local_user';
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final encrypted = await _encryptionService.encryptText(content);
    await _db.insert('messages', {
      'id': id,
      'user_id': uid,
      'role': role,
      'content': encrypted,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'emotion_label': emotion?.name,
      'stress_level': stress,
      'intent_class': intent?.name,
      'session_id': sessionId,
    });
  }

  Future<List<Map<String, dynamic>>> getRecentMessages({String? sessionId, String? userId, int limit = 50}) async {
    final uid = userId ?? 'local_user';
    String where = 'user_id = ?';
    List<dynamic> args = [uid];
    
    if (sessionId != null) {
      where += ' AND session_id = ?';
      args.add(sessionId);
    }

    final rows = await _db.query(
      'messages',
      where:     where,
      whereArgs: args,
      orderBy:   'timestamp ASC',
      limit:     limit,
    );
    final List<Map<String, dynamic>> results = [];
    for (final r in rows) {
      final content = r['content'] as String;
      final decrypted = await _encryptionService.decryptText(content);
      results.add({...r, 'content': decrypted});
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> getMessagesLastNDays(int days) async {
    final start = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final rows = await _db.query('messages', where: 'timestamp >= ?', whereArgs: [start], orderBy: 'timestamp ASC');
    final List<Map<String, dynamic>> results = [];
    for (final r in rows) {
      final content = r['content'] as String;
      final decrypted = await _encryptionService.decryptText(content);
      results.add({...r, 'content': decrypted});
    }
    return results;
  }

  // ── DAO: Wellbeing Records ──────────────────────────────────────────

  Future<void> saveWellbeingRecord(Map<String, dynamic> data, [String? userId]) async {
    final uid = userId ?? 'local_user';
    final date = data['date'] ?? todayString();
    
    // Safety for NOT NULL created_at
    final Map<String, dynamic> record = Map<String, dynamic>.from(data);
    record['user_id'] = uid;
    record['date'] = date;
    record['created_at'] ??= DateTime.now().millisecondsSinceEpoch;
    
    await _db.insert('wellbeing_records', record, 
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getWellbeingHistory(int days, [String? userId]) async {
    final uid = userId ?? 'local_user';
    return await _db.query('wellbeing_records', where: 'user_id = ?', whereArgs: [uid], orderBy: 'date DESC', limit: days);
  }

  // ── DAO: Tasks (Feature 03) ───────────────────────────────────────────

  Future<List<Task>> getActiveTasks([String? userId]) async {
    final uid = userId ?? 'local_user';
    final res = await _db.query(
      'tasks',
      where: 'user_id = ? AND status NOT IN (?, ?, ?)',
      whereArgs: [uid, 'completed', 'cancelled', 'snoozed'],
      orderBy: 'priority DESC, created_at DESC',
    );
    return res.map((m) => Task.fromMap(m)).toList();
  }

  Future<List<Task>> getCompletedTasksToday([String? userId]) async {
    final uid = userId ?? 'local_user';
    final start = DateTime.now().subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
    final res = await _db.query(
      'tasks',
      where: 'user_id = ? AND status = ? AND completed_at >= ?',
      whereArgs: [uid, 'completed', start],
    );
    return res.map((m) => Task.fromMap(m)).toList();
  }

  Future<void> saveTask(Task task) async {
    await _db.insert('tasks', task.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateTask(Task task) async {
    await _db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> snoozeTask(String id, int until) async {
    await _db.update('tasks', {'status': 'snoozed', 'snoozed_until': until}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateTaskStatus(String id, String status) async {
    await _db.update(
      'tasks',
      {
        'status': status,
        if (status == 'completed') 'completed_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTask(String id) async {
    await _db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // Legacy/Helper DAOs
  Future<void> updateTaskDeadline(String id, int deadline) async {
    await _db.update('tasks', {'deadline': deadline}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateTaskPriority(String id, int priority) async {
    await _db.update('tasks', {'priority': priority}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getRecentTasks(int limit, [String? userId]) async {
    final uid = userId ?? 'local_user';
    return await _db.query('tasks', where: 'user_id = ?', whereArgs: [uid], orderBy: 'created_at DESC', limit: limit);
  }

  Future<List<Map<String, dynamic>>> getCompletedTasks([String? userId]) async {
    final uid = userId ?? 'local_user';
    return await _db.query('tasks', where: "user_id = ? AND status = 'completed'", whereArgs: [uid], orderBy: 'completed_at DESC', limit: 50);
  }

  // ── DAO: Behavior Events ───────────────────────────────────────────

  Future<void> saveBehaviorEvent({required String type, required double intensity, String? metadata, String? userId}) async {
    final uid = userId ?? 'local_user';
    await _db.insert('behavior_events', {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'user_id': uid,
      'event_type': type,
      'intensity': intensity,
      'metadata': metadata,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getRecentBehaviorEvents(int hours, [String? userId]) async {
    final uid = userId ?? 'local_user';
    final since = DateTime.now().millisecondsSinceEpoch - (hours * 3600 * 1000);
    return await _db.query('behavior_events', where: 'user_id = ? AND timestamp > ?', whereArgs: [uid, since], orderBy: 'timestamp DESC');
  }

  // ── DAO: XP Events ─────────────────────────────────────────────────

  Future<void> addXP(String action, int xpGained, [String? userId]) async {
    final uid = userId ?? AuthService.instance.currentUser?.id ?? 'local_user';
    await _db.insert('xp_events', {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'user_id': uid,
      'action': action,
      'xp_gained': xpGained,
      'earned_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<int> getTotalXP([String? userId]) async {
    final uid = userId ?? AuthService.instance.currentUser?.id ?? 'local_user';
    final result = await _db.rawQuery('SELECT COALESCE(SUM(xp_gained), 0) as total FROM xp_events WHERE user_id = ?', [uid]);
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> getXPHistory(int limit, [String? userId]) async {
    final uid = userId ?? 'local_user';
    return await _db.query('xp_events', where: 'user_id = ?', whereArgs: [uid], orderBy: 'earned_at DESC', limit: limit);
  }

  Future<bool> hasAwardedDailyCheckinToday([String? userId]) async {
    final uid = userId ?? 'local_user';
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = startOfDay + 86400000;
    final res = await _db.query('xp_events', where: 'user_id = ? AND action = ? AND earned_at >= ? AND earned_at < ?', whereArgs: [uid, 'DAILY_CHECKIN', startOfDay, endOfDay], limit: 1);
    return res.isNotEmpty;
  }

  // ── DAO: Assessments ───────────────────────────────────────────────

  Future<void> saveAssessment(Map<String, dynamic> data, [String? userId]) async {
    final uid = userId ?? 'local_user';
    await _db.insert('assessments', {
      'id': data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'user_id': uid,
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

  Future<List<Map<String, dynamic>>> getAssessments([String? userId]) async {
    final uid = userId ?? 'local_user';
    return await _db.query('assessments', where: 'user_id = ?', whereArgs: [uid], orderBy: 'timestamp DESC');
  }

  Future<List<Map<String, dynamic>>> getAssessmentsForDate(String date, [String? userId]) async {
    final uid = userId ?? 'local_user';
    return await _db.query('assessments', where: 'user_id = ? AND date = ?', whereArgs: [uid, date]);
  }

  Future<Map<String, dynamic>?> getLatestAssessmentOfType(String type, [String? userId]) async {
    final uid = userId ?? 'local_user';
    final res = await _db.query('assessments', where: 'user_id = ? AND type = ?', whereArgs: [uid, type], orderBy: 'timestamp DESC', limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<String?> getAssessmentTypeForWeek(String type, [String? userId]) async {
    final uid = userId ?? 'local_user';
    final startOfWeek = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    final res = await _db.query('assessments', where: 'user_id = ? AND type = ? AND timestamp >= ?', whereArgs: [uid, type, startOfWeek], limit: 1);
    return res.isNotEmpty ? type : null;
  }

  // ── DAO: User Profile ──────────────────────────────────────────────

  Future<Map<String, dynamic>?> getProfile([String? userId]) async {
    final uid = userId ?? AuthService.instance.currentUser?.id ?? 'local_user';
    final res = await _db.query('user_profile', where: 'id = ?', whereArgs: [uid], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> saveProfile(Map<String, dynamic> profile, [String? userId]) async {
    await updateProfile(profile, userId);
  }

  Future<void> updateProfile(Map<String, dynamic> updates, [String? userId]) async {
    final uid = userId ?? AuthService.instance.currentUser?.id ?? 'local_user';
    final existing = await getProfile(uid);
    if (existing == null) {
      await _db.insert('user_profile', {'id': uid, ...updates});
    } else {
      await _db.update('user_profile', updates, where: 'id = ?', whereArgs: [uid]);
    }
  }

  /// Migrate all data from local_user to a newly authenticated user.
  /// This fixes the "profile gone" issue upon login.
  Future<void> migrateLocalData(String newUserId) async {
    const localId = 'local_user';
    if (newUserId == localId) return;

    // Check if newUserId already has a profile. If yes, we'll merge selectively.
    final existingNewProfile = await getProfile(newUserId);
    final localProfile = await getProfile(localId);

    if (localProfile != null && existingNewProfile == null) {
      // Move profile record if none exists for the new user ID
      await _db.update('user_profile', {'id': newUserId}, where: 'id = ?', whereArgs: [localId]);
    } else if (localProfile != null && existingNewProfile != null) {
      // Delete local duplicate - maybe we should merge in future but this is safest to avoid collisions
      await _db.delete('user_profile', where: 'id = ?', whereArgs: [localId]);
    }

    // Move all historical data
    final tablesToUpdate = [
      'messages',
      'wellbeing_records',
      'tasks',
      'xp_events',
      'assessments',
      'behavior_events',
      'context_capsules',
    ];

    for (final table in tablesToUpdate) {
      try {
        await _db.update(table, {'user_id': newUserId}, where: 'user_id = ?', whereArgs: [localId]);
      } catch (e) {
        debugPrint('[DatabaseService] Migration failed for table $table: $e');
      }
    }
    
    debugPrint('[DatabaseService] ✅ Migration completed for $newUserId');
  }

  // ── DAO: Context Capsules ──────────────────────────────────────────

  Future<void> saveContextCapsule(Map<String, dynamic> capsule) async {
    final uid = capsule['user_id'] ?? AuthService.instance.currentUser?.id ?? 'local_user';
    await _db.insert('context_capsules', {
      'id':                  capsule['id'] ?? capsule['date'],
      'user_id':             uid,
      'date':                capsule['date'],
      'dominant_emotion':    capsule['dominantEmotion'],
      'average_stress_level': capsule['averageStressLevel'],
      'primary_intent':      capsule['primaryIntent'],
      'behavioral_flags':    jsonEncode(capsule['behavioralFlags']),
      'session_themes':      jsonEncode(capsule['sessionThemes']),
      'consecutive_negative_days': capsule['consecutiveNegativeDays'],
      'total_messages_this_week':   capsule['totalMessagesThisWeek'],
      'cws_trend':           capsule['cwsTrend'],
      'intent_frequency':    jsonEncode(capsule['intentFrequency']),
      'streak_days':         capsule['streakDays'],
      'total_xp':            capsule['totalXP'],
      'current_level':       capsule['currentLevel'],
      'synced_at':           DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<ContextCapsule?> getLatestContextCapsule([String? userId]) async {
    final uid = userId ?? 'local_user';
    final res = await _db.query('context_capsules', where: 'user_id = ?', whereArgs: [uid], orderBy: 'date DESC', limit: 1);
    if (res.isEmpty) return null;
    
    // Model expects Lists/Maps from JSON strings
    final map = Map<String, dynamic>.from(res.first);
    map['behavioral_flags'] = jsonDecode(map['behavioral_flags'] ?? '[]');
    map['session_themes']   = jsonDecode(map['session_themes']   ?? '[]');
    map['intent_frequency'] = jsonDecode(map['intent_frequency'] ?? '{}');
    
    return ContextCapsule.fromMap(map);
  }

  Future<List<ContextCapsule>> getPendingContextCapsules() async {
    final res = await _db.query('context_capsules', where: 'synced_at IS NULL');
    return res.map((r) {
      final map = Map<String, dynamic>.from(r);
      map['behavioral_flags'] = jsonDecode(map['behavioral_flags'] ?? '[]');
      map['session_themes']   = jsonDecode(map['session_themes']   ?? '[]');
      map['intent_frequency'] = jsonDecode(map['intent_frequency'] ?? '{}');
      return ContextCapsule.fromMap(map);
    }).toList();
  }

  Future<void> markContextCapsuleSynced(String id) async {
    await _db.update(
      'context_capsules',
      {'synced_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearChatHistory() async {
    await _db.execute('DELETE FROM messages;');
  }

  Future<void> clearUserData(String userId) async {
    const tables = ['messages', 'tasks', 'wellbeing_records', 'xp_events', 'assessments', 'behavior_events', 'context_capsules'];
    for (final table in tables) {
      await _db.delete(table, where: 'user_id = ?', whereArgs: [userId]);
    }
    await _db.execute('''
      UPDATE user_profile 
      SET total_xp = 0, 
          current_level = 'Awareness', 
          onboarding_done = 0,
          emergency_contacts = NULL
      WHERE id = ?
    ''', [userId]);
  }

  /// Full factory reset for the device
  Future<void> factoryReset() async {
    await _db.delete('messages');
    await _db.delete('tasks');
    await _db.delete('wellbeing_records');
    await _db.delete('xp_events');
    await _db.delete('assessments');
    await _db.delete('behavior_events');
    await _db.delete('context_capsules');
    await _db.delete('user_profile');
    
    // Restore local user skeleton
    await _db.execute('''
      INSERT OR IGNORE INTO user_profile (id, created_at)
      VALUES ('local_user', ?)
    ''', [DateTime.now().millisecondsSinceEpoch]);
  }

  Future<String> exportData() async {
    final tables = ['messages', 'tasks', 'wellbeing_records', 'assessments', 'user_profile', 'xp_events', 'behavior_events', 'xp_records'];
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

final databaseServiceProvider = DatabaseService.instance;
