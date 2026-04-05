import 'dart:math';
import 'package:flutter/material.dart';
import '../../pipeline/layer9_response/llm_service.dart';
import '../../models/task.dart';
import '../../models/user_profile.dart';
import '../storage/database_service.dart';
import '../../core/utils/helpers.dart';

class ScheduleSlot {
  final String label;
  final TimeOfDay start;
  final TimeOfDay end;
  final TaskComplexity maxComplexity;
  final String reasoning;

  const ScheduleSlot({
    required this.label,
    required this.start,
    required this.end,
    required this.maxComplexity,
    required this.reasoning,
  });
}

class ScheduledTask {
  final Task task;
  final ScheduleSlot? slot;
  final double priorityScore;
  final String? stressNote;
  final List<String> microSteps;
  final bool isHiddenDueToStress;

  const ScheduledTask({
    required this.task,
    this.slot,
    required this.priorityScore,
    this.stressNote,
    this.microSteps = const [],
    this.isHiddenDueToStress = false,
  });
}

class DailyPlan {
  final DateTime date;
  final List<ScheduledTask> scheduledTasks;
  final List<Task> deferredTasks;
  final double userStressLevel;
  final int visibleTaskCount;
  final String planSummary;
  final List<String> suggestions;

  const DailyPlan({
    required this.date,
    required this.scheduledTasks,
    required this.deferredTasks,
    required this.userStressLevel,
    required this.visibleTaskCount,
    required this.planSummary,
    required this.suggestions,
  });
}

class ScoredTaskPair {
  final Task task;
  final double score;
  ScoredTaskPair(this.task, this.score);
}

class SmartScheduler {
  final DatabaseService _db;
  SmartScheduler({DatabaseService? db}) : _db = db ?? DatabaseService.instance;
  static final instance = SmartScheduler();

  double computePriorityScore({
    required Task task,
    required double currentStress,
    required double taskCompletionRateToday,
  }) {
    final urgency = _computeUrgency(task);
    final importance = switch (task.priority) {
      4 => 100.0,
      3 => 75.0,
      2 => 50.0,
      _ => 25.0,
    };
    final complexityScore = switch (task.complexity) {
      TaskComplexity.micro   => 100.0,
      TaskComplexity.small   => 80.0,
      TaskComplexity.medium  => 60.0,
      TaskComplexity.large   => 40.0,
      TaskComplexity.project => 20.0,
    };
    final stressPenalty = currentStress > 70
        ? (100 - complexityScore) * 0.5
        : currentStress > 50
            ? (100 - complexityScore) * 0.2
            : 0.0;
    final cognitiveAdjusted = clamp(complexityScore - stressPenalty, 0, 100);
    final momentum = clamp(taskCompletionRateToday * 30, 0, 30);
    final score = (urgency * 0.40) +
                  (importance * 0.30) +
                  (cognitiveAdjusted * 0.15) +
                  (momentum * 0.15 / 30 * 100);
    return clamp(score, 0, 100);
  }

  double _computeUrgency(Task task) {
    if (task.deadline == null) return 10;
    final deadline = DateTime.fromMillisecondsSinceEpoch(task.deadline!);
    final now      = DateTime.now();
    final hoursLeft = deadline.difference(now).inHours;
    if (hoursLeft < 0)    return 100;
    if (hoursLeft < 6)    return 95;
    if (hoursLeft < 24)   return 90;
    if (hoursLeft < 48)   return 75;
    if (hoursLeft < 72)   return 60;
    if (hoursLeft < 168)  return 40;
    if (hoursLeft < 336)  return 20;
    return 10;
  }

  int _maxVisibleTasks(double stress) {
    if (stress >= 85) return 1;
    if (stress >= 70) return 2;
    if (stress >= 50) return 5;
    return 999;
  }

  List<String> _generateMicroSteps(Task task) {
    final steps = <String>[];
    if (task.subtasks.isNotEmpty) return task.subtasks;
    
    switch (task.category) {
      case TaskCategory.academic:
        steps.addAll(['Review reference material', 'Rough draft/Brainstorm', 'Finalize & Review']);
      case TaskCategory.professional:
        steps.addAll(['Check project specs', 'Immediate focus action', 'Team update/Status sync']);
      case TaskCategory.personal:
        steps.addAll(['Prepare environment', 'Perform action', 'Tidy up']);
      case TaskCategory.wellbeing:
        steps.addAll(['Find quiet space', 'Active focus', 'Reflect']);
      default:
        steps.addAll(['First small step', 'Main activity', 'Review']);
    }
    return steps.take(3).toList();
  }

