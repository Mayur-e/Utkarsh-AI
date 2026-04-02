// lib/services/assessment/assessment_trigger_service.dart

import '../storage/database_service.dart';
import 'assessment_data.dart';
import '../../core/utils/helpers.dart';

class AssessmentTriggerService {
  AssessmentTriggerService._();
  static final instance = AssessmentTriggerService._();

  final _db = databaseServiceProvider;

  /// Evaluate if any assessment should be triggered based on user data.
  Future<AssessmentType?> checkTriggers() async {
    final wellbeing = await _db.getWellbeingHistory(7);
    final today     = todayString();

    // 1. Daily Mood — Highest Priority
    final todayAssessments = await _db.getAssessmentsForDate(today);
    if (!todayAssessments.any((a) => a['type'] == 'dailyMood')) {
      final hour = DateTime.now().hour;
      // Trigger between 8 AM and 10 PM
      if (hour >= 8 && hour <= 22) {
        return AssessmentType.dailyMood;
      }
    }

    // 2. PHQ-9: 3 consecutive red/orange days
    if (wellbeing.length >= 3) {
      final recent3 = wellbeing.take(3);
      if (recent3.every((r) {
        final risk = r['risk_level'] as String?;
        return risk == 'red' || risk == 'orange';
      })) {
        if (!todayAssessments.any((a) => a['type'] == 'phq9')) {
          return AssessmentType.phq9;
        }
      }
    }

    // 3. GAD-7: CWS drops > 15 points
    if (wellbeing.length >= 2) {
      final latest  = wellbeing[0]['cws_score'] as num;
      final previous = wellbeing[1]['cws_score'] as num;
      final drop = latest - previous;
      if (drop < -15 && !todayAssessments.any((a) => a['type'] == 'gad7')) {
        return AssessmentType.gad7;
      }
    }

    // 4. Weekly Review: Monday
    if (DateTime.now().weekday == DateTime.monday) {
      final thisWeeksReview = await _db.getAssessmentTypeForWeek('weeklyReview');
      if (thisWeeksReview == null) return AssessmentType.weeklyReview;
    }

    // 5. Monthly PHQ-9: mandatory every 30 days
    final lastPhq9 = await _db.getLatestAssessmentOfType('phq9');
    if (lastPhq9 == null) {
      return AssessmentType.phq9;
    } else {
      final lastTime = DateTime.fromMillisecondsSinceEpoch(lastPhq9['timestamp'] as int);
      if (DateTime.now().difference(lastTime).inDays >= 30) {
        return AssessmentType.phq9;
      }
    }

    return null;
  }
}
