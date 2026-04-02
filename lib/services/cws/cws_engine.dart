import 'dart:math' as math;
import '../storage/database_service.dart';

enum RiskLevel { green, yellow, orange, red }

class CWSWeights {
  static const double emotion = 0.25;
  static const double stress = 0.15;
  static const double tasks = 0.15;
  static const double activity = 0.10;
  static const double routine = 0.10;
  static const double behavior = 0.15;
  static const double growth = 0.10;
}

class CWSInputs {
  final double emotionScore;   // 0–100, high = positive
  final double stressLevel;    // 0–100, high = stressed
  final double taskScore;      // 0–100
  final double activityScore;  // 0–100
  final double routineScore;   // 0–100
  final double behaviorScore;  // 0–100
  final double growthScore;    // 0–100

  CWSInputs({
    required this.emotionScore,
    required this.stressLevel,
    this.taskScore = 65,
    this.activityScore = 60,
    this.routineScore = 60,
    this.behaviorScore = 60,
    this.growthScore = 50,
  });
}

class CWSResult {
  final double cws;
  final double smoothedCWS;
  final RiskLevel riskLevel;
  final String date;

  CWSResult({
    required this.cws,
    required this.smoothedCWS,
    required this.riskLevel,
    required this.date,
  });
}

class CWSEngine {
  final DatabaseService _db = databaseServiceProvider;

  double normalizeStress(double stressLevel) {
    return (100.0 - stressLevel).clamp(0.0, 100.0);
  }

  double normalizeTaskCompletion(int completed, int total, double stressLevel) {
    if (total == 0) return 65.0;
    final rate = completed / total;
    return (rate * (1.0 - stressLevel / 100.0) * 100.0).clamp(0.0, 100.0);
  }

  double normalizeGrowth(int totalXP) {
    if (totalXP <= 0) return 0.0;
    // Logarithmic scale: 1500 XP ≈ 100 score
    return (math.log(1.0 + totalXP / 15.0) * 20.0).clamp(0.0, 100.0);
  }

  RiskLevel getRiskLevel(double score) {
    if (score >= 75.0) return RiskLevel.green;
    if (score >= 50.0) return RiskLevel.yellow;
    if (score >= 30.0) return RiskLevel.orange;
    return RiskLevel.red;
  }

  Future<CWSResult> computeAndSave(CWSInputs inputs) async {
    final double normalizedStress = normalizeStress(inputs.stressLevel);
    
    final double rawCws = (inputs.emotionScore * CWSWeights.emotion) +
        (normalizedStress * CWSWeights.stress) +
        (inputs.taskScore * CWSWeights.tasks) +
        (inputs.activityScore * CWSWeights.activity) +
        (inputs.routineScore * CWSWeights.routine) +
        (inputs.behaviorScore * CWSWeights.behavior) +
        (inputs.growthScore * CWSWeights.growth);

    final double cws = rawCws.clamp(0.0, 100.0);
    
    // 7-day smoothing
    final history = await _db.getWellbeingHistory(7);
    double smoothedCWS = cws;
    if (history.isNotEmpty) {
      final double historyAvg = history.fold<double>(0.0, (sum, r) => sum + (r['cws_score'] as num).toDouble()) / history.length;
      smoothedCWS = (0.7 * cws) + (0.3 * historyAvg);
    }

    final risk = getRiskLevel(smoothedCWS);
    final dateStr = DateTime.now().toIso8601String().split('T')[0];

    final result = CWSResult(
      cws: cws,
      smoothedCWS: smoothedCWS,
      riskLevel: risk,
      date: dateStr,
    );

    // Save record
    await _db.saveWellbeingRecord({
      'id': 'wb_${DateTime.now().millisecondsSinceEpoch}',
      'date': dateStr,
      'cws_score': smoothedCWS,
      'emotion_score': inputs.emotionScore,
      'stress_score': normalizedStress,
      'task_score': inputs.taskScore,
      'activity_score': inputs.activityScore,
      'routine_score': inputs.routineScore,
      'behavior_score': inputs.behaviorScore,
      'growth_score': inputs.growthScore,
      'risk_level': risk.name,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    return result;
  }
}

final cwsEngineProvider = CWSEngine();
