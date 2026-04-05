import 'dart:convert';
import 'package:flutter/material.dart';

enum Profession {
  collegeStudent,
  schoolStudent,
  workingProfessional,
  jobSeeker,
  researcher,
  other,
}

enum ResponseStyle {
  warmSupportive,
  directPractical,
  analyticalStructured,
}

enum PreferredLanguage {
  english,
  hindi,
  hinglish,
}

enum StressTrigger {
  exams,
  deadlines,
  socialSituations,
  familyPressure,
  financialStress,
  careerUncertainty,
  comparison,
  sleepDeprivation,
  healthConcerns,
  workload,
}

enum ActivityLevel {
  sedentary,      // Little to no exercise
  light,          // 1-2 times per week
  moderate,       // 3-4 times per week
  active,         // Daily exercise
}

enum SocialPreference {
  introvert,
  ambivert,
  extrovert,
}

class CollegeProfile {
  final String? universityName;
  final String? stream;            // CS, Mechanical, Commerce, etc.
  final int yearOfStudy;           // 1, 2, 3, 4, 5
  final String? semester;
  final List<String> upcomingEvents; // ['exams', 'placements', 'internship']

  const CollegeProfile({
    this.universityName,
    this.stream,
    required this.yearOfStudy,
    this.semester,
    this.upcomingEvents = const [],
  });

  Map<String, dynamic> toMap() => {
    'university_name':  universityName,
    'stream':           stream,
    'year_of_study':    yearOfStudy,
    'semester':         semester,
    'upcoming_events':  upcomingEvents,
  };

  factory CollegeProfile.fromMap(Map<String, dynamic> m) => CollegeProfile(
    universityName: m['university_name'],
    stream:         m['stream'],
    yearOfStudy:    m['year_of_study'] ?? 1,
    semester:       m['semester'],
    upcomingEvents: List<String>.from(m['upcoming_events'] ?? []),
  );
}

class SchoolProfile {
  final String? schoolName;
  final int classNumber;           // 6-12
  final String board;              // CBSE, ICSE, State, IB

  const SchoolProfile({
    this.schoolName,
    required this.classNumber,
    required this.board,
  });

  Map<String, dynamic> toMap() => {
    'school_name':  schoolName,
    'class_number': classNumber,
    'board':        board,
  };

  factory SchoolProfile.fromMap(Map<String, dynamic> m) => SchoolProfile(
    schoolName:  m['school_name'],
    classNumber: m['class_number'] ?? 10,
    board:       m['board'] ?? 'CBSE',
  );
}

class ProfessionalProfile {
  final String? industry;
  final String? role;
  final int? yearsOfExperience;
  final String workStyle;          // remote, office, hybrid

  const ProfessionalProfile({
    this.industry,
    this.role,
    this.yearsOfExperience,
    required this.workStyle,
  });

  Map<String, dynamic> toMap() => {
    'industry':              industry,
    'role':                  role,
    'years_of_experience':   yearsOfExperience,
    'work_style':            workStyle,
  };

  factory ProfessionalProfile.fromMap(Map<String, dynamic> m) => ProfessionalProfile(
    industry:          m['industry'],
    role:              m['role'],
    yearsOfExperience: m['years_of_experience'],
    workStyle:         m['work_style'] ?? 'office',
  );
}

class EmergencyContact {
  final String name;
  final String number;
  final String? relation;

  const EmergencyContact({required this.name, required this.number, this.relation});

  Map<String, dynamic> toMap() => {
    'name': name,
    'number': number,
    'relation': relation,
  };

  factory EmergencyContact.fromMap(Map<String, dynamic> m) => EmergencyContact(
    name: m['name'] ?? '',
    number: m['number'] ?? '',
    relation: m['relation'],
  );
}

class UserProfile {
  final String id;

  // Personal identity
  final String? displayName;
  final int age;
  final String? gender;            // optional
  final PreferredLanguage preferredLanguage;

  // Profession
  final Profession profession;
  final CollegeProfile? collegeProfile;
  final SchoolProfile? schoolProfile;
  final ProfessionalProfile? professionalProfile;

