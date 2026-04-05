// lib/services/assessment/assessment_trigger_service.dart

import '../storage/database_service.dart';
import 'assessment_data.dart';
import '../../core/utils/helpers.dart';
import '../auth/auth_service.dart';

class AssessmentTriggerService {
  AssessmentTriggerService._();
  static final instance = AssessmentTriggerService._();

  final _db = databaseServiceProvider;

  // Cache to avoid spamming prompts in the same session
  static final Map<AssessmentType, DateTime> _lastPrompted = {};

  /// Evaluate if any assessment should be triggered based on user data.
  Future<AssessmentType?> checkTriggers([String? userId]) async {
    final uid = userId ?? AuthService.instance.currentUser?.id;
    final now = DateTime.now();

    // Helper to check cooldown (e.g., 2 hours)
    bool isCooled(AssessmentType type) {
      if (!_lastPrompted.containsKey(type)) return true;
      // Increased cooldown to 4 hours for chat-based prompts
      return now.difference(_lastPrompted[type]!).inHours >= 4;
    }

    final todayAssessments = await _db.getAssessmentsForDate(todayString(), uid);
    if (!todayAssessments.any((a) => a['type'] == 'dailyMood')) {
      final hour = DateTime.now().hour;
      if (hour >= 8 && hour <= 22 && isCooled(AssessmentType.dailyMood)) {
        _lastPrompted[AssessmentType.dailyMood] = now;
        return AssessmentType.dailyMood;
      }
    }

    // 2. Daily Stress after Mood if not done
    if (!todayAssessments.any((a) => a['type'] == 'dailyStress')) {
      final hasMood = todayAssessments.any((a) => a['type'] == 'dailyMood');
      if (hasMood && isCooled(AssessmentType.dailyStress)) {
        _lastPrompted[AssessmentType.dailyStress] = now;
        return AssessmentType.dailyStress;
      }
    }

    // 3. PHQ-9: 3 consecutive red/orange days
    final wellbeing = await _db.getWellbeingHistory(7, uid);
    if (wellbeing.length >= 3) {
      final recent3 = wellbeing.take(3);
      if (recent3.every((r) {
        final risk = r['risk_level'] as String?;
        return risk == 'red' || risk == 'orange';
      })) {
        if (!todayAssessments.any((a) => a['type'] == 'phq9') && isCooled(AssessmentType.phq9)) {
          _lastPrompted[AssessmentType.phq9] = now;
          return AssessmentType.phq9;
        }
      }
    }

    // 3. GAD-7: CWS drops > 15 points
    if (wellbeing.length >= 2) {
      final latest  = wellbeing[0]['cws_score'] as num;
      final previous = wellbeing[1]['cws_score'] as num;
      final drop = latest - previous;
      if (drop < -15 && !todayAssessments.any((a) => a['type'] == 'gad7') && isCooled(AssessmentType.gad7)) {
        _lastPrompted[AssessmentType.gad7] = now;
        return AssessmentType.gad7;
      }
    }

    // 4. Weekly Review: Monday
    if (DateTime.now().weekday == DateTime.monday) {
      final thisWeeksReview = await _db.getAssessmentTypeForWeek('weeklyReview', uid);
      if (thisWeeksReview == null && isCooled(AssessmentType.weeklyReview)) {
        _lastPrompted[AssessmentType.weeklyReview] = now;
        return AssessmentType.weeklyReview;
      }
    }

    // 5. Monthly PHQ-9: mandatory every 30 days
    final lastPhq9 = await _db.getLatestAssessmentOfType('phq9', uid);
    if (lastPhq9 == null) {
      if (!todayAssessments.any((a) => a['type'] == 'phq9')) {
         return AssessmentType.phq9;
      }
    } else {
      final lastTime = DateTime.fromMillisecondsSinceEpoch(lastPhq9['timestamp'] as int);
      if (DateTime.now().difference(lastTime).inDays >= 30) {
        if (!todayAssessments.any((a) => a['type'] == 'phq9')) {
          return AssessmentType.phq9;
        }
      }
    }

    return null;
  }
}
