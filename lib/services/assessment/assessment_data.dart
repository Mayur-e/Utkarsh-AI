// lib/services/assessment/assessment_data.dart

enum AssessmentType {
  dailyMood,
  dailyStress,
  weeklyReview,
  phq9,
  gad7,
  monthlyDeep,
}

enum ResponseScale {
  emoji5,         // 😢 😞 😐 😊 😄
  likert4,        // Not at all / Several days / More than half / Nearly every day
  numeric10,      // 1–10 slider
  yesNo,          // Yes / No
  frequency5,     // Never / Rarely / Sometimes / Often / Always
}

class AssessmentQuestion {
  final String id;
  final String text;
  final ResponseScale scale;
  final bool isCritical;          // PHQ-9 Q9, GAD-7 Q7
  final String? contextHint;      // Helper text shown below question

  const AssessmentQuestion({
    required this.id,
    required this.text,
    required this.scale,
    this.isCritical = false,
    this.contextHint,
  });
}

class AssessmentDefinition {
  final AssessmentType type;
  final String title;
  final String subtitle;
  final List<AssessmentQuestion> questions;
  final int estimatedMinutes;
  final bool isClinicallValidated;
  final String? source;           // "PHQ-9 © Pfizer Inc."

  const AssessmentDefinition({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.questions,
    required this.estimatedMinutes,
    this.isClinicallValidated = false,
    this.source,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// DAILY MOOD CHECK (5 questions, emoji scale, ~1 minute)
// ─────────────────────────────────────────────────────────────────────────────

const kDailyMoodAssessment = AssessmentDefinition(
  type:               AssessmentType.dailyMood,
  title:              'Daily Mood Check',
  subtitle:           'Quick 5-question check-in for today',
  estimatedMinutes:   1,
  questions: [
    AssessmentQuestion(
      id:    'dm_1',
      text:  'How are you feeling overall right now?',
      scale: ResponseScale.emoji5,
    ),
    AssessmentQuestion(
      id:    'dm_2',
      text:  'How was your energy level today?',
      scale: ResponseScale.emoji5,
    ),
    AssessmentQuestion(
      id:    'dm_3',
      text:  'How connected did you feel to others today?',
      scale: ResponseScale.emoji5,
    ),
    AssessmentQuestion(
      id:    'dm_4',
      text:  'How hopeful do you feel about tomorrow?',
      scale: ResponseScale.emoji5,
    ),
    AssessmentQuestion(
      id:    'dm_5',
      text:  'How satisfied are you with what you did today?',
      scale: ResponseScale.emoji5,
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// DAILY STRESS CHECK (3 questions, ~30 seconds)
// ─────────────────────────────────────────────────────────────────────────────

const kDailyStressAssessment = AssessmentDefinition(
  type:             AssessmentType.dailyStress,
  title:            'Stress',
  subtitle:         'Quick 3-question check',
  estimatedMinutes: 1,
  questions: [
    AssessmentQuestion(
      id:    'ds_1',
      text:  'How stressed did you feel today (0 = calm, 10 = overwhelmed)?',
      scale: ResponseScale.numeric10,
    ),
    AssessmentQuestion(
      id:    'ds_2',
      text:  'Was there a specific thing causing your stress today?',
      scale: ResponseScale.yesNo,
    ),
    AssessmentQuestion(
      id:    'ds_3',
      text:  'How well did you manage your stress today?',
      scale: ResponseScale.emoji5,
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// WEEKLY REVIEW (10 questions, ~3 minutes)
// ─────────────────────────────────────────────────────────────────────────────

const kWeeklyReviewAssessment = AssessmentDefinition(
  type:             AssessmentType.weeklyReview,
  title:            'Weekly Wellbeing Review',
  subtitle:         'Your comprehensive weekly check-in',
  estimatedMinutes: 3,
  questions: [
    AssessmentQuestion(
      id:    'wr_1',
      text:  'How would you rate your overall wellbeing this week?',
      scale: ResponseScale.numeric10,
    ),
    AssessmentQuestion(
      id:    'wr_2',
      text:  'How well did you sleep on most nights this week?',
      scale: ResponseScale.emoji5,
    ),
    AssessmentQuestion(
      id:    'wr_3',
      text:  'How manageable was your workload this week?',
      scale: ResponseScale.emoji5,
    ),
    AssessmentQuestion(
      id:    'wr_4',
      text:  'How often did you feel overwhelmed this week?',
      scale: ResponseScale.frequency5,
    ),
    AssessmentQuestion(
      id:    'wr_5',
      text:  'How connected did you feel to your goals this week?',
      scale: ResponseScale.emoji5,
    ),
    AssessmentQuestion(
      id:    'wr_6',
      text:  'How often did you engage in activities you enjoy?',
      scale: ResponseScale.frequency5,
    ),
    AssessmentQuestion(
      id:    'wr_7',
      text:  'How well did you take care of your physical health this week?',
      scale: ResponseScale.emoji5,
    ),
    AssessmentQuestion(
      id:    'wr_8',
      text:  'How supported did you feel by people around you?',
      scale: ResponseScale.emoji5,
    ),
    AssessmentQuestion(
      id:    'wr_9',
      text:  'How often did you feel positive about the future this week?',
      scale: ResponseScale.frequency5,
    ),
    AssessmentQuestion(
      id:    'wr_10',
      text:  'Overall, was this week better, similar, or worse than last week?',
      scale: ResponseScale.emoji5,
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// PHQ-9 (9 questions, clinically validated)
// ─────────────────────────────────────────────────────────────────────────────

const kPhq9Assessment = AssessmentDefinition(
  type:                  AssessmentType.phq9,
  title:                 'Wellbeing Assessment',
  subtitle:              'Over the last 2 weeks, how often have you been bothered by the following?',
  estimatedMinutes:      3,
  isClinicallValidated:  true,
  source:                'PHQ-9 © Pfizer Inc.',
  questions: [
    AssessmentQuestion(
      id:    'phq_1',
      text:  'Little interest or pleasure in doing things?',
      scale: ResponseScale.likert4,
    ),
    AssessmentQuestion(
      id:    'phq_2',
      text:  'Feeling down, depressed, or hopeless?',
      scale: ResponseScale.likert4,
    ),
    AssessmentQuestion(
      id:    'phq_3',
      text:  'Trouble falling or staying asleep, or sleeping too much?',
      scale: ResponseScale.likert4,
    ),
    AssessmentQuestion(
      id:    'phq_4',
      text:  'Feeling tired or having little energy?',
      scale: ResponseScale.likert4,
    ),
    AssessmentQuestion(
      id:    'phq_5',
      text:  'Poor appetite or overeating?',
      scale: ResponseScale.likert4,
    ),
    AssessmentQuestion(
      id:    'phq_6',
      text:  'Feeling bad about yourself — or that you are a failure or have let yourself or your family down?',
      scale: ResponseScale.likert4,
    ),
    AssessmentQuestion(
      id:    'phq_7',
      text:  'Trouble concentrating on things, such as reading or studying?',
      scale: ResponseScale.likert4,
    ),
    AssessmentQuestion(
      id:    'phq_8',
      text:  'Moving or speaking so slowly that other people could have noticed? Or so fidgety and restless that you\'ve been moving more than usual?',
      scale: ResponseScale.likert4,
    ),
    AssessmentQuestion(
      id:          'phq_9',
      text:        'Thoughts that you would be better off dead, or of hurting yourself in some way?',
      scale:       ResponseScale.likert4,
      isCritical:  true,            // ⚠️ Any answer > 0 → CrisisModal
      contextHint: 'This question helps us ensure your safety.',
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// GAD-7 (7 questions, clinically validated)
// ─────────────────────────────────────────────────────────────────────────────

const kGad7Assessment = AssessmentDefinition(
  type:                  AssessmentType.gad7,
  title:                 'Anxiety Check',
  subtitle:              'Over the last 2 weeks, how often have you been bothered by the following?',
  estimatedMinutes:      2,
  isClinicallValidated:  true,
  source:                'GAD-7 © Pfizer Inc.',
  questions: [
    AssessmentQuestion(id: 'gad_1', text: 'Feeling nervous, anxious, or on edge?',                        scale: ResponseScale.likert4),
    AssessmentQuestion(id: 'gad_2', text: 'Not being able to stop or control worrying?',                   scale: ResponseScale.likert4),
    AssessmentQuestion(id: 'gad_3', text: 'Worrying too much about different things?',                     scale: ResponseScale.likert4),
    AssessmentQuestion(id: 'gad_4', text: 'Trouble relaxing?',                                             scale: ResponseScale.likert4),
    AssessmentQuestion(id: 'gad_5', text: 'Being so restless that it is hard to sit still?',              scale: ResponseScale.likert4),
    AssessmentQuestion(id: 'gad_6', text: 'Becoming easily annoyed or irritable?',                        scale: ResponseScale.likert4),
    AssessmentQuestion(id: 'gad_7', text: 'Feeling afraid, as if something awful might happen?',          scale: ResponseScale.likert4),
  ],
);

class AssessmentResult {
  final double score;
  final String severity;
  final bool requiresCrisisIntervention;
  final bool requiresProfessionalReferral;
  final List<String> recommendations;

  const AssessmentResult({
    required this.score,
    required this.severity,
    required this.requiresCrisisIntervention,
    required this.requiresProfessionalReferral,
    required this.recommendations,
  });
}
