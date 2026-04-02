// lib/models/context_capsule.dart

enum SessionTheme {
  academicPressure,
  sleepIssues,
  socialStress,
  familyPressure,
  financialStress,
  selfDoubt,
  motivation,
  grief,
  anxiety,
  burnout,
  positiveProgress,
  goalAchievement,
}

class ContextCapsule {
  final String userId;
  final String date;                          // YYYY-MM-DD
  final String dominantEmotion;              // positive/neutral/negative
  final double averageStressLevel;           // 0-100
  final String primaryIntent;               // most frequent intent this week
  final List<String> behavioralFlags;       // ['overload', 'procrastination']
  final List<SessionTheme> sessionThemes;   // recurring topics
  final int consecutiveNegativeDays;        // 0-N
  final int totalMessagesThisWeek;
  final double cwsTrend;                    // +/- change from last week
  final Map<String, int> intentFrequency;  // counts per intent class
  final String? lastPositiveNote;           // anonymized positive context
  final int streakDays;
  final int totalXP;
  final String currentLevel;

  const ContextCapsule({
    required this.userId,
    required this.date,
    required this.dominantEmotion,
    required this.averageStressLevel,
    required this.primaryIntent,
    required this.behavioralFlags,
    required this.sessionThemes,
    required this.consecutiveNegativeDays,
    required this.totalMessagesThisWeek,
    required this.cwsTrend,
    required this.intentFrequency,
    this.lastPositiveNote,
    required this.streakDays,
    required this.totalXP,
    required this.currentLevel,
  });

  Map<String, dynamic> toMap() => {
    'user_id':                   userId,
    'date':                      date,
    'dominant_emotion':          dominantEmotion,
    'average_stress_level':      averageStressLevel,
    'primary_intent':            primaryIntent,
    'behavioral_flags':          behavioralFlags,
    'session_themes':            sessionThemes.map((t) => t.name).toList(),
    'consecutive_negative_days': consecutiveNegativeDays,
    'total_messages_this_week':  totalMessagesThisWeek,
    'cws_trend':                 cwsTrend,
    'intent_frequency':          intentFrequency,
    'last_positive_note':        lastPositiveNote,
    'streak_days':               streakDays,
    'total_xp':                  totalXP,
    'current_level':             currentLevel,
  };

  factory ContextCapsule.fromMap(Map<String, dynamic> map) => ContextCapsule(
    userId:                  map['user_id'],
    date:                    map['date'],
    dominantEmotion:         map['dominant_emotion'],
    averageStressLevel:      (map['average_stress_level'] as num).toDouble(),
    primaryIntent:           map['primary_intent'],
    behavioralFlags:         List<String>.from(map['behavioral_flags'] ?? []),
    sessionThemes:           (map['session_themes'] as List<dynamic>? ?? [])
        .map((t) => SessionTheme.values.firstWhere(
              (e) => e.name == t,
              orElse: () => SessionTheme.academicPressure,
            ))
        .toList(),
    consecutiveNegativeDays: map['consecutive_negative_days'] ?? 0,
    totalMessagesThisWeek:   map['total_messages_this_week'] ?? 0,
    cwsTrend:                (map['cws_trend'] as num?)?.toDouble() ?? 0.0,
    intentFrequency:         Map<String, int>.from(map['intent_frequency'] ?? {}),
    lastPositiveNote:        map['last_positive_note'],
    streakDays:              map['streak_days'] ?? 0,
    totalXP:                 map['total_xp'] ?? 0,
    currentLevel:            map['current_level'] ?? 'Awareness',
  );
}