  List<ScheduleSlot> _buildDailySlots(UserProfile profile) {
    final wakeHour  = profile.wakeTimeHour ?? 7;
    final sleepHour = profile.sleepTimeHour ?? 23;
    final profession = profile.profession;

    final slots = <ScheduleSlot>[];

    // Early Morning: Cognitive Peak
    slots.add(ScheduleSlot(
      label:         'Deep Focus Burst',
      start:         TimeOfDay(hour: wakeHour + 1, minute: 0),
      end:           TimeOfDay(hour: wakeHour + 3, minute: 0),
      maxComplexity: TaskComplexity.large,
      reasoning:     'Your brain is most refreshed now. Tackle the most complex task.',
    ));

    // Mid-Day: Profession-Specific Core
    if (profession == Profession.collegeStudent) {
      slots.add(const ScheduleSlot(
        label:         'Academic Deep Work',
        start:         TimeOfDay(hour: 10, minute: 0),
        end:           TimeOfDay(hour: 14, minute: 0),
        maxComplexity: TaskComplexity.large,
        reasoning:     'Ideal for assignments, research, or coding projects.',
      ));
    } else if (profession == Profession.schoolStudent) {
      slots.add(const ScheduleSlot(
        label:         'School/Board Prep',
        start:         TimeOfDay(hour: 14, minute: 0),
        end:           TimeOfDay(hour: 17, minute: 0),
        maxComplexity: TaskComplexity.medium,
        reasoning:     'After-school window for self-study and assignments.',
      ));
    } else if (profession == Profession.workingProfessional) {
      final isRemote = profile.professionalProfile?.workStyle == 'remote';
      slots.add(ScheduleSlot(
        label:         isRemote ? 'Agile Flow Session' : 'Office Execution',
        start:         const TimeOfDay(hour: 10, minute: 0),
        end:           const TimeOfDay(hour: 13, minute: 0),
        maxComplexity: TaskComplexity.large,
        reasoning:     isRemote ? 'Synchronous work with team and high focus.' : 'Primary sprint/execution hours.',
      ));
    }

    // Afternoon: Administrative/Medium Flow
    slots.add(const ScheduleSlot(
      label:         'Mid-Day Momentum',
      start:         TimeOfDay(hour: 15, minute: 0),
      end:           TimeOfDay(hour: 18, minute: 0),
      maxComplexity: TaskComplexity.medium,
      reasoning:     'Steady progress on medium-priority tasks.',
    ));

    // Evening: Review & Reflection
    slots.add(ScheduleSlot(
      label:         'Reflection & Prep',
      start:         const TimeOfDay(hour: 20, minute: 0),
      end:           TimeOfDay(hour: max(20, sleepHour - 1), minute: 0),
      maxComplexity: TaskComplexity.small,
      reasoning:     'Clear small blockers and prep for tomorrow.',
    ));

    return slots;
  }

