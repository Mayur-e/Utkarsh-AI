import 'package:flutter/material.dart';
import '../../../services/assessment/assessment_data.dart';
import '../../../services/assessment/risk_assessment_service.dart';
import '../../../services/growth/xp_service.dart';
import '../../../core/theme/app_theme.dart';
import '../components/crisis_modal.dart';

class AssessmentScreen extends StatefulWidget {
  final AssessmentType type;
  final ValueChanged<AssessmentResult> onComplete;
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
  late final List<AssessmentQuestion> _questions;
  late List<int> _responses;
  bool _showCrisis = false;
  AssessmentResult? _result;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _questions =
        widget.type == AssessmentType.phq9 ? kPhq9Questions : kGad7Questions;
    _responses = List.filled(_questions.length, -1);
  }

  int get _answeredCount => _responses.where((r) => r >= 0).length;
  bool get _allAnswered => _answeredCount == _questions.length;

  void _handleSelect(int idx, int value) {
    setState(() {
      _responses[idx] = value;
    });
  }

  Future<void> _handleSubmit() async {
    if (!_allAnswered) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Please answer all questions ($_answeredCount of ${_questions.length} answered)'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final r = riskAssessmentService.score(widget.type, _responses);
    await riskAssessmentService.save(r);
    // Award XP
    xpService.award('ASSESSMENT_COMPLETE');

    setState(() {
      _result = r;
      _submitted = true;
      if (r.hasCrisisIndicator) {
        _showCrisis = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted && !_showCrisis && _result != null) {
      return _ResultScreen(
        result: _result!,
        type: widget.type,
        onDone: () => widget.onComplete(_result!),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: AppSpacing.lg),
                  ...List.generate(
                      _questions.length, (idx) => _buildQuestionCard(idx)),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: _allAnswered ? _handleSubmit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.surfaceElevated,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.sm)),
                    ),
                    child: Text(
                      _allAnswered
                          ? 'View results →'
                          : '$_answeredCount / ${_questions.length} answered',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: AppFontSizes.md,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: widget.onDismiss,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    ),
                    child: const Text('Remind me later',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                  const SizedBox(height: 60), // padding
                ],
              ),
            ),
          ),
          if (_showCrisis)
            Positioned.fill(
              child: CrisisModal(
                onSafeConfirmed: () {
                  setState(() => _showCrisis = false);
                  if (_result != null) {
                    widget.onComplete(_result!);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.type == AssessmentType.phq9 ? 'PHQ-9' : 'GAD-7',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: AppFontSizes.sm,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Over the last 2 weeks, how often have you been bothered by any of the following?',
          style: TextStyle(
            color: AppColors.text,
            fontSize: AppFontSizes.lg,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          '🔒 Your answers are stored privately on this device only.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: AppFontSizes.xs,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(int idx) {
    final q = _questions[idx];
    final isCrit = q.isCritical;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: isCrit
            ? Border.all(color: AppColors.danger.withValues(alpha: 0.5), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isCrit)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                '⚠️ Please answer honestly — this question is about your safety.',
                style: TextStyle(
                    color: AppColors.danger, fontSize: AppFontSizes.xs),
              ),
            ),
          Text('Question ${q.id} of ${_questions.length}',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: AppFontSizes.xs)),
          const SizedBox(height: 4),
          Text(q.text,
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: AppFontSizes.md,
                  height: 1.4)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: kAssessmentOptions.map((opt) {
              final selected = _responses[idx] == opt.value;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _handleSelect(idx, opt.value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.surfaceElevated,
                      border: Border.all(
                        color: selected ? AppColors.primary : Colors.transparent,
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${opt.value}',
                          style: TextStyle(
                            fontSize: AppFontSizes.lg,
                            fontWeight: FontWeight.bold,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          opt.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            color: selected
                                ? AppColors.primaryLight
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Result sub-screen ────────────────────────────────────────────────────────

const _kSeverityColors = {
  'Minimal': Color(0xFF66BB6A),
  'Mild': Color(0xFFFFC107),
  'Moderate': Color(0xFFFF9800),
  'Moderately Severe': Color(0xFFF44336),
  'Severe': Color(0xFFB71C1C),
};

const _kActionMessages = {
  RiskAction.none:
      "Great — your responses are in a healthy range. Keep doing your daily check-ins!",
  RiskAction.coaching:
      "Some mild symptoms detected. Consider talking to a trusted friend, mentor, or college counsellor.",
  RiskAction.assessment:
      "Moderate symptoms identified. We recommend scheduling an appointment with a mental health professional.",
  RiskAction.professionalAlert:
      "Significant distress detected. Please reach out to a professional as soon as possible.",
};

class _ResultScreen extends StatelessWidget {
  final AssessmentResult result;
  final AssessmentType type;
  final VoidCallback onDone;

  const _ResultScreen({
    required this.result,
    required this.type,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final color = _kSeverityColors[result.severity] ?? AppColors.text;
    final maxScore = type == AssessmentType.phq9 ? 27 : 21;
    final typeName = type == AssessmentType.phq9 ? 'PHQ-9' : 'GAD-7';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                ),
                child: Column(
                  children: [
                    Text('$typeName Result',
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: AppFontSizes.sm)),
                    const SizedBox(height: AppSpacing.sm),
                    Text('${result.score}',
                        style: TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.w800,
                            color: color)),
                    Text('out of $maxScore',
                        style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: AppFontSizes.sm)),
                    const SizedBox(height: AppSpacing.md),
                    Text(result.severity,
                        style: TextStyle(
                            fontSize: AppFontSizes.xl,
                            fontWeight: FontWeight.bold,
                            color: color)),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      _kActionMessages[result.riskAction] ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppFontSizes.sm,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.sm)),
                ),
                child: const Text('Back to Utkarsh',
                    style: TextStyle(
                        color: AppColors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
