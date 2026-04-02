import 'dart:math' as math;
import '../storage/database_service.dart';

class BehaviorResult {
  final bool procrastination;   // 2+ overdue high-priority tasks
  final bool overload;          // 5+ pending tasks AND stress > 60
  final int streakDays;         // Consecutive days of app use
  final double routineScore;    // 0–100 consistency score
  final double behaviorScore;   // 0–100 overall behavioral wellness
  final double activityScore;   // 0–100 engagement level
  final List<String> flags;     // Human-readable flag list

  BehaviorResult({
    required this.procrastination,
    required this.overload,
    required this.streakDays,
    required this.routineScore,
    required this.behaviorScore,
    required this.activityScore,
    required this.flags,
  });
}

class BehaviorService {
  final DatabaseService _db = databaseServiceProvider;

  Future<BehaviorResult> analyze(double currentStressLevel) async {
    final tasks = await _db.getActiveTasks();
    final history = await _db.getWellbeingHistory(14);
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final List<String> flags = [];

    // ── Procrastination Detection ────────────────────────────────────────
    final overdueHighPriority = tasks.where((t) {
      final deadline = t['deadline'] as int?;
      final priority = t['priority'] as int? ?? 2;
      return priority == 3 && deadline != null && deadline < now;
    }).length;

    final procrastination = overdueHighPriority >= 2;
    if (procrastination) {
      flags.add('procrastination: $overdueHighPriority overdue high-priority tasks');
    }

    // ── Overload Detection ───────────────────────────────────────────────
    final pendingCount = tasks.length;
    final overload = pendingCount >= 5 && currentStressLevel > 60.0;
    if (overload) {
      flags.add('overload: $pendingCount pending tasks at high stress');
    }

    // ── Streak Calculation ────────────────────────────────────────────────
    int streakDays = 0;
    
    // Sort history by date descending
    final sortedHistory = [...history]..sort((a, b) => 
        (b['date'] as String).compareTo(a['date'] as String));

    for (int i = 0; i < sortedHistory.length; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      
      if (sortedHistory.any((r) => r['date'] == dateStr)) {
        streakDays++;
      } else {
        break;
      }
    }

    // ── Routine Score ─────────────────────────────────────────────────────
    final activeDays = history.length;
    final double routineScore = math.min(100.0, (activeDays / 14.0) * 100.0);

    // ── Activity Score ────────────────────────────────────────────────────
    double activityScore = 50.0 + (streakDays * 5.0) - (procrastination ? 15.0 : 0.0) - (overload ? 10.0 : 0.0);
    activityScore = activityScore.clamp(0.0, 100.0);

    // ── Behavior Score (overall) ──────────────────────────────────────────
    double behaviorScore = (routineScore * 0.4) + (activityScore * 0.4) +
        (procrastination ? 0.0 : 10.0) + (overload ? 0.0 : 10.0);
    behaviorScore = behaviorScore.clamp(0.0, 100.0);

    // ── Persist Events ────────────────────────────────────────────────────
    if (procrastination) {
      await _db.saveBehaviorEvent(
        type: 'procrastination',
        intensity: math.min(1.0, overdueHighPriority / 5.0),
        metadata: '{"overdueCount": $overdueHighPriority}',
      );
    }
    if (overload) {
      await _db.saveBehaviorEvent(
        type: 'overload',
        intensity: math.min(1.0, pendingCount / 10.0),
        metadata: '{"pendingCount": $pendingCount}',
      );
    }
    if (streakDays >= 7) {
      await _db.saveBehaviorEvent(
        type: 'streak',
        intensity: 1.0,
        metadata: '{"streakDays": $streakDays}',
      );
    }

    return BehaviorResult(
      procrastination: procrastination,
      overload: overload,
      streakDays: streakDays,
      routineScore: routineScore,
      behaviorScore: behaviorScore,
      activityScore: activityScore,
      flags: flags,
    );
  }
}

final behaviorServiceProvider = BehaviorService();
