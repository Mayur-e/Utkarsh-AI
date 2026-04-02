// Assessment data for PHQ-9 and GAD-7 standardized questionnaires.

class AssessmentQuestion {
  final int id;
  final String text;
  final bool isCritical; // PHQ-9 Q9 only — thought of self-harm

  const AssessmentQuestion({
    required this.id,
    required this.text,
    this.isCritical = false,
  });
}

const List<AssessmentQuestion> kPhq9Questions = [
  AssessmentQuestion(id: 1, text: 'Little interest or pleasure in doing things'),
  AssessmentQuestion(id: 2, text: 'Feeling down, depressed, or hopeless'),
  AssessmentQuestion(id: 3, text: 'Trouble falling or staying asleep, or sleeping too much'),
  AssessmentQuestion(id: 4, text: 'Feeling tired or having little energy'),
  AssessmentQuestion(id: 5, text: 'Poor appetite or overeating'),
  AssessmentQuestion(
      id: 6,
      text: 'Feeling bad about yourself — or that you are a failure or have let yourself or your family down'),
  AssessmentQuestion(
      id: 7,
      text: 'Trouble concentrating on things, such as reading or watching television'),
  AssessmentQuestion(
      id: 8,
      text: 'Moving or speaking so slowly that other people could have noticed, or being so fidgety or restless that you have been moving around a lot more than usual'),
  AssessmentQuestion(
      id: 9,
      text: 'Thoughts that you would be better off dead, or of hurting yourself in some way',
      isCritical: true),
];

const List<AssessmentQuestion> kGad7Questions = [
  AssessmentQuestion(id: 1, text: 'Feeling nervous, anxious, or on edge'),
  AssessmentQuestion(id: 2, text: 'Not being able to stop or control worrying'),
  AssessmentQuestion(id: 3, text: 'Worrying too much about different things'),
  AssessmentQuestion(id: 4, text: 'Trouble relaxing'),
  AssessmentQuestion(id: 5, text: 'Being so restless that it is hard to sit still'),
  AssessmentQuestion(id: 6, text: 'Becoming easily annoyed or irritable'),
  AssessmentQuestion(id: 7, text: 'Feeling afraid as if something awful might happen'),
];

const List<({int value, String label})> kAssessmentOptions = [
  (value: 0, label: 'Not at all'),
  (value: 1, label: 'Several days'),
  (value: 2, label: 'More than half'),
  (value: 3, label: 'Nearly every day'),
];

enum AssessmentType { phq9, gad7 }
enum RiskAction { none, coaching, assessment, professionalAlert }

String phq9Severity(int score) {
  if (score <= 4) return 'Minimal';
  if (score <= 9) return 'Mild';
  if (score <= 14) return 'Moderate';
  if (score <= 19) return 'Moderately Severe';
  return 'Severe';
}

String gad7Severity(int score) {
  if (score <= 4) return 'Minimal';
  if (score <= 9) return 'Mild';
  if (score <= 14) return 'Moderate';
  return 'Severe';
}

class AssessmentResult {
  final AssessmentType type;
  final List<int> responses;
  final int score;
  final String severity;
  final int? q9Score; // PHQ-9 only
  final bool hasCrisisIndicator;
  final RiskAction riskAction;

  const AssessmentResult({
    required this.type,
    required this.responses,
    required this.score,
    required this.severity,
    this.q9Score,
    required this.hasCrisisIndicator,
    required this.riskAction,
  });
}
