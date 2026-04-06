// lib/features/assessment/screens/assessment_screen.dart

import 'package:flutter/material.dart';
import '../../../services/assessment/assessment_data.dart';
import '../../../services/assessment/risk_assessment_service.dart';
import '../../../services/storage/database_service.dart';
import '../../../services/auth/auth_service.dart';
import '../../../services/cws/cws_engine.dart';
import '../../../services/growth/xp_service.dart';
import '../components/crisis_modal.dart';
import '../../../core/theme/app_theme.dart';

class AssessmentScreen extends StatefulWidget {
  final AssessmentType type;
  final Function(AssessmentResult) onComplete;
  final VoidCallback onDismiss;

  const AssessmentScreen({
    super.key,
    required this.type,
    required this.onComplete,
    required this.onDismiss,
  });

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  late List<int> _responses;
  bool _showCrisis = false;
  AssessmentResult? _result;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final definition = _getDefinition();
    _responses = List.filled(definition.questions.length, -1);
  }

  AssessmentDefinition _getDefinition() {
    switch (widget.type) {
      case AssessmentType.phq9:         return kPhq9Assessment;
      case AssessmentType.gad7:         return kGad7Assessment;
      case AssessmentType.dailyMood:    return kDailyMoodAssessment;
      case AssessmentType.dailyStress:  return kDailyStressAssessment;
      case AssessmentType.weeklyReview: return kWeeklyReviewAssessment;
      case AssessmentType.monthlyDeep:  return kPhq9Assessment; // Fallback
    }
  }

  void _handleSelect(int idx, int value) {
    setState(() {
      _responses[idx] = value;
    });
  }

  Future<void> _handleSubmit() async {
    if (_responses.any((r) => r == -1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions before submitting.')),
      );
      return;
    }

    AssessmentResult res;
    switch (widget.type) {
      case AssessmentType.phq9:          res = AssessmentScorer.scorePhq9(_responses); break;
      case AssessmentType.gad7:          res = AssessmentScorer.scoreGad7(_responses); break;
      case AssessmentType.dailyMood:     res = AssessmentScorer.scoreDailyMood(_responses); break;
      case AssessmentType.dailyStress:   res = AssessmentScorer.scoreDailyStress(_responses); break;
      case AssessmentType.weeklyReview:  res = AssessmentScorer.scoreWeeklyReview(_responses); break;
      default:                           res = AssessmentScorer.scorePhq9(_responses);
    }
    
    // Save to DB
    final uid = AuthService.instance.currentUser?.id;
    await databaseServiceProvider.saveAssessment({
      'type': widget.type.name,
      'responses': _responses.toString(),
      'score': res.score,
      'severity': res.severity,
      'triggered_by': 'manual',
      'date': DateTime.now().toIso8601String().split('T')[0],
    }, uid);

    // CRITICAL: Trigger Wellbeing Update (CWS) for Daily Check-ins
    if (widget.type == AssessmentType.dailyMood || widget.type == AssessmentType.dailyStress) {
      try {
        final db = databaseServiceProvider;
        final history = await db.getWellbeingHistory(1, uid);
        
        double emScore = 65;
        double stLevel = 40;
        
        if (history.isNotEmpty) {
          final last = history.first;
          emScore = (last['emotion_score'] as num?)?.toDouble() ?? 65;
          stLevel = 100 - ((last['stress_score'] as num?)?.toDouble() ?? 60); // stress_score in DB is normalized (100-level)
        }

        if (widget.type == AssessmentType.dailyMood) {
          emScore = res.score;
        } else {
          stLevel = res.score; // dailyStress score is 0-100 (high = stressed)
        }

        await cwsEngineProvider.computeAndSave(CWSInputs(
          emotionScore: emScore,
          stressLevel: stLevel,
        ), uid);

        // Award XP: daily check-in (guarded — once per day)
        await xpService.onDailyCheckin(uid);
      } catch (e) {
        debugPrint('[AssessmentScreen] CWS auto-update failed: $e');
      }

      // Daily mood/stress: XP already awarded above as DAILY_CHECKIN.
      // Do NOT also award ASSESSMENT_COMPLETE for these quick checks.
    } else {
      // Full assessments (PHQ-9, GAD-7, weekly review) → award separately
      await xpService.award('ASSESSMENT_COMPLETE', uid);
    }

    setState(() {
      _result = res;
      _submitted = true;
      if (res.requiresCrisisIntervention) _showCrisis = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showCrisis) {
      return CrisisModal(
        onSafeConfirmed: () {
          setState(() => _showCrisis = false);
          if (_result != null) widget.onComplete(_result!);
        },
      );
    }

    if (_submitted && _result != null) {
      return _buildResultScreen(_result!);
    }

    final definition = _getDefinition();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(definition.title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.text),
          onPressed: widget.onDismiss,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              definition.subtitle,
              style: const TextStyle(
                fontSize: AppFontSizes.lg,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              "Your answers are protected with zero-knowledge encryption.",
              style: TextStyle(color: AppColors.textMuted, fontSize: AppFontSizes.xs),
            ),
            const SizedBox(height: AppSpacing.xl),
            ...definition.questions.asMap().entries.map((entry) => _buildQuestionCard(entry.key, entry.value)),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                child: const Text("View Results →", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              ),
            ),
            if (definition.source != null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Center(
                  child: Text(
                    definition.source!,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
                ),
              ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int idx, AssessmentQuestion q) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: q.isCritical ? Border.all(color: AppColors.danger.withValues(alpha: 0.3), width: 1) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.text,
            style: const TextStyle(color: AppColors.text, fontSize: AppFontSizes.md, fontWeight: FontWeight.w600, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildResponseScale(idx, q.scale),
        ],
      ),
    );
  }

  Widget _buildResponseScale(int idx, ResponseScale scale) {
    switch (scale) {
      case ResponseScale.likert4:
        return _buildOptions(idx, [
          {'v': 0, 'l': 'Not at all'},
          {'v': 1, 'l': 'Several days'},
          {'v': 2, 'l': 'More than half'},
          {'v': 3, 'l': 'Nearly daily'},
        ]);
      case ResponseScale.emoji5:
        return _buildEmojiScale(idx);
      case ResponseScale.numeric10:
        return _buildNumericSlider(idx);
      case ResponseScale.yesNo:
        return _buildOptions(idx, [
          {'v': 0, 'l': 'No'},
          {'v': 1, 'l': 'Yes'},
        ]);
      case ResponseScale.frequency5:
        return _buildOptions(idx, [
          {'v': 0, 'l': 'Never'},
          {'v': 1, 'l': 'Rarely'},
          {'v': 2, 'l': 'Sometimes'},
          {'v': 3, 'l': 'Often'},
          {'v': 4, 'l': 'Always'},
        ]);
    }
  }

  Widget _buildOptions(int idx, List<Map<String, dynamic>> options) {
    return Column(
      children: options.map((opt) {
        final isSelected = _responses[idx] == opt['v'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => _handleSelect(idx, opt['v'] as int),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      opt['l'] as String,
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmojiScale(int idx) {
    final emojis = ['😢', '😞', '😐', '😊', '😄'];
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 8,
      runSpacing: 12,
      children: List.generate(emojis.length, (i) {
        final isSelected = _responses[idx] == i;
        return GestureDetector(
          onTap: () => _handleSelect(idx, i),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 2),
                ),
                child: Text(emojis[i], style: const TextStyle(fontSize: 28)),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildNumericSlider(int idx) {
    return Column(
      children: [
        Slider(
          value: _responses[idx] == -1 ? 5.0 : _responses[idx].toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          activeColor: AppColors.primary,
          inactiveColor: AppColors.background,
          label: _responses[idx] == -1 ? "?" : _responses[idx].toString(),
          onChanged: (val) => _handleSelect(idx, val.toInt()),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('None', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
              Text('Moderate', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
              Text('Extreme', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultScreen(AssessmentResult result) {
    final color = _getSeverityColor(result.severity);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                ),
                child: Column(
                  children: [
                    Text(
                      _getDefinition().title,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      result.score.toStringAsFixed(0),
                      style: TextStyle(fontSize: 72, fontWeight: FontWeight.w800, color: color),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      result.severity,
                      style: TextStyle(fontSize: AppFontSizes.xxl, fontWeight: FontWeight.bold, color: color),
                    ),
                    const SizedBox(height: 32),
                    if (result.recommendations.isNotEmpty) ...[
                      const Text(
                        "Recommendations",
                        style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...result.recommendations.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          "• $r",
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: AppFontSizes.md),
                          textAlign: TextAlign.center,
                        ),
                      )),
                    ] else
                      const Text(
                        "Your responses indicate a stable baseline. Continue your regular check-ins to track your progress.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => widget.onComplete(result),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: const Text("Check-in Completed", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    severity = severity.toLowerCase();
    if (severity.contains('positive') || severity.contains('thriving') || severity.contains('minimal')) {
      return AppColors.success;
    }
    if (severity.contains('neutral') || severity.contains('managing') || severity.contains('mild')) {
       return Colors.blueAccent;
    }
    if (severity.contains('struggling') || severity.contains('moderate')) {
      return Colors.orangeAccent;
    }
    if (severity.contains('risk') || severity.contains('severe') || severity.contains('low')) {
      return AppColors.danger;
    }
    return AppColors.text;
  }
}
