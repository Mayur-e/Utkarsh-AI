import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/storage/database_service.dart';
import '../../../services/response/response_engine.dart';
import '../../../services/cws/cws_engine.dart';
import '../../assessment/screens/assessment_screen.dart';
import '../../../services/assessment/assessment_data.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  double _cwsScore = 0;
  RiskLevel _riskLevel = RiskLevel.green;
  double? _improvement;
  Map<String, double> _factorScores = {};
  List<Map<String, dynamic>> _history = [];
  int _tasksCompleted = 0;
  int _streakDays = 0;
  int _totalXP = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) setState(() => _loading = true);
    await responseEngineProvider.ensureInitialized();

    final db = databaseServiceProvider;
    final history = await db.getWellbeingHistory(7);
    final completedTotal = await db.getCompletedTasks();
    final totalXP = await db.getTotalXP();

    // Latest record
    final today = history.isNotEmpty ? history.first : null;
    final yesterday = history.length >= 2 ? history[1] : null;

    // CWS
    final cws = today != null ? (today['cws_score'] as num).toDouble() : 0.0;
    final risk = CWSEngine().getRiskLevel(cws);
    final improv = (today != null && yesterday != null)
        ? cws - (yesterday['cws_score'] as num).toDouble()
        : null;

    // Factor scores
    final factors = today != null
        ? {
            'emotionScore': (today['emotion_score'] as num?)?.toDouble() ?? 50,
            'stressScore': (today['stress_score'] as num?)?.toDouble() ?? 50,
            'taskScore': (today['task_score'] as num?)?.toDouble() ?? 50,
            'activityScore':
                (today['activity_score'] as num?)?.toDouble() ?? 50,
            'routineScore': (today['routine_score'] as num?)?.toDouble() ?? 50,
            'behaviorScore':
                (today['behavior_score'] as num?)?.toDouble() ?? 50,
            'growthScore': (today['growth_score'] as num?)?.toDouble() ?? 50,
          }
        : <String, double>{};

    // Streak
    int streak = 0;
    final sortedH = List<Map<String, dynamic>>.from(history)
      ..sort((a, b) =>
          (b['date'] as String).compareTo(a['date'] as String));
    for (int i = 0; i < sortedH.length; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final ds = date.toIso8601String().split('T')[0];
      if (sortedH.any((r) => r['date'] == ds)) {
        streak++;
      } else {
        break;
      }
    }

    if (mounted) {
      setState(() {
        _cwsScore = cws;
        _riskLevel = risk;
        _improvement = improv;
        _factorScores = factors;
        _history = history;
        _tasksCompleted = completedTotal.length;
        _streakDays = streak;
        _totalXP = totalXP;
        _loading = false;
      });
    }
  }

  Color get _riskColor {
    switch (_riskLevel) {
      case RiskLevel.green:
        return AppColors.wellbeingGreen;
      case RiskLevel.yellow:
        return AppColors.wellbeingYellow;
      case RiskLevel.orange:
        return AppColors.wellbeingOrange;
      case RiskLevel.red:
        return AppColors.wellbeingRed;
    }
  }

  String get _riskLabel {
    switch (_riskLevel) {
      case RiskLevel.green:
        return 'Flourishing';
      case RiskLevel.yellow:
        return 'Stable';
      case RiskLevel.orange:
        return 'Needs Care';
      case RiskLevel.red:
        return 'At Risk';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2))
            : RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: () => _load(refresh: true),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    // ── Header ──────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Wellbeing',
                              style: TextStyle(
                                  color: AppColors.text,
                                  fontSize: AppFontSizes.xxl,
                                  fontWeight: FontWeight.bold)),
                          Text(
                            _formattedDate(),
                            style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: AppFontSizes.sm),
                          ),
                        ],
                      ),
                    ),

                    // ── CWS Gauge ────────────────────────────────────────
                    _CWSGauge(
                      score: _cwsScore,
                      color: _riskColor,
                      label: _riskLabel,
                      improvement: _improvement,
                    ),

                    // ── Quick Stats ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md),
                      child: Row(
                        children: [
                          _statCard('✅', '$_tasksCompleted', 'Tasks Done',
                              AppColors.success),
                          const SizedBox(width: AppSpacing.sm),
                          _statCard('🔥', '$_streakDays', 'Day Streak',
                              AppColors.warning),
                          const SizedBox(width: AppSpacing.sm),
                          _statCard('⭐', '$_totalXP', 'Total XP',
                              AppColors.accent),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ── 7-Day Trend ──────────────────────────────────────
                    if (_history.length >= 2)
                      _TrendChart(history: _history)
                    else
                      _emptyChart(),

                    // ── Factor Breakdown ─────────────────────────────────
                    if (_factorScores.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _FactorBars(scores: _factorScores),
                    ],

                    // ── Assessment Section ──────────────────────────────
                    const SizedBox(height: AppSpacing.md),
                    _AssessmentsSection(),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _statCard(String emoji, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md, horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: AppFontSizes.xl,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFontSizes.xs),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _emptyChart() {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Center(
        child: Text('📈 Trend appears after 2 days of check-ins',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.sm)),
      ),
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  Widget _AssessmentsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Self-Assessments',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: AppFontSizes.lg,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _assessmentCard('☀️', 'Daily Check-in', 'How are you now?',
                  AssessmentType.daily, AppColors.wellbeingGreen),
              const SizedBox(width: AppSpacing.sm),
              _assessmentCard('📅', 'Weekly Review', 'Full week wrap',
                  AssessmentType.weekly, AppColors.accent),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _clinicalCard(),
        ],
      ),
    );
  }

  Widget _assessmentCard(
      String emoji, String title, String subtitle, AssessmentType type, Color color) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _launchAssessment(type),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 8),
              Text(title,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: AppFontSizes.sm,
                      fontWeight: FontWeight.bold)),
              Text(subtitle,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clinicalCard() {
    return GestureDetector(
      onTap: () => _showClinicalPicker(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            const Text('🔬', style: TextStyle(fontSize: 24)),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Clinical Screening',
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: AppFontSizes.md,
                          fontWeight: FontWeight.bold)),
                  Text('Standard PHQ-9 or GAD-7 assessment',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: AppFontSizes.xs)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  void _launchAssessment(AssessmentType type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AssessmentScreen(
          type: type,
          onComplete: (res) {
            Navigator.of(context).pop();
            _load(refresh: true);
          },
          onDismiss: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _showClinicalPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose Screening',
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: AppFontSizes.lg,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: AppColors.wellbeingOrange,
                  child: Text('D', style: TextStyle(color: Colors.white))),
              title: const Text('PHQ-9 (Depression)',
                  style: TextStyle(color: AppColors.text)),
              subtitle: const Text('9 questions about your mood/interest',
                  style: TextStyle(color: AppColors.textMuted)),
              onTap: () {
                Navigator.pop(context);
                _launchAssessment(AssessmentType.phq9);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text('A', style: TextStyle(color: Colors.white))),
              title: const Text('GAD-7 (Anxiety)',
                  style: TextStyle(color: AppColors.text)),
              subtitle: const Text('7 questions about worry/tension',
                  style: TextStyle(color: AppColors.textMuted)),
              onTap: () {
                Navigator.pop(context);
                _launchAssessment(AssessmentType.gad7);
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

// ── CWS Gauge ──────────────────────────────────────────────────────────────

class _CWSGauge extends StatefulWidget {
  final double score;
  final Color color;
  final String label;
  final double? improvement;

  const _CWSGauge({
    required this.score,
    required this.color,
    required this.label,
    this.improvement,
  });

  @override
  State<_CWSGauge> createState() => _CWSGaugeState();
}

class _CWSGaugeState extends State<_CWSGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = Tween<double>(begin: 0, end: widget.score / 100)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_CWSGauge old) {
    super.didUpdateWidget(old);
    if (old.score != widget.score) {
      _anim = Tween<double>(begin: old.score / 100, end: widget.score / 100)
          .animate(
              CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(
                painter: _GaugePainter(
                  progress: _anim.value,
                  color: widget.color,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(_anim.value * 100).round()}',
                        style: TextStyle(
                          color: widget.color,
                          fontSize: AppFontSizes.xxxl,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      Text('%',
                          style: TextStyle(
                              color: widget.color.withValues(alpha: 0.7),
                              fontSize: AppFontSizes.lg)),
                      Text(widget.label,
                          style: TextStyle(
                              color: widget.color,
                              fontSize: AppFontSizes.sm,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.improvement != null)
            Container(
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 4),
              decoration: BoxDecoration(
                color: widget.improvement! >= 0
                    ? AppColors.success.withValues(alpha: 0.15)
                    : AppColors.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                '${widget.improvement! >= 0 ? '↑' : '↓'} ${widget.improvement!.abs().toStringAsFixed(0)} pts from yesterday',
                style: TextStyle(
                    color: widget.improvement! >= 0
                        ? AppColors.success
                        : AppColors.danger,
                    fontSize: AppFontSizes.sm,
                    fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 4),
          const Text('Composite Wellbeing Score',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: AppFontSizes.xs)),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  _GaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 16;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = AppColors.surfaceElevated
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress || old.color != color;
}

// ── 7-Day Trend Chart ──────────────────────────────────────────────────────

class _TrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> history;

  const _TrendChart({required this.history});

  @override
  Widget build(BuildContext context) {
    final reversed = history.reversed.toList();
    final scores =
        reversed.map((r) => (r['cws_score'] as num).toDouble()).toList();
    final maxScore = scores.reduce(math.max);
    final minScore = scores.reduce(math.min);
    final range = (maxScore - minScore).clamp(1.0, 100.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('7-Day Trend',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: AppFontSizes.lg,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _SparklinePainter(
                scores: scores,
                max: maxScore,
                min: minScore,
                range: range,
                color: AppColors.primary,
              ),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: reversed
                .map((r) {
                  final parts = (r['date'] as String).split('-');
                  return Text(
                    '${parts[2]}/${parts[1]}',
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9),
                  );
                })
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> scores;
  final double max, min, range;
  final Color color;

  _SparklinePainter({
    required this.scores,
    required this.max,
    required this.min,
    required this.range,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final n = scores.length;
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < n; i++) {
      final x = i / (n - 1) * size.width;
      final y = size.height - ((scores[i] - min) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Dots
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final dotBorder = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.fill;

    for (int i = 0; i < n; i++) {
      final x = i / (n - 1) * size.width;
      final y = size.height - ((scores[i] - min) / range) * size.height;
      canvas.drawCircle(Offset(x, y), 5, dotBorder);
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.scores != scores;
}

// ── Factor Bars ────────────────────────────────────────────────────────────

class _FactorBars extends StatefulWidget {
  final Map<String, double> scores;

  const _FactorBars({required this.scores});

  @override
  State<_FactorBars> createState() => _FactorBarsState();
}

class _FactorBarsState extends State<_FactorBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  static const _factors = [
    ('emotionScore', '💚', 'Emotional State', '25%'),
    ('stressScore', '🧘', 'Stress (Inverted)', '15%'),
    ('taskScore', '✅', 'Task Completion', '15%'),
    ('activityScore', '⚡', 'Activity Level', '10%'),
    ('routineScore', '🔄', 'Daily Routine', '10%'),
    ('behaviorScore', '📊', 'Behavior Patterns', '15%'),
    ('growthScore', '🌱', 'Growth & XP', '10%'),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _barColor(double v) {
    if (v >= 75) return AppColors.wellbeingGreen;
    if (v >= 50) return AppColors.wellbeingYellow;
    if (v >= 30) return AppColors.wellbeingOrange;
    return AppColors.wellbeingRed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('7-Factor Breakdown',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: AppFontSizes.lg,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.md),
          ...(_factors.map((f) {
            final (key, emoji, label, weight) = f;
            final value = widget.scores[key] ?? 50.0;
            final color = _barColor(value);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(label,
                                style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: AppFontSizes.sm,
                                    fontWeight: FontWeight.w500)),
                            Row(
                              children: [
                                Text(weight,
                                    style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11)),
                                const SizedBox(width: 8),
                                Text('${value.round()}',
                                    style: TextStyle(
                                        color: color,
                                        fontSize: AppFontSizes.sm,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppRadius.full),
                          child: SizedBox(
                            height: 7,
                            child: AnimatedBuilder(
                              animation: _anim,
                              builder: (_, __) => LinearProgressIndicator(
                                value: (value / 100) * _anim.value,
                                backgroundColor:
                                    AppColors.surfaceElevated,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          })),
        ],
      ),
    );
  }
}
