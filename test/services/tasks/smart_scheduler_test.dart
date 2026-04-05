import 'package:flutter_test/flutter_test.dart';
import 'package:utkarsh_ai/models/task.dart';
import 'package:utkarsh_ai/models/user_profile.dart';
import 'package:utkarsh_ai/services/storage/database_service.dart';
import 'package:utkarsh_ai/services/tasks/smart_scheduler.dart';
import 'package:flutter/material.dart';

class ManualMockDatabaseService extends Fake implements DatabaseService {
  List<Task> activeTasks = [];
  List<Task> completedToday = [];

  @override
  Future<List<Task>> getActiveTasks([String? userId]) async => activeTasks;

  @override
  Future<List<Task>> getCompletedTasksToday([String? userId]) async => completedToday;
}

void main() {
  late ManualMockDatabaseService mockDb;
  late SmartScheduler scheduler;

  setUp(() {
    mockDb = ManualMockDatabaseService();
    scheduler = SmartScheduler(db: mockDb);
  });

  group('SmartScheduler End-to-End Verification', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final highPriorityTask = Task(
      id: 'task_1',
      title: 'Final Exam Preparation',
      priority: 4, // Critical
      status: TaskStatus.pending,
      category: TaskCategory.academic,
      complexity: TaskComplexity.large,
      deadline: now + 3600000 * 24 * 2, // 2 days from now
      createdAt: now,
    );

    final lowPriorityTask = Task(
      id: 'task_2',
      title: 'Read a book',
      priority: 1,
      status: TaskStatus.pending,
      category: TaskCategory.personal,
      complexity: TaskComplexity.small,
      createdAt: now,
    );

    final mockProfile = UserProfile(
      id: 'user_1',
      displayName: 'Test Student',
      streakDays: 5,
      totalXP: 1200,
      currentLevel: 'Focus Master',
      typicalWakeTime: const TimeOfDay(hour: 7, minute: 0),
      typicalSleepTime: const TimeOfDay(hour: 23, minute: 0),
      createdAt: now,
    );

    test('Verification: Low Stress (30) Behavior', () async {
      mockDb.activeTasks = [highPriorityTask, lowPriorityTask];
      mockDb.completedToday = [];

      final plan = await scheduler.buildDailyPlan(
        currentStress: 30.0,
        profile: mockProfile,
      );

      debugPrint('\n--- LOW STRESS (30) PLAN ---');
      debugPrint('Visible Tasks: ${plan.visibleTaskCount}');
      for (var st in plan.scheduledTasks) {
        debugPrint('Task: ${st.task.title} | Priority Score: ${st.priorityScore.toStringAsFixed(1)} | Hidden: ${st.isHiddenDueToStress}');
      }

      expect(plan.visibleTaskCount, 2);
      expect(plan.scheduledTasks.any((t) => t.task.id == 'task_1' && !t.isHiddenDueToStress), true);
      expect(plan.scheduledTasks.any((t) => t.task.id == 'task_2' && !t.isHiddenDueToStress), true);
    });

    test('Verification: High Stress (80) Behavior', () async {
      mockDb.activeTasks = [highPriorityTask, lowPriorityTask];
      mockDb.completedToday = [];

      final plan = await scheduler.buildDailyPlan(
        currentStress: 80.0,
        profile: mockProfile,
      );

      debugPrint('\n--- HIGH STRESS (80) PLAN ---');
      debugPrint('Visible Tasks: ${plan.visibleTaskCount}');
      debugPrint('Plan Summary: ${plan.planSummary}');
      
      for (var st in plan.scheduledTasks) {
        debugPrint('Task: ${st.task.title} | Priority Score: ${st.priorityScore.toStringAsFixed(1)} | Hidden: ${st.isHiddenDueToStress}');
        if (!st.isHiddenDueToStress) {
          debugPrint('  Micro-steps: ${st.microSteps}');
        }
      }

      // 1. Check cognitive load management: max visible should be 2 at stress 80
      expect(plan.visibleTaskCount, lessThanOrEqualTo(2));
      
      // 2. Check micro-step generation: high stress should trigger micro-steps
      final highTaskSt = plan.scheduledTasks.firstWhere((t) => t.task.id == 'task_1');
      expect(highTaskSt.microSteps.isNotEmpty, true);
    });

    test('Verification: Extreme Stress (90) Behavior', () async {
      mockDb.activeTasks = [highPriorityTask, lowPriorityTask];
      mockDb.completedToday = [];

      final plan = await scheduler.buildDailyPlan(
        currentStress: 90.0,
        profile: mockProfile,
      );

      debugPrint('\n--- EXTREME STRESS (90) PLAN ---');
      debugPrint('Visible Tasks: ${plan.visibleTaskCount}');
      
      // At stress 90, maxVisible should be 1
      expect(plan.visibleTaskCount, 1);
      expect(plan.scheduledTasks.firstWhere((t) => t.task.id == 'task_1').isHiddenDueToStress, false);
      expect(plan.scheduledTasks.firstWhere((t) => t.task.id == 'task_2').isHiddenDueToStress, true);
    });
  });
}
