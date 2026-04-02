import '../storage/database_service.dart';
import 'assessment_data.dart';

class RiskAssessmentService {
  RiskAssessmentService._();
  static final RiskAssessmentService instance = RiskAssessmentService._();

  // ── Auto-trigger rules ──────────────────────────────────────────────────
  // Rule 1: CWS < 50 for 3 consecutive days → prompt PHQ-9
  // Rule 2: CWS drops > 15 pts from yesterday → prompt GAD-7
  // Rule 3: 5+ negative messages in session → prompt PHQ-9 (called from chat)

  Future<AssessmentType?> shouldTrigger() async {
    final history = await databaseServiceProvider.getWellbeingHistory(7);
    if (history.length >= 3) {
      final threeDaysLow =
          history.take(3).every((r) => (r['cws_score'] as num) < 50);
      if (threeDaysLow) return AssessmentType.phq9;
    }
    if (history.length >= 2) {
      final drop = (history[1]['cws_score'] as num) -
          (history[0]['cws_score'] as num);
      if (drop > 15) return AssessmentType.gad7;
    }
    return null;
  }

  AssessmentType? shouldTriggerFromChat(int negativeCount) {
    return negativeCount >= 5 ? AssessmentType.phq9 : null;
  }

  // ── Scoring ──────────────────────────────────────────────────────────────

  AssessmentResult score(AssessmentType type, List<int> responses) {
    final total = responses.fold(0, (s, r) => s + r);
    final severity =
        type == AssessmentType.phq9 ? phq9Severity(total) : gad7Severity(total);
    final q9 = type == AssessmentType.phq9 ? responses[8] : null;
    final hasCrisis = type == AssessmentType.phq9 && (q9 ?? 0) > 0;

    final action = hasCrisis || severity == 'Severe'
        ? RiskAction.professionalAlert
        : (severity == 'Moderate' || severity == 'Moderately Severe')
            ? RiskAction.assessment
            : severity == 'Mild'
                ? RiskAction.coaching
                : RiskAction.none;

    return AssessmentResult(
      type: type,
      responses: responses,
      score: total,
      severity: severity,
      q9Score: q9,
      hasCrisisIndicator: hasCrisis,
      riskAction: action,
    );
  }

  Future<void> save(AssessmentResult result) async {
    await databaseServiceProvider.saveAssessment({
      'type': result.type == AssessmentType.phq9 ? 'PHQ-9' : 'GAD-7',
      'responses': result.responses.join(','),
      'score': result.score,
      'severity': result.severity,
    });
  }
}

final riskAssessmentService = RiskAssessmentService.instance;
