// lib/services/assessment/risk_assessment_service.dart

import '../storage/database_service.dart';
import 'assessment_data.dart';

class RiskAssessmentService {
  final DatabaseService _db;

  RiskAssessmentService(this._db);

  // -- Auto-trigger rules (Phase 12, Part A, Step 2) -----------------------
  // Rule 1: CWS < 50 for 3 consecutive days -> prompt PHQ-9
  // Rule 2: CWS drops > 15 points in 1 day -> prompt GAD-7
  // Rule 3: 5+ negative messages in session -> prompt PHQ-9 (Handled in ResponseEngine)

  Future<AssessmentType?> shouldTrigger() async {
    final history = await _db.getWellbeingHistory(7);

    // Rule 1: 3 days of low wellbeing
    if (history.length >= 3) {
      final threeDaysLow = history.take(3).every((r) => (r['cws_score'] as num? ?? 100.0) < 55);
      if (threeDaysLow) return AssessmentType.phq9;
    }

    // Rule 2: Sharp drop in wellbeing
    if (history.length >= 2) {
      final drop = (history[1]['cws_score'] as num? ?? 0.0).toDouble() - (history[0]['cws_score'] as num? ?? 0.0).toDouble();
      if (drop > 15) return AssessmentType.gad7;
    }

    return null;
  }

  // -- Scoring logic -------------------------------------------------------
  AssessmentResult score(AssessmentType type, List<int> responses) {
    if (responses.any((r) => r < 0)) throw Exception('Incomplete responses');

    final total = responses.reduce((s, r) => s + r);
    final severity = type == AssessmentType.phq9 ? getPHQ9Severity(total) : getGAD7Severity(total);
    final q9Score = type == AssessmentType.phq9 ? responses[8] : 0;
    
    // Critical safety indicator (PHQ-9 Q9 > 0)
    final hasCrisisIndicator = type == AssessmentType.phq9 && q9Score > 0;

    RiskAction riskAction;
    if (hasCrisisIndicator || severity == 'Severe') {
      riskAction = RiskAction.professionalAlert;
    } else if (severity == 'Moderate' || severity == 'Moderately Severe') {
      riskAction = RiskAction.assessment;
    } else if (severity == 'Mild') {
      riskAction = RiskAction.coaching;
    } else {
      riskAction = RiskAction.none;
    }

    return AssessmentResult(
      type: type,
      responses: responses,
      score: total,
      severity: severity,
      hasCrisisIndicator: hasCrisisIndicator,
      riskAction: riskAction,
      timestamp: DateTime.now(),
    );
  }

  Future<void> saveResult(AssessmentResult result) async {
    // Note: We need a database method for this in database_service.dart
    // await _db.saveAssessmentRecord(result);
  }
}
