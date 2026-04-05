import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/tasks/screens/tasks_screen.dart';
import '../features/growth/screens/growth_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../core/theme/app_theme.dart';
import '../services/storage/database_service.dart';
import '../services/auth/auth_service.dart';
import '../features/assessment/screens/assessment_screen.dart';
import '../services/assessment/assessment_data.dart';
import '../state/app_state.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  static const List<Widget> _screens = [
    ChatScreen(),
    DashboardScreen(),
    TasksScreen(),
    GrowthScreen(),
    SettingsScreen(),
  ];

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon:         Icon(Icons.chat_bubble_outline),
      selectedIcon: Icon(Icons.chat_bubble),
      label:        'Chat',
    ),
    NavigationDestination(
      icon:         Icon(Icons.monitor_heart_outlined),
      selectedIcon: Icon(Icons.monitor_heart),
      label:        'Wellbeing',
    ),
    NavigationDestination(
      icon:         Icon(Icons.check_box_outline_blank),
      selectedIcon: Icon(Icons.check_box),
      label:        'Tasks',
    ),
    NavigationDestination(
      icon:         Icon(Icons.eco_outlined),
      selectedIcon: Icon(Icons.eco),
      label:        'Growth',
    ),
    NavigationDestination(
      icon:         Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label:        'Settings',
    ),
  ];

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  Timer? _reminderTimer;

  @override
  void initState() {
    super.initState();
    // Initial check on startup after a short delay
    Future.delayed(const Duration(seconds: 3), () => _triggerInitialPrompts());
    
    // Hourly reminder
    _reminderTimer = Timer.periodic(const Duration(hours: 1), (_) => _checkReminder());
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  Future<void> _triggerInitialPrompts() async {
    if (!mounted) return;
    
    final uid = AuthService.instance.currentUser?.id;
    final hasCheckedIn = await databaseServiceProvider.hasCompletedCheckInToday(uid);
    
    if (!hasCheckedIn) {
      _showReminderPrompt(isInitial: true);
    }
  }

  Future<void> _checkReminder() async {
    final selectedIndex = ref.read(navigationIndexProvider);
    // 4 is Settings index based on _screens list
    if (selectedIndex == 4) return;

    final uid = AuthService.instance.currentUser?.id;
    final hasCheckedIn = await databaseServiceProvider.hasCompletedCheckInToday(uid);
    
    if (!hasCheckedIn && mounted) {
      _showReminderPrompt(isInitial: false);
    }
  }

  void _showReminderPrompt({required bool isInitial}) async {
    final uid = AuthService.instance.currentUser?.id;
    final tasks = await databaseServiceProvider.getActiveTasks(uid);
    final urgentTasks = tasks.where((t) => t.deadline != null && 
        (t.deadline! - DateTime.now().millisecondsSinceEpoch) < 86400000).toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isDismissible: !isInitial, // Forced on startup
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌟 Wellness Check-in', 
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.md),
            const Text(
              "How are you doing right now? Taking a moment to check in helps Utkarsh support you better.",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            
            if (urgentTasks.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        "Reminder: '${urgentTasks.first.title}' is due soon!",
                        style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _launchCheckIn();
                },
                child: const Text('Check-in Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            if (!isInitial)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Maybe later', style: TextStyle(color: AppColors.textMuted)),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  void _launchCheckIn() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AssessmentScreen(
          type: AssessmentType.dailyMood,
          onComplete: (res) => Navigator.of(context).pop(),
          onDismiss: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(navigationIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index:    selectedIndex,
        children: AppShell._screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex:     selectedIndex,
        onDestinationSelected: (index) {
          ref.read(navigationIndexProvider.notifier).state = index;
        },
        backgroundColor:       AppColors.surface,
        indicatorColor:        AppColors.primary.withValues(alpha: 0.2),
        shadowColor:           Colors.transparent,
        surfaceTintColor:      Colors.transparent,
        destinations:          AppShell._destinations,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
