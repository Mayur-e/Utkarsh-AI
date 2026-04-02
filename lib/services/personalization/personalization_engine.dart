import '../../models/user_profile.dart';

class PersonalizationEngine {
  PersonalizationEngine._();
  static final instance = PersonalizationEngine._();

  /// Build the full AI system prompt from user profile.
  /// Called before every Groq API or offline LLM request.
  String buildSystemPrompt(UserProfile profile) {
    final buffer = StringBuffer();

    // Core identity
    buffer.writeln('You are Utkarsh, an empathetic AI wellbeing companion.');
    buffer.writeln('');

    // User context
    buffer.writeln('ABOUT THIS USER:');
    buffer.writeln('Name: ${profile.displayName ?? "User"}');
    buffer.writeln('Age: ${profile.age} years old');
    if (profile.gender != null) buffer.writeln('Gender: ${profile.gender}');
    buffer.writeln('');

    // Academic/professional context
    buffer.writeln('PROFESSIONAL CONTEXT:');
    switch (profile.profession) {
      case Profession.collegeStudent:
        final c = profile.collegeProfile;
        buffer.writeln('Role: College Student');
        if (c != null) {
          if (c.stream != null) buffer.writeln('Stream: ${c.stream}');
          buffer.writeln('Year: ${c.yearOfStudy}${_ordinalSuffix(c.yearOfStudy)} year');
          if (c.upcomingEvents.isNotEmpty) {
            buffer.writeln('Upcoming events: ${c.upcomingEvents.join(', ')}');
          }
        }
        break;

      case Profession.schoolStudent:
        final s = profile.schoolProfile;
        buffer.writeln('Role: School Student');
        if (s != null) {
          buffer.writeln('Class: ${s.classNumber}th, ${s.board} Board');
        }
        break;

      case Profession.workingProfessional:
        final p = profile.professionalProfile;
        buffer.writeln('Role: Working Professional');
        if (p != null) {
          if (p.industry != null) buffer.writeln('Industry: ${p.industry}');
          if (p.role != null)     buffer.writeln('Role: ${p.role}');
          buffer.writeln('Work Style: ${p.workStyle}');
        }
        break;

      default:
        buffer.writeln('Role: ${profile.profession.name}');
    }
    buffer.writeln('');

    // Lifestyle context
    buffer.writeln('LIFESTYLE CONTEXT:');
    if (profile.stressTriggers.isNotEmpty) {
      buffer.writeln(
        'Known stress triggers: ${profile.stressTriggers.map((t) => t.name).join(', ')}',
      );
    }
    buffer.writeln('Social style: ${profile.socialPreference.name}');
    buffer.writeln('');

    // Communication style
    buffer.writeln('COMMUNICATION GUIDELINES:');
    buffer.writeln('Always address them as: ${profile.displayName ?? "User"}');
    switch (profile.responseStyle) {
      case ResponseStyle.warmSupportive:
        buffer.writeln('Tone: Warm, empathetic, encouraging. Use supportive language.');
        buffer.writeln('Format: Emotional acknowledgment first, then gentle suggestions.');
        break;
      case ResponseStyle.directPractical:
        buffer.writeln('Tone: Direct, practical, action-oriented. Skip lengthy preambles.');
        buffer.writeln('Format: Clear steps and specific advice. Be concise.');
        break;
      case ResponseStyle.analyticalStructured:
        buffer.writeln('Tone: Structured, logical, systematic. Use organized thinking.');
        buffer.writeln('Format: Break down problems clearly. Use structure when helpful.');
        break;
    }

    switch (profile.preferredLanguage) {
      case PreferredLanguage.hindi:
        buffer.writeln('Language: Respond in Hindi when user writes in Hindi.');
        break;
      case PreferredLanguage.hinglish:
        buffer.writeln('Language: Mix of Hindi and English (Hinglish) is preferred.');
        break;
      case PreferredLanguage.english:
        buffer.writeln('Language: English.');
        break;
    }

    buffer.writeln('Keep responses 2-4 sentences unless detail is explicitly needed.');
    buffer.writeln('Never diagnose. For serious mental health concerns, suggest professional support.');

    return buffer.toString();
  }

  /// Generate a context-aware greeting for first message of the day.
  String buildDailyGreeting(UserProfile profile) {
    final hour = DateTime.now().hour;
    final name = profile.displayName ?? 'there';

    String timeGreeting;
    if (hour < 12)      timeGreeting = 'Good morning';
    else if (hour < 17) timeGreeting = 'Good afternoon';
    else if (hour < 21) timeGreeting = 'Good evening';
    else                timeGreeting = 'Hey';

    // Academic context
    String contextual = '';
    if (profile.profession == Profession.collegeStudent) {
      final c = profile.collegeProfile;
      if (c != null && c.upcomingEvents.contains('exams')) {
        contextual = ' How are the exam preparations going?';
      } else if (c != null && c.upcomingEvents.contains('placements')) {
        contextual = ' How are the placement preparations coming along?';
      }
    }

    return '$timeGreeting, $name! 🌿$contextual How are you feeling today?';
  }

  String _ordinalSuffix(int n) {
    if (n == 1) return 'st';
    if (n == 2) return 'nd';
    if (n == 3) return 'rd';
    return 'th';
  }

  /// Adjust CWS weights based on user profile context.
  Map<String, double> getContextualCWSWeights(UserProfile profile) {
    var weights = {
      'emotion':  0.25,
      'stress':   0.15,
      'tasks':    0.15,
      'activity': 0.10,
      'routine':  0.10,
      'behavior': 0.15,
      'growth':   0.10,
    };

    // Exam period: increase task and stress weight
    if (profile.collegeProfile?.upcomingEvents.contains('exams') == true) {
      weights['tasks']  = 0.20;
      weights['stress'] = 0.20;
      weights['growth'] = 0.05;
    }

    // High stress triggers: increase emotion weight
    if (profile.stressTriggers.length >= 3) {
      weights['emotion'] = 0.30;
      weights['stress']  = 0.20;
      weights['activity'] = 0.05;
    }

    // Normalize to sum to 1.0
    final total = weights.values.reduce((a, b) => a + b);
    weights = weights.map((k, v) => MapEntry(k, v / total));

    return weights;
  }
}
