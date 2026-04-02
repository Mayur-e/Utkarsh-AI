// lib/services/context/context_builder_service.dart

import '../../models/context_capsule.dart';
import '../storage/database_service.dart';


class ContextBuilderService {
  ContextBuilderService._();
  static final instance = ContextBuilderService._();

  final _db = databaseServiceProvider;

  /// Build a context capsule from the last 7 days of local data.
  /// Called after each chat session and before sync.
  Future<ContextCapsule> buildWeeklyCapsule(String userId) async {
    final messages  = await _db.getMessagesLastNDays(7);
    final wellbeingHistory = await _db.getWellbeingHistory(7);
    final profile   = await _db.getProfile();

    // Dominant emotion from message emotion_labels
    final emotionCounts = <String, int>{};
    final intentCounts  = <String, int>{};
    double totalStress  = 0;

    for (final raw in messages) {
      if (raw['role'] != 'user') continue;
      
      final label = raw['emotion_label'] as String? ?? 'neutral';
      emotionCounts[label] = (emotionCounts[label] ?? 0) + 1;
      
      totalStress += (raw['stress_level'] as num?)?.toDouble() ?? 0.0;

      final intent = raw['intent_class'] as String? ?? 'casual';
      intentCounts[intent] = (intentCounts[intent] ?? 0) + 1;
    }

    final dominantEmotion = emotionCounts.entries.isEmpty
        ? 'neutral'
        : emotionCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    final primaryIntent = intentCounts.entries.isEmpty
        ? 'casual'
        : intentCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    final userMessages = messages.where((m) => m['role'] == 'user');
    final avgStress = userMessages.isEmpty
        ? 0.0
        : totalStress / userMessages.length;

    // CWS trend
    double cwsTrend = 0;
    if (wellbeingHistory.length >= 2) {
      final latest = (wellbeingHistory.first['cws_score'] as num).toDouble();
      final oldest = (wellbeingHistory.last['cws_score'] as num).toDouble();
      cwsTrend = latest - oldest;
    }

    // Consecutive negative days
    int consecNeg = 0;
    for (final rec in wellbeingHistory) {
      final risk = rec['risk_level'] as String?;
      if (risk == 'red' || risk == 'orange') {
        consecNeg++;
      } else {
        break;
      }
    }

    // Session themes (simplified keyword detection)
    final themes = _detectThemes(messages.map((m) => m['content'] as String).toList());

    // Behavioral flags
    final flags = <String>[];
    final activeTasks = await _db.getActiveTasks();
    final overdue = activeTasks.where((t) {
      final deadline = t['deadline'] as int?;
      final priority = t['priority'] as int? ?? 2;
      return priority == 3 &&
             deadline != null &&
             deadline < DateTime.now().millisecondsSinceEpoch;
    }).length;

    if (overdue >= 2) flags.add('procrastination');
    if (activeTasks.length >= 5 && avgStress > 60) flags.add('overload');

    return ContextCapsule(
      userId:                  userId,
      date:                    DateTime.now().toIso8601String().split('T')[0],
      dominantEmotion:         dominantEmotion,
      averageStressLevel:      avgStress,
      primaryIntent:           primaryIntent,
      behavioralFlags:         flags,
      sessionThemes:           themes,
      consecutiveNegativeDays: consecNeg,
      totalMessagesThisWeek:   userMessages.length,
      cwsTrend:                cwsTrend,
      intentFrequency:         intentCounts,
      streakDays:              profile?['streak_days'] ?? 0,
      totalXP:                 profile?['total_xp'] ?? 0,
      currentLevel:            profile?['current_level'] ?? 'Awareness',
    );
  }

  List<SessionTheme> _detectThemes(List<String> messages) {
    final joined = messages.join(' ').toLowerCase();
    final themes  = <SessionTheme>[];
    final themeKeywords = {
      SessionTheme.academicPressure: ['exam', 'assignment', 'study', 'viva', 'marks', 'grade'],
      SessionTheme.sleepIssues:      ['sleep', 'tired', 'exhausted', 'awake', 'insomnia'],
      SessionTheme.socialStress:     ['friends', 'relationship', 'alone', 'lonely', 'social'],
      SessionTheme.burnout:          ['burnout', 'overwhelmed', 'can\'t anymore', 'giving up'],
      SessionTheme.motivation:       ['motivated', 'goal', 'focus', 'determined', 'progress'],
      SessionTheme.anxiety:          ['anxious', 'worry', 'nervous', 'panic', 'fear'],
    };

    for (final entry in themeKeywords.entries) {
      if (entry.value.any((kw) => joined.contains(kw))) {
        themes.add(entry.key);
      }
    }
    return themes;
  }

  /// Generate a personalized welcome-back message for new device/session
  /// using the restored context capsule.
  String buildContextGreeting(ContextCapsule capsule, String userName) {
    final parts = <String>[];

    // Stress context
    if (capsule.consecutiveNegativeDays >= 3) {
      parts.add(
        'I remember you\'ve been going through a tough stretch lately, $userName. '
        'I\'m here and I\'ve got you.',
      );
    } else if (capsule.cwsTrend > 10) {
      parts.add(
        'Welcome back, $userName! You\'ve been making real progress — '
        'your wellbeing score has been climbing.',
      );
    } else {
      parts.add('Good to see you again, $userName! 🌿');
    }

    // Streak context
    if (capsule.streakDays >= 7) {
      parts.add('Your ${capsule.streakDays}-day streak is still going strong!');
    }

    // Theme context
    if (capsule.sessionThemes.contains(SessionTheme.academicPressure)) {
      parts.add('How\'s the academic pressure feeling today?');
    } else {
      parts.add('How are you feeling today?');
    }

    return parts.join(' ');
  }
}
