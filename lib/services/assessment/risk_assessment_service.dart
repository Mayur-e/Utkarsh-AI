// lib/services/assessment/risk_assessment_service.dart

import 'assessment_data.dart';

class AssessmentScorer {
  static AssessmentResult scorePhq9(List<int> responses) {
    if (responses.length != 9) throw Exception('Incomplete PHQ-9');
    final total = responses.reduce((a, b) => a + b);
    final q9    = responses[8];

    String severity;
    if (total >= 20)      severity = 'Severe Depression';
    else if (total >= 15) severity = 'Moderately Severe Depression';
    else if (total >= 10) severity = 'Moderate Depression';
    else if (total >= 5)  severity = 'Mild Depression';
    else                  severity = 'Minimal Depression';

    return AssessmentResult(
      score:                       total.toDouble(),
      severity:                    severity,
      requiresCrisisIntervention:  q9 > 0 || total >= 20,
      requiresProfessionalReferral:total >= 10,
      recommendations:             _phq9Recommendations(severity, q9 > 0),
    );
  }

  static AssessmentResult scoreGad7(List<int> responses) {
    if (responses.length != 7) throw Exception('Incomplete GAD-7');
    final total = responses.reduce((a, b) => a + b);

    String severity;
    if (total >= 15)     severity = 'Severe Anxiety';
    else if (total >= 10)severity = 'Moderate Anxiety';
    else if (total >= 5) severity = 'Mild Anxiety';
    else                 severity = 'Minimal Anxiety';

    return AssessmentResult(
      score:                        total.toDouble(),
      severity:                     severity,
      requiresCrisisIntervention:   false,
      requiresProfessionalReferral: total >= 10,
      recommendations:              _gad7Recommendations(severity),
    );
  }

  static AssessmentResult scoreDailyMood(List<int> responses) {
    if (responses.isEmpty) throw Exception('Incomplete responses');
    final avg = responses.reduce((a, b) => a + b) / responses.length;
    final score = (avg / 4) * 100; // Normalize 0-4 scale to 0-100
    
    return AssessmentResult(
      score:                        score,
      severity:                     score >= 70 ? 'Positive' : score >= 40 ? 'Neutral' : 'Low',
      requiresCrisisIntervention:   false,
      requiresProfessionalReferral: false,
      recommendations:              [],
    );
  }

  static AssessmentResult scoreWeeklyReview(List<int> responses) {
    if (responses.isEmpty) throw Exception('Incomplete responses');
    final total = responses.reduce((a, b) => a + b);
    // Assuming 10 questions on 0-10 scale? Or emoji scale 0-4?
    // Weekly review has 10 questions. If use emoji5 (0-4), max is 40.
    final score = (total / 40) * 100;

    String severity;
    if (score >= 70)      severity = 'Thriving';
    else if (score >= 50) severity = 'Managing';
    else if (score >= 30) severity = 'Struggling';
    else                  severity = 'At Risk';

    return AssessmentResult(
      score:                        score,
      severity:                     severity,
      requiresCrisisIntervention:   false,
      requiresProfessionalReferral: score < 30,
      recommendations:              [],
    );
  }

  static List<String> _phq9Recommendations(String severity, bool suicidal) {
    final recs = <String>[];
    if (suicidal) recs.add('Please speak with a crisis counselor immediately.');
    if (severity.contains('Severe') || severity.contains('Moderate')) {
      recs.add('A consultation with a mental health professional is highly recommended.');
    }
    recs.add('Keep a daily mood log to track patterns.');
    return recs;
  }

  static List<String> _gad7Recommendations(String severity) {
    final recs = <String>[];
    if (severity.contains('Severe')) {
      recs.add('Consider seeking professional help for anxiety management.');
    }
    recs.add('Try deep breathing exercises or guided meditation.');
    return recs;
  }
}
