import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/growth/xp_service.dart';
import '../../../services/storage/database_service.dart';
import '../../../services/response/response_engine.dart';
import '../../../core/widgets/prism_card.dart';

class GrowthScreen extends StatefulWidget {
  const GrowthScreen({super.key});

  @override
  State<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends State<GrowthScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  UserLevel? _level;
  List<Map<String, dynamic>> _xpHistory = [];

  static const _actionLabels = {
    'TASK_COMPLETED': ('✅', 'Task completed'),
    'REFLECTION_ADDED': ('💭', 'Reflection added'),
    'STRESS_REDUCED': ('📉', 'Stress reduced'),
    'WEEKLY_STREAK': ('🔥', '7-day streak!'),
    'ASSESSMENT_COMPLETE': ('📋', 'Assessment done'),
    'DAILY_CHECKIN': ('☀️', 'Daily check-in'),
    'MOOD_IMPROVED': ('😊', 'Mood improved'),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await responseEngineProvider.ensureInitialized();
    final level = await xpService.getLevelInfo();
    final history = await databaseServiceProvider.getXPHistory(30);
    if (mounted) {
      setState(() {
        _level = level;
        _xpHistory = history;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.11),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.06),
              ),
            ),
          ),
          SafeArea(
            child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2))
            : RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: () async {
                  setState(() => _loading = true);
                  await _load();
                },
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    // ── Header ────────────────────────────────────────
                    const Padding(
                      padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                      child: Text('Growth',
                          style: TextStyle(
                              color: AppColors.text,
                              fontSize: AppFontSizes.xxl,
                              fontWeight: FontWeight.bold)),
                    ),

                    // ── XP Progress Card ──────────────────────────────
                    if (_level != null) _XPProgressCard(level: _level!),

                    // ── XP Rewards Guide ──────────────────────────────
                    _XPRewardsCard(),

                    // ── Level Journey Map ──────────────────────────────
                    _LevelJourneyMap(
                        currentXP: _level?.totalXP ?? 0),

                    // ── Recent XP History ──────────────────────────────
                    const Padding(
                      padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                      child: Text('Recent XP Activity',
                          style: TextStyle(
                              color: AppColors.text,
                              fontSize: AppFontSizes.lg,
                              fontWeight: FontWeight.w600)),
                    ),
                    if (_xpHistory.isEmpty)
                      PrismCard(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: const Center(
                          child: Column(
                            children: [
                              Text('🌱',
                                  style: TextStyle(fontSize: 40)),
                              SizedBox(height: AppSpacing.sm),
                              Text(
                                'Complete tasks and daily check-ins to earn XP!',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: AppFontSizes.sm),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      PrismCard(
                        padding: EdgeInsets.zero,
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _xpHistory.length,
                          separatorBuilder: (_, __) => const Divider(
                              color: AppColors.surfaceContainerHigh,
                              height: 1),
                          itemBuilder: (_, i) {
                            final row = _xpHistory[i];
                            final action =
                                row['action'] as String? ?? '';
                            final meta =
                                _actionLabels[action] ?? ('🎯', action);
                            final xp = row['xp_gained'] as int? ?? 0;
                            final ts =
                                row['earned_at'] as int? ?? 0;
                            final date =
                                DateTime.fromMillisecondsSinceEpoch(
                                    ts);
                            return ListTile(
                              leading: Text(meta.$1,
                                  style:
                                      const TextStyle(fontSize: 22)),
                              title: Text(meta.$2,
                                  style: const TextStyle(
                                      color: AppColors.onSurface,
                                      fontSize: AppFontSizes.sm)),
                              subtitle: Text(
                                '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: AppFontSizes.xs),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.success
                                      .withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.full),
                                ),
                                child: Text('+$xp XP',
                                    style: const TextStyle(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.bold,
                                        fontSize: AppFontSizes.sm)),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
          ),
        ],
      ),
    );
  }
}

