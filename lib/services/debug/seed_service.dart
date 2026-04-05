import 'dart:math';
import '../storage/database_service.dart';
import '../auth/auth_service.dart';
import '../cloud/cloud_sync_service.dart';
import '../../models/task.dart';

class SeedService {
  static final _db = databaseServiceProvider;
  static final _auth = AuthService.instance;

  static Future<void> seedMayureshAccount() async {
    final uid = _auth.currentUser?.id;
    if (uid == null) return;

    final now = DateTime.now();
    final random = Random();

    // 1. Create Profile
    await _db.updateProfile({
      'name': 'Mayuresh',
      'username': 'mayuresh@gmail.com',
      'professional_context': 'Engineering Student',
      'goals': 'Mastering Architecture, Reducing Mental Stress',
      'streak_days': 5,
      'total_xp': 850,
      'current_level': 'Improving',
    });

    // 2. Generate 7 Days of Wellbeing History (7-layer Scores)
    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      
      final cwsBase = 65.0 - (i * 2); // Gradual improvement in simulation
      
      await _db.saveWellbeingRecord({
        'date': dateStr,
        'user_id': uid,
        'cws_score': cwsBase + random.nextDouble() * 5,
        'emotion_score': 60.0 + random.nextDouble() * 20,
        'stress_score': 40.0 + random.nextDouble() * 10,
        'task_score': 70.0 + random.nextDouble() * 10,
        'activity_score': 55.0 + random.nextDouble() * 30,
        'routine_score': 80.0,
        'behavior_score': 75.0,
        'growth_score': 65.0,
        'risk_level': 'green',
        'sentiment': 'positive',
      }, uid);
    }

    // 3. Add Tasks (Completed & Incomplete)
    // Completed Tasks
    for (int i = 1; i <= 3; i++) {
      await _db.saveTask(Task(
        id: 'completed_$i',
        title: 'Review Chapter $i Architecture',
        description: 'Completed for test',
        priority: 2,
        status: TaskStatus.completed,
        category: TaskCategory.academic,
        userId: uid,
        createdAt: now.subtract(Duration(days: i + 1)).millisecondsSinceEpoch,
        completedAt: now.subtract(Duration(days: i)).millisecondsSinceEpoch,
      ));
    }

    // Incomplete Task
    await _db.saveTask(Task(
      id: 'incomplete_1',
      title: 'Analyze V2 Persistence Layer',
      description: 'Pending task for testing',
      priority: 3,
      status: TaskStatus.pending,
      category: TaskCategory.professional,
      userId: uid,
      createdAt: now.millisecondsSinceEpoch,
      deadline: now.add(const Duration(days: 2)).millisecondsSinceEpoch,
    ));

    // 4. Add Assessments
    await _db.saveAssessment({
      'id': 'gad7_initial',
      'type': 'GAD-7',
      'score': 8,
      'severity': 'Mild',
      'responses': '{"q1":1,"q2":1,"q3":2}',
      'date': now.subtract(const Duration(days: 5)).toIso8601String().split('T')[0],
      'user_id': uid,
    }, uid);

    // 5. XP History
    for (int i = 0; i < 5; i++) {
      await _db.addXP('DAILY_CHECKIN', 3, uid);
    }
    await _db.addXP('WEEKLY_STREAK', 20, uid);

    // 6. SYNC EVERYTHING TO CLOUD (Force Aggregated Sync)
    await CloudSyncService.instance.syncAll();
  }
}
