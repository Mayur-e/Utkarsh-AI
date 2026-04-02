// lib/models/user_profile.dart

class UserProfile {
  final String id;
  final String? displayName;
  final int? age;
  final String? profession;
  final String? institution;
  final String? yearOfStudy;
  final int totalXP;
  final String currentLevel;
  final bool onboardingDone;
  final int streakDays;

  const UserProfile({
    required this.id,
    this.displayName,
    this.age,
    this.profession,
    this.institution,
    this.yearOfStudy,
    this.totalXP = 0,
    this.currentLevel = 'Awareness',
    this.onboardingDone = false,
    this.streakDays = 0,
  });

  Map<String, dynamic> toMap() => {
    'id':              id,
    'display_name':    displayName,
    'age':             age,
    'profession':      profession,
    'institution':     institution,
    'year_of_study':   yearOfStudy,
    'total_xp':        totalXP,
    'current_level':   currentLevel,
    'onboarding_done': onboardingDone ? 1 : 0,
    'streak_days':     streakDays,
  };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    id:             map['id'] ?? 'local_user',
    displayName:    map['display_name'],
    age:            map['age'],
    profession:     map['profession'],
    institution:    map['institution'],
    yearOfStudy:    map['year_of_study'],
    totalXP:        map['total_xp'] ?? 0,
    currentLevel:   map['current_level'] ?? 'Awareness',
    onboardingDone: (map['onboarding_done'] ?? 0) == 1,
    streakDays:     map['streak_days'] ?? 0,
  );
}