  Future<DailyPlan> buildDailyPlan({
    required double currentStress,
    required UserProfile profile,
  }) async {
    final db              = _db;
    final allTasks        = await db.getActiveTasks(profile.id);
    final completedToday  = await db.getCompletedTasksToday(profile.id);
    final totalToday      = completedToday.length + allTasks.length;
    final completionRate  = totalToday > 0 ? completedToday.length / totalToday : 0.5;

    final slots           = _buildDailySlots(profile);
    final maxVisible      = _maxVisibleTasks(currentStress);
    final deferredTasks   = <Task>[];

    final scoredTasksList = allTasks.map((task) {
      final score = computePriorityScore(
        task:                       task,
        currentStress:              currentStress,
        taskCompletionRateToday:    completionRate,
      );
      return ScoredTaskPair(task, score);
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final scheduledTasks  = <ScheduledTask>[];
    int slotIndex         = 0;

    for (var i = 0; i < scoredTasksList.length; i++) {
        final pair = scoredTasksList[i];
      final task = pair.task;
      final score = pair.score;

      if (i >= maxVisible) {
        deferredTasks.add(task);
        scheduledTasks.add(ScheduledTask(
          task:               task,
          priorityScore:      score,
          isHiddenDueToStress: true,
        ));
        continue;
      }

      ScheduleSlot? assignedSlot;
      while (slotIndex < slots.length) {
        final slot = slots[slotIndex];
        final complexityOrder = TaskComplexity.values.indexOf(task.complexity);
        final slotOrder = TaskComplexity.values.indexOf(slot.maxComplexity);
        if (complexityOrder <= slotOrder) {
          assignedSlot = slot;
          slotIndex++;
          break;
        }
        slotIndex++;
      }

      final microSteps = (currentStress > 70 || task.complexity == TaskComplexity.large)
          ? _generateMicroSteps(task)
          : <String>[];

      scheduledTasks.add(ScheduledTask(
        task:          task,
        slot:          assignedSlot,
        priorityScore: score,
        stressNote:    task.stressAdjusted
            ? 'Priority adjusted due to current stress'
            : null,
        microSteps:    microSteps,
      ));
    }

    final visibleCount = scheduledTasks.where((t) => !t.isHiddenDueToStress).length;
    return DailyPlan(
      date:            DateTime.now(),
      scheduledTasks:  scheduledTasks,
      deferredTasks:   deferredTasks,
      userStressLevel: currentStress,
      visibleTaskCount:visibleCount,
      planSummary:     _buildPlanSummary(currentStress: currentStress, visible: visibleCount, total: allTasks.length),
      suggestions:     _buildSuggestions(stress: currentStress, tasks: allTasks, completionRate: completionRate),
    );
  }

  String _buildPlanSummary({required double currentStress, required int visible, required int total}) {
    if (total == 0) return 'No tasks yet.';
    if (currentStress >= 85) return 'High stress detected. Showing 1 critical task.';
    if (currentStress >= 70) return 'Showing top $visible tasks for focus.';
    if (visible == total) return 'All $total tasks shown.';
    return 'Showing $visible of $total tasks.';
  }

  List<String> _buildSuggestions({required double stress, required List<Task> tasks, required double completionRate}) {
    final suggestions = <String>[];
    
    // 1. Stress Management
    if (stress >= 80) {
      suggestions.add('🧘 Stress is high. Focus on just ONE task.');
    } else if (stress >= 60) {
      suggestions.add('🌬️ Take a 5-minute breather before starting.');
    }

    // 2. Urgent Tasks
    final urgentTasks = tasks.where((t) => t.deadline != null && t.status != TaskStatus.completed).toList()
      ..sort((a, b) => a.deadline!.compareTo(b.deadline!));

    if (urgentTasks.isNotEmpty) {
      final lead = urgentTasks.first;
      final hoursLeft = DateTime.fromMillisecondsSinceEpoch(lead.deadline!).difference(DateTime.now()).inHours;
      
      if (hoursLeft < 24 && hoursLeft >= 0) {
        suggestions.add('⏰ "${lead.title}" is due in $hoursLeft hours!');
      } else if (hoursLeft < 0) {
        suggestions.add('⚠️ "${lead.title}" is past due!');
      }
    }

    // 3. Quick Wins for Momentum
    if (completionRate < 0.3 && tasks.isNotEmpty) {
      final query = tasks.where((t) => t.complexity == TaskComplexity.micro || t.complexity == TaskComplexity.small).toList();
      if (query.isNotEmpty) {
        suggestions.add('🎯 Start with "${query.first.title}" for a quick win.');
      } else {
        suggestions.add('🎯 Break down your biggest task into steps.');
      }
    }

    // 4. Fallback
    if (suggestions.isEmpty) {
      if (tasks.isEmpty) {
        suggestions.add('🌱 Add a task to start your growth journey.');
      } else {
        suggestions.add('✅ You\'re doing great! Keep the momentum.');
      }
    }

    return suggestions.take(3).toList();
  }

  /// Generates a personalized explanation of the schedule using the local LLM.
  Future<String> explainPlan({
    required DailyPlan plan,
    required UserProfile profile,
  }) async {
    final llm = LLMService.instance;
    if (!llm.isReady) return "Here's your optimized schedule for today.";

    final systemPrompt = """
You are Utkarsh, a student's empathetic productivity guide.
Explain the current daily schedule. Focus on:
1. Why tasks were ordered this way (stress-aware)
2. Encouragement for the student (${profile.displayName})
Keep it under 3 sentences. Warm tone.
""";

    final taskTitles = plan.scheduledTasks.where((t) => !t.isHiddenDueToStress).map((t) => t.task.title).join(', ');
    final context = "User Stress: ${plan.userStressLevel}/100. Visible Tasks: $taskTitles. Hidden due to stress: ${plan.deferredTasks.length}.";

    try {
      return await llm.generate(
        history: [ChatMessage(role: MessageRole.user, content: context)],
        systemPrompt: systemPrompt,
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      return "I've optimized your day to balance productivity and wellness. You've got this!";
    }
  }
}
