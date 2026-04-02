// lib/features/assessment/screens/assessment_screen.dart

import 'package:flutter/material.dart';
import '../../../services/assessment/assessment_data.dart';
import '../../../services/assessment/risk_assessment_service.dart';
import '../../../services/storage/database_service.dart';
import '../components/crisis_modal.dart';

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
  final RiskAssessmentService _riskService = RiskAssessmentService(databaseServiceProvider);

  @override
  void initState() {
    super.initState();
    final questions = _getQuestions();
    _responses = List.filled(questions.length, -1);
  }

  List<AssessmentQuestion> _getQuestions() {
    switch (widget.type) {
      case AssessmentType.phq9:   return phq9Questions;
      case AssessmentType.gad7:   return gad7Questions;
      case AssessmentType.daily:  return dailyCheckinQuestions;
      case AssessmentType.weekly: return weeklyReviewQuestions;
    }
  }

  String _getTypeLabel() {
    switch (widget.type) {
      case AssessmentType.phq9:   return 'PHQ-9';
      case AssessmentType.gad7:   return 'GAD-7';
      case AssessmentType.daily:  return 'Daily Check-in';
      case AssessmentType.weekly: return 'Weekly Review';
    }
  }

  void _handleSelect(int idx, int value) {
    setState(() {
      _responses[idx] = value;
    });
  }

  Future<void> _handleSubmit() async {
    final questions = _getQuestions();
    final answeredCount = _responses.where((r) => r >= 0).length;

    if (answeredCount < questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please answer all questions ($answeredCount of ${questions.length} answered)')),
      );
      return;
    }

    final res = _riskService.score(widget.type, _responses);
    
    // Save to DB
    await databaseServiceProvider.saveAssessment({
      'type': _getTypeLabel(),
      'responses': _responses.toString(),
      'score': res.score,
      'severity': res.severity,
    });

    setState(() {
      _result = res;
      _submitted = true;
      if (res.hasCrisisIndicator) _showCrisis = true;
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

    final questions = _getQuestions();
    final typeLabel = _getTypeLabel();

    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('$typeLabel Assessment', style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onDismiss,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Over the last 2 weeks, how often have you been bothered by any of the following?",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "🔒 Your answers are stored privately on this device only.",
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 24),
            ...questions.asMap().entries.map((entry) => _buildQuestionCard(entry.key, entry.value)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D52),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("View Results →", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int idx, AssessmentQuestion q) {
    List<Map<String, dynamic>> options;
    if (widget.type == AssessmentType.daily || widget.type == AssessmentType.weekly) {
      options = [
        {'value': 0, 'label': 'Poor'},
        {'value': 1, 'label': 'Fair'},
        {'value': 2, 'label': 'Good'},
        {'value': 3, 'label': 'Excellent'},
      ];
    } else {
      options = [
        {'value': 0, 'label': 'Not at all'},
        {'value': 1, 'label': 'Several days'},
        {'value': 2, 'label': 'More than half'},
        {'value': 3, 'label': 'Nearly every day'},
      ];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(16),
        border: q.isCritical ? Border.all(color: Colors.redAccent.withValues(alpha: 0.3), width: 1) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (q.isCritical)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                "⚠️ This question is about your safety. Please answer honestly.",
                style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          Text(
            "Question ${q.id}",
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            q.text,
            style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            children: options.map((opt) {
              final isSelected = _responses[idx] == opt['value'];
              return Expanded(
                child: GestureDetector(
                  onTap: () => _handleSelect(idx, opt['value'] as int),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF2E7D52).withValues(alpha: 0.2) : const Color(0xFF243040),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF2E7D52) : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "${opt['value']}",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? const Color(0xFF4CAF78) : Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          opt['label'] as String,
                          style: TextStyle(
                            fontSize: 8,
                            color: isSelected ? const Color(0xFF4CAF78) : Colors.white38,
                          ),
                          textAlign: TextAlign.center,
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

  Widget _buildResultScreen(AssessmentResult result) {
    int maxScore;
    switch (widget.type) {
      case AssessmentType.phq9:   maxScore = 27; break;
      case AssessmentType.gad7:   maxScore = 21; break;
      case AssessmentType.daily:  maxScore = 12; break;
      case AssessmentType.weekly: maxScore = 15; break;
    }
    final color = _getSeverityColor(result.severity);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2332),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Text(
                      "${_getTypeLabel()} Result",
                      style: const TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "${result.score}",
                      style: TextStyle(fontSize: 72, fontWeight: FontWeight.w800, color: color),
                    ),
                    Text(
                      "out of $maxScore",
                      style: const TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      result.severity,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _getActionMessage(result.riskAction),
                      style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                      textAlign: TextAlign.center,
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
                    backgroundColor: const Color(0xFF2E7D52),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Back to Utkarsh", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
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
    if (severity.contains('Excellent') || severity.contains('Balanced') || severity.contains('Minimal')) {
      return const Color(0xFF66BB6A);
    }
    if (severity.contains('Stable') || severity.contains('Good') || severity.contains('Mild')) {
      return const Color(0xFF4CAF78);
    }
    if (severity.contains('Fair') || severity.contains('Moderate')) {
      return const Color(0xFFFF9800);
    }
    if (severity.contains('Low') || severity.contains('Suboptimal') || severity.contains('Severe')) {
      return const Color(0xFFF44336);
    }
    return Colors.white;
  }

  String _getActionMessage(RiskAction action) {
    switch (action) {
      case RiskAction.none: return "Great — your responses are in a healthy range. Keep doing your daily check-ins!";
      case RiskAction.coaching: return "Some mild symptoms detected. Consider talking to a trusted friend, mentor, or college counsellor.";
      case RiskAction.assessment: return "Moderate symptoms identified. We recommend scheduling an appointment with a mental health professional.";
      case RiskAction.professionalAlert: return "Significant distress detected. Please reach out to a professional as soon as possible.";
    }
  }
}