  // Lifestyle
  final TimeOfDay? typicalWakeTime;
  final TimeOfDay? typicalSleepTime;
  final double dailyStudyOrWorkHours;
  final ActivityLevel activityLevel;
  final SocialPreference socialPreference;
  final List<StressTrigger> stressTriggers;

  // AI preferences
  final ResponseStyle responseStyle;
  final bool voiceEnabled;
  final bool ttsEnabled;

  // Health baseline (optional)
  final int? baselineStressLevel;    // 1-10
  final int? baselineSleepQuality;   // 1-5
  final String? healthNotes;
  final List<EmergencyContact> emergencyContacts;

  // Gamification
  final int totalXP;
  final String currentLevel;
  final bool onboardingDone;
  final int streakDays;
  final String? lastActiveDate;

  // Notification preferences
  final bool notificationsEnabled;
  final bool dailyMoodNotification;
  final bool weeklyReviewNotification;
  final bool taskReminders;
  final bool streakReminders;
  final bool aiLearningEnabled;
  final bool onlineAiEnabled;
  final bool offlineLlmEnabled;

  // Timestamps
  final int createdAt;
  final int? lastActiveAt;

  // Convenience getters for scheduler
  int? get wakeTimeHour => typicalWakeTime?.hour;
  int? get sleepTimeHour => typicalSleepTime?.hour;

  const UserProfile({
    required this.id,
    this.displayName,
    this.age = 20,
    this.gender,
    this.preferredLanguage = PreferredLanguage.english,
    this.profession = Profession.collegeStudent,
    this.collegeProfile,
    this.schoolProfile,
    this.professionalProfile,
    this.typicalWakeTime,
    this.typicalSleepTime,
    this.dailyStudyOrWorkHours = 6,
    this.activityLevel = ActivityLevel.light,
    this.socialPreference = SocialPreference.ambivert,
    this.stressTriggers = const [],
    this.responseStyle = ResponseStyle.warmSupportive,
    this.voiceEnabled = false,
    this.ttsEnabled = true,
    this.baselineStressLevel,
    this.baselineSleepQuality,
    this.healthNotes,
    this.totalXP = 0,
    this.currentLevel = 'Awareness',
    this.onboardingDone = false,
    this.streakDays = 0,
    this.lastActiveDate,
    this.notificationsEnabled = true,
    this.dailyMoodNotification = true,
    this.weeklyReviewNotification = true,
    this.taskReminders = true,
    this.streakReminders = true,
    this.aiLearningEnabled = true,
    this.onlineAiEnabled = true,
    this.offlineLlmEnabled = true,
    this.emergencyContacts = const [],
    required this.createdAt,
    this.lastActiveAt,
  });