// ── XP Progress Card ──────────────────────────────────────────────────────

class _XPProgressCard extends StatefulWidget {
  final UserLevel level;

  const _XPProgressCard({required this.level});

  @override
  State<_XPProgressCard> createState() => _XPProgressCardState();
}

class _XPProgressCardState extends State<_XPProgressCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = Tween<double>(
            begin: 0, end: widget.level.progressPercent / 100)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.level;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: PrismStatusCard(
        statusColor: l.current.color,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
        children: [
          Row(
            children: [
              Text(l.current.emoji,
                  style: const TextStyle(fontSize: 36)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.current.name,
                        style: TextStyle(
                            color: l.current.color,
                            fontSize: AppFontSizes.xl,
                            fontWeight: FontWeight.bold)),
                    Text('${l.totalXP} XP total',
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: AppFontSizes.sm)),
                  ],
                ),
              ),
              if (l.xpToNext != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${l.xpToNext} XP',
                        style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: AppFontSizes.xs)),
                    Text('to ${l.next!.emoji} ${l.next!.name}',
                        style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10)),
                  ],
                )
              else
                const Text('Max Level! ✨',
                    style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: _anim.value,
                    minHeight: 12,
                    backgroundColor: AppColors.surfaceElevated,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(l.current.color),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${l.progressPercent.round()}%',
                    style: TextStyle(
                        color: l.current.color,
                        fontSize: AppFontSizes.xs,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ── XP Rewards Guide ──────────────────────────────────────────────────────

class _XPRewardsCard extends StatelessWidget {
  static const _rewards = [
    ('✅', 'Complete a task', '+10'),
    ('☀️', 'Daily check-in', '+3'),
    ('📉', 'Stress reduced', '+15'),
    ('🔥', '7-day streak', '+20'),
    ('💭', 'Reflection added', '+5'),
    ('😊', 'Mood improved', '+10'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: PrismCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How to Earn XP',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: AppFontSizes.md,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _rewards
                .map((r) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius:
                            BorderRadius.circular(AppRadius.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(r.$1,
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(r.$2,
                              style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: AppFontSizes.xs)),
                          const SizedBox(width: 4),
                          Text(r.$3,
                              style: const TextStyle(
                                  color: AppColors.success,
                                  fontSize: AppFontSizes.xs,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
      ),
    );
  }
}

// ── Level Journey Map ─────────────────────────────────────────────────────

class _LevelJourneyMap extends StatelessWidget {
  final int currentXP;

  const _LevelJourneyMap({required this.currentXP});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: PrismCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Journey',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: AppFontSizes.md,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: kLevels.asMap().entries.map((entry) {
              final i = entry.key;
              final l = entry.value;
              final reached = currentXP >= l.minXP;
              final isCurrent =
                  currentXP >= l.minXP &&
                  (i == kLevels.length - 1 ||
                      currentXP < kLevels[i + 1].minXP);
              return Expanded(
                child: Column(
                  children: [
                    // connector line
                    if (i > 0)
                      Container(
                        height: 2,
                        color: reached
                            ? l.color.withValues(alpha: 0.5)
                            : AppColors.surfaceElevated,
                      ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: isCurrent ? 48 : 40,
                      height: isCurrent ? 48 : 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: reached
                            ? l.color.withValues(alpha: 0.2)
                            : AppColors.surfaceElevated,
                        border: Border.all(
                          color: reached
                              ? l.color
                              : AppColors.surfaceHighlight,
                          width: isCurrent ? 2.5 : 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(l.emoji,
                            style: TextStyle(
                                fontSize: isCurrent ? 22 : 16)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(l.name,
                        style: TextStyle(
                            color: reached
                                ? l.color
                                : AppColors.textMuted,
                            fontSize: 9,
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal),
                        textAlign: TextAlign.center),
                    Text('${l.minXP}+',
                        style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 8)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      ),
    );
  }
}
