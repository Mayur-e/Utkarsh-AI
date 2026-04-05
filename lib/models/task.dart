// Task model for wellbeing-driven scheduling

enum TaskStatus {
  pending,
  inProgress,
  completed,
  cancelled,
  snoozed,
  deferred,           // Rescheduled by smart scheduler
}

enum TaskCategory {
  academic,           // Assignments, exams, projects
  personal,           // Health, errands, habits
  social,             // Plans with people
  professional,       // Work tasks
  creative,           // Creative pursuits
  admin,              // Forms, emails, paperwork
  wellbeing,          // Meditation, reflection, check-ins
  other,
}

enum TaskComplexity {
  micro,              // < 15 minutes
  small,              // 15-45 minutes
  medium,             // 45-120 minutes
  large,              // 2-4 hours
  project,            // Multiple days
}

class Task {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final int? deadline;          // milliseconds timestamp
  final int priority;           // 1=low, 2=medium, 3=high, 4=critical
  final TaskStatus status;
  final TaskCategory category;
  final TaskComplexity complexity;
  final bool extractedFromChat;
  final int? preMood;
  final int? postMood;
  final int createdAt;
  final int? completedAt;
  final int? snoozedUntil;      // New: snooze support
  final int? deferredTo;        // New: deferred date timestamp
  final List<String> subtasks;  // New: micro-steps for large tasks
  final int estimatedMinutes;   // New: time estimate
  final int? scheduledFor;      // New: scheduled time slot
  final double priorityScore;   // Computed by scheduler
  final bool stressAdjusted;    // Was priority lowered due to stress?

  const Task({
    required this.id,
    this.userId = 'local_user',
    required this.title,
    this.description,
    this.deadline,
    required this.priority,
    required this.status,
    this.category = TaskCategory.academic,
    this.complexity = TaskComplexity.medium,
    this.extractedFromChat = false,
    this.preMood,
    this.postMood,
    required this.createdAt,
    this.completedAt,
    this.snoozedUntil,
    this.deferredTo,
    this.subtasks = const [],
    this.estimatedMinutes = 30,
    this.scheduledFor,
    this.priorityScore = 50.0,
    this.stressAdjusted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'deadline': deadline,
      'priority': priority,
      'status': status.name,
      'category': category.name,
      'complexity': complexity.name,
      'extracted_from_chat': extractedFromChat ? 1 : 0,
      'pre_mood': preMood,
      'post_mood': postMood,
      'created_at': createdAt,
      'completed_at': completedAt,
      'snoozed_until': snoozedUntil,
      'deferred_to': deferredTo,
      'subtasks': subtasks.join('|'),
      'estimated_minutes': estimatedMinutes,
      'scheduled_for': scheduledFor,
      'priority_score': priorityScore,
      'stress_adjusted': stressAdjusted ? 1 : 0,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      userId: map['user_id'] ?? 'local_user',
      title: map['title'],
      description: map['description'],
      deadline: map['deadline'],
      priority: map['priority'],
      status: TaskStatus.values.firstWhere((e) => e.name == map['status'], orElse: () => TaskStatus.pending),
      category: TaskCategory.values.firstWhere((e) => e.name == (map['category'] ?? 'academic'), orElse: () => TaskCategory.academic),
      complexity: TaskComplexity.values.firstWhere((e) => e.name == (map['complexity'] ?? 'medium'), orElse: () => TaskComplexity.medium),
      extractedFromChat: map['extracted_from_chat'] == 1,
      preMood: map['pre_mood'],
      postMood: map['post_mood'],
      createdAt: map['created_at'],
      completedAt: map['completed_at'],
      snoozedUntil: map['snoozed_until'],
      deferredTo: map['deferred_to'],
      subtasks: (map['subtasks'] as String?)?.split('|').where((s) => s.isNotEmpty).toList() ?? [],
      estimatedMinutes: map['estimated_minutes'] ?? 30,
      scheduledFor: map['scheduled_for'],
      priorityScore: (map['priority_score'] as num?)?.toDouble() ?? 50.0,
      stressAdjusted: map['stress_adjusted'] == 1,
    );
  }

  Task copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    int? deadline,
    int? priority,
    TaskStatus? status,
    TaskCategory? category,
    TaskComplexity? complexity,
    bool? extractedFromChat,
    int? preMood,
    int? postMood,
    int? createdAt,
    int? completedAt,
    int? snoozedUntil,
    int? deferredTo,
    List<String>? subtasks,
    int? estimatedMinutes,
    int? scheduledFor,
    double? priorityScore,
    bool? stressAdjusted,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      deadline: deadline ?? this.deadline,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      category: category ?? this.category,
      complexity: complexity ?? this.complexity,
      extractedFromChat: extractedFromChat ?? this.extractedFromChat,
      preMood: preMood ?? this.preMood,
      postMood: postMood ?? this.postMood,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      deferredTo: deferredTo ?? this.deferredTo,
      subtasks: subtasks ?? this.subtasks,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      priorityScore: priorityScore ?? this.priorityScore,
      stressAdjusted: stressAdjusted ?? this.stressAdjusted,
    );
  }
}
