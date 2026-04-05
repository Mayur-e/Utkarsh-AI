import 'package:flutter/material.dart';
import '../../../services/storage/database_service.dart';
import '../auth/auth_service.dart';

// ── XP Table ──────────────────────────────────────────────────────────────

const Map<String, int> kXpRewards = {
  'TASK_COMPLETED': 10,
  'REFLECTION_ADDED': 5,
  'STRESS_REDUCED': 15,
  'WEEKLY_STREAK': 20,
  'ASSESSMENT_COMPLETE': 8,
  'DAILY_CHECKIN': 3,
  'MOOD_IMPROVED': 10,
};

// ── Level Definitions ──────────────────────────────────────────────────────

class LevelInfo {
  final String name;
  final String emoji;
  final Color color;
  final int minXP;
  final int maxXP; // -1 = infinite

  const LevelInfo({
    required this.name,
    required this.emoji,
    required this.color,
    required this.minXP,
    required this.maxXP,
  });
}

const List<LevelInfo> kLevels = [
  LevelInfo(name: 'Awareness',   emoji: '🌱', color: Color(0xFF9E9E9E), minXP: 0,    maxXP: 100),
  LevelInfo(name: 'Stabilizing', emoji: '🌿', color: Color(0xFF42A5F5), minXP: 100,  maxXP: 300),
  LevelInfo(name: 'Improving',   emoji: '🌳', color: Color(0xFF66BB6A), minXP: 300,  maxXP: 700),
  LevelInfo(name: 'Resilient',   emoji: '🌟', color: Color(0xFFFFA726), minXP: 700,  maxXP: 1500),
  LevelInfo(name: 'Flourishing', emoji: '✨', color: Color(0xFFAB47BC), minXP: 1500, maxXP: -1),
];

class UserLevel {
  final LevelInfo current;
  final LevelInfo? next;
  final int totalXP;
  final int? xpToNext;
  final double progressPercent;

  const UserLevel({
    required this.current,
    required this.next,
    required this.totalXP,
    required this.xpToNext,
    required this.progressPercent,
  });
}

// ── XP Service ────────────────────────────────────────────────────────────

class XPService {
  XPService._();
  static final XPService instance = XPService._();

  Future<int> award(String action, [String? userId]) async {
    final uid = userId ?? AuthService.instance.currentUser?.id;
    final xp = kXpRewards[action] ?? 0;
    if (xp == 0) return 0;
    await databaseServiceProvider.addXP(action, xp, uid);
    return xp;
  }

  Future<UserLevel> getLevelInfo([String? userId]) async {
    final uid = userId ?? AuthService.instance.currentUser?.id;
    final totalXP = await databaseServiceProvider.getTotalXP(uid);
    final current = kLevels.lastWhere((l) => totalXP >= l.minXP,
        orElse: () => kLevels.first);
    final nextIdx = kLevels.indexOf(current) + 1;
    final next = nextIdx < kLevels.length ? kLevels[nextIdx] : null;
    final xpInLevel = totalXP - current.minXP;
    final levelRange =
        current.maxXP == -1 ? 1 : current.maxXP - current.minXP;
    final progress =
        (xpInLevel / levelRange * 100).clamp(0, 100).toDouble();
    final xpToNext = next != null ? next.minXP - totalXP : null;

    return UserLevel(
      current: current,
      next: next,
      totalXP: totalXP,
      xpToNext: xpToNext,
      progressPercent: progress,
    );
  }

  Future<bool> checkAndAwardStressReduction([String? userId]) async {
    final uid = userId ?? AuthService.instance.currentUser?.id;
    final h = await databaseServiceProvider.getWellbeingHistory(2, uid);
    if (h.length >= 2) {
      final delta = (h[0]['cws_score'] as num) - (h[1]['cws_score'] as num);
      if (delta >= 5) {
        await award('STRESS_REDUCED', uid);
        return true;
      }
    }
    return false;
  }

  Future<bool> checkAndAwardWeeklyStreak([String? userId]) async {
    final uid = userId ?? AuthService.instance.currentUser?.id;
    final h = await databaseServiceProvider.getWellbeingHistory(7, uid);
    if (h.length >= 7) {
      await award('WEEKLY_STREAK', uid);
      return true;
    }
    return false;
  }

  Future<void> onTaskCompleted([String? userId]) async {
    await award('TASK_COMPLETED', userId);
  }

  Future<void> onDailyCheckin([String? userId]) async {
    final uid = userId ?? AuthService.instance.currentUser?.id;
    final alreadyAwarded = await databaseServiceProvider.hasAwardedDailyCheckinToday(uid);
    if (!alreadyAwarded) {
      await award('DAILY_CHECKIN', uid);
    }
  }
}

// Global singleton accessor
final xpService = XPService.instance;