  Map<String, dynamic> toMap() => {
    'id':                         id,
    'display_name':               displayName,
    'age':                        age,
    'gender':                     gender,
    'preferred_language':         preferredLanguage.name,
    'profession':                 profession.name,
    'college_profile':            collegeProfile != null ? jsonEncode(collegeProfile!.toMap()) : null,
    'school_profile':             schoolProfile != null ? jsonEncode(schoolProfile!.toMap()) : null,
    'professional_profile':       professionalProfile != null ? jsonEncode(professionalProfile!.toMap()) : null,
    'wake_time_hour':             typicalWakeTime?.hour,
    'wake_time_minute':           typicalWakeTime?.minute,
    'sleep_time_hour':            typicalSleepTime?.hour,
    'sleep_time_minute':          typicalSleepTime?.minute,
    'daily_hours':                dailyStudyOrWorkHours,
    'activity_level':             activityLevel.name,
    'social_preference':          socialPreference.name,
    'stress_triggers':            jsonEncode(stressTriggers.map((t) => t.name).toList()),
    'response_style':             responseStyle.name,
    'voice_enabled':              voiceEnabled ? 1 : 0,
    'tts_enabled':                ttsEnabled ? 1 : 0,
    'baseline_stress':            baselineStressLevel,
    'baseline_sleep':             baselineSleepQuality,
    'health_notes':               healthNotes,
    'total_xp':                   totalXP,
    'current_level':              currentLevel,
    'onboarding_done':            onboardingDone ? 1 : 0,
    'streak_days':                streakDays,
    'last_active_date':           lastActiveDate,
    'notifications_enabled':      notificationsEnabled ? 1 : 0,
    'daily_mood_notification':    dailyMoodNotification ? 1 : 0,
    'weekly_review_notification': weeklyReviewNotification ? 1 : 0,
    'task_reminders':             taskReminders ? 1 : 0,
    'streak_reminders':           streakReminders ? 1 : 0,
    'ai_learning_enabled':        aiLearningEnabled ? 1 : 0,
    'online_ai_enabled':         onlineAiEnabled ? 1 : 0,
    'offline_llm_enabled':        offlineLlmEnabled ? 1 : 0,
    'emergency_contacts':         jsonEncode(emergencyContacts.map((c) => c.toMap()).toList()),
    'created_at':                 createdAt,
    'last_active_at':             lastActiveAt,
  };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    id:                    map['id'] ?? 'local_user',
    displayName:           map['display_name'],
    age:                   map['age'] ?? 20,
    gender:                map['gender'],
    preferredLanguage:     PreferredLanguage.values.firstWhere((e) => e.name == map['preferred_language'], orElse: () => PreferredLanguage.english),
    profession:            Profession.values.firstWhere((e) => e.name == map['profession'], orElse: () => Profession.collegeStudent),
    collegeProfile:        map['college_profile'] != null ? CollegeProfile.fromMap(jsonDecode(map['college_profile'])) : null,
    schoolProfile:         map['school_profile'] != null ? SchoolProfile.fromMap(jsonDecode(map['school_profile'])) : null,
    professionalProfile:   map['professional_profile'] != null ? ProfessionalProfile.fromMap(jsonDecode(map['professional_profile'])) : null,
    typicalWakeTime:       map['wake_time_hour'] != null ? TimeOfDay(hour: map['wake_time_hour'], minute: map['wake_time_minute'] ?? 0) : null,
    typicalSleepTime:      map['sleep_time_hour'] != null ? TimeOfDay(hour: map['sleep_time_hour'], minute: map['sleep_time_minute'] ?? 0) : null,
    dailyStudyOrWorkHours: (map['daily_hours'] ?? 6).toDouble(),
    activityLevel:         ActivityLevel.values.firstWhere((e) => e.name == map['activity_level'], orElse: () => ActivityLevel.light),
    socialPreference:      SocialPreference.values.firstWhere((e) => e.name == map['social_preference'], orElse: () => SocialPreference.ambivert),
    stressTriggers:        map['stress_triggers'] != null ? (jsonDecode(map['stress_triggers']) as List).map((s) => StressTrigger.values.firstWhere((e) => e.name == s)).toList() : [],
    responseStyle:         ResponseStyle.values.firstWhere((e) => e.name == map['response_style'], orElse: () => ResponseStyle.warmSupportive),
    voiceEnabled:          (map['voice_enabled'] ?? 0) == 1,
    ttsEnabled:            (map['tts_enabled'] ?? 1) == 1,
    baselineStressLevel:   map['baseline_stress'],
    baselineSleepQuality:  map['baseline_sleep'],
    healthNotes:           map['health_notes'],
    totalXP:               map['total_xp'] ?? 0,
    currentLevel:          map['current_level'] ?? 'Awareness',
    onboardingDone:        (map['onboarding_done'] ?? 0) == 1,
    streakDays:            map['streak_days'] ?? 0,
    lastActiveDate:        map['last_active_date'],
    notificationsEnabled:  (map['notifications_enabled'] ?? 1) == 1,
    dailyMoodNotification: (map['daily_mood_notification'] ?? 1) == 1,
    weeklyReviewNotification: (map['weekly_review_notification'] ?? 1) == 1,
    taskReminders:         (map['task_reminders'] ?? 1) == 1,
    streakReminders:       (map['streak_reminders'] ?? 1) == 1,
    aiLearningEnabled:     (map['ai_learning_enabled'] ?? 1) == 1,
    onlineAiEnabled:       (map['online_ai_enabled'] ?? 1) == 1,
    offlineLlmEnabled:      (map['offline_llm_enabled'] ?? 1) == 1,
    emergencyContacts:     map['emergency_contacts'] != null ? (jsonDecode(map['emergency_contacts']) as List).map((c) => EmergencyContact.fromMap(c)).toList() : [],
    createdAt:             map['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
    lastActiveAt:          map['last_active_at'],
  );
}
