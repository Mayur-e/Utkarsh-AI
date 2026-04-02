// lib/services/assessment/assessment_data.dart

class AssessmentQuestion {
  final int id;
  final String text;
  final bool isCritical;

  const AssessmentQuestion({
    required this.id,
    required this.text,
    this.isCritical = false,
  });
}

const List<AssessmentQuestion> phq9Questions = [
  AssessmentQuestion(id: 1, text: 'Little interest or pleasure in doing things'),
  AssessmentQuestion(id: 2, text: 'Feeling down, depressed, or hopeless'),
  AssessmentQuestion(id: 3, text: 'Trouble falling or staying asleep, or sleeping too much'),
  AssessmentQuestion(id: 4, text: 'Feeling tired or having little energy'),
  AssessmentQuestion(id: 5, text: 'Poor appetite or overeating'),
  AssessmentQuestion(id: 6, text: 'Feeling bad about yourself — or that you have let yourself or your family down'),
  AssessmentQuestion(id: 7, text: 'Trouble concentrating on things, such as reading or watching television'),
  AssessmentQuestion(id: 8, text: 'Moving or speaking so slowly that other people could have noticed? Or the opposite — being so fidgety or restless that you have been moving around a lot more than usual'),
  AssessmentQuestion(id: 9, text: 'Thoughts that you would be better off dead, or of hurting yourself in some way', isCritical: true),
];

const List<AssessmentQuestion> gad7Questions = [
  AssessmentQuestion(id: 1, text: 'Feeling nervous, anxious or on edge'),
  AssessmentQuestion(id: 2, text: 'Not being able to stop or control worrying'),
  AssessmentQuestion(id: 3, text: 'Worrying too much about different things'),
  AssessmentQuestion(id: 4, text: 'Trouble relaxing'),
  AssessmentQuestion(id: 5, text: 'Being so restless that it is hard to sit still'),
  AssessmentQuestion(id: 6, text: 'Becoming easily annoyed or irritable'),
  AssessmentQuestion(id: 7, text: 'Feeling afraid as if something awful might happen'),
];

const List<AssessmentQuestion> dailyCheckinQuestions = [
  AssessmentQuestion(id: 1, text: 'Overall, how would you rate your mood today?'),
  AssessmentQuestion(id: 2, text: 'How would you rate your energy and focus today?'),
  AssessmentQuestion(id: 3, text: 'How well did you handle your stress level today?'),
  AssessmentQuestion(id: 4, text: 'How refreshed do you feel after last night\'s sleep?'),
];

const List<AssessmentQuestion> weeklyReviewQuestions = [
  AssessmentQuestion(id: 1, text: 'How satisfied were you with your academic progress this week?'),
  AssessmentQuestion(id: 2, text: 'How connected have you felt with your friends and family this week?'),
  AssessmentQuestion(id: 3, text: 'How consistent were you with your daily routines and habits?'),
  AssessmentQuestion(id: 4, text: 'How well did you manage to balance work and relaxation this week?'),
  AssessmentQuestion(id: 5, text: 'How optimistic do you feel about the upcoming week?'),
];

enum AssessmentType { phq9, gad7, daily, weekly }
enum RiskAction { none, coaching, assessment, professionalAlert }

class AssessmentResult {
  final AssessmentType type;
  final List<int> responses;
  final int score;
  final String severity;
  final bool hasCrisisIndicator;
  final RiskAction riskAction;
  final DateTime timestamp;

  AssessmentResult({
    required this.type,
    required this.responses,
    required this.score,
    required this.severity,
    required this.hasCrisisIndicator,
    required this.riskAction,
    required this.timestamp,
  });
}

String getPHQ9Severity(int score) {
  if (score <= 4) return 'Minimal';
  if (score <= 9) return 'Mild';
  if (score <= 14) return 'Moderate';
  if (score <= 19) return 'Moderately Severe';
  return 'Severe';
}

String getGAD7Severity(int score) {
  if (score <= 4) return 'Minimal';
  if (score <= 9) return 'Mild';
  if (score <= 14) return 'Moderate';
  return 'Severe';
}

String getDailySeverity(int score) {
  if (score <= 4) return 'Very Low';
  if (score <= 8) return 'Low';
  if (score <= 12) return 'Stable';
  return 'Excellent';
}

String getWeeklySeverity(int score) {
  if (score <= 5) return 'Suboptimal';
  if (score <= 10) return 'Fair';
  if (score <= 15) return 'Good';
  return 'Balanced';
}
