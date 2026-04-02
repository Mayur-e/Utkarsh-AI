import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/storage/database_service.dart';
import '../../../services/response/response_engine.dart';
import '../../../services/growth/xp_service.dart';
import '../../../state/app_state.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _pendingTasks = [];
  List<Map<String, dynamic>> _doneTasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    await responseEngineProvider.ensureInitialized();
    final active = await databaseServiceProvider.getActiveTasks();
    final done = await databaseServiceProvider.getCompletedTasks();
    if (mounted) {
      setState(() {
        _pendingTasks = active;
        _doneTasks = done;
        _loading = false;
      });
    }
  }

  Future<void> _markDone(Map<String, dynamic> task) async {
    await databaseServiceProvider.updateTaskStatus(
      task['id'] as String,
      'completed',
    );
    // Award XP for completing a task
    final xpEarned = await xpService.award('TASK_COMPLETED');
    await _loadTasks();
    if (mounted && xpEarned > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Task done! +$xpEarned XP earned'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      );
    }
  }

  Future<void> _deleteTask(String id) async {
    await databaseServiceProvider.deleteTask(id);
    await _loadTasks();
  }

  Future<void> _addTaskManually() async {
    final titleCtrl = TextEditingController();
    DateTime? deadline;
    int priority = 2;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.lg,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Task',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: AppFontSizes.lg,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  style: const TextStyle(color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: 'What do you need to do?',
                    hintStyle:
                        const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Priority selector
                const Text('Priority',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppFontSizes.sm)),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _priorityChip(1, 'Low', AppColors.info, priority,
                        (v) => setModal(() => priority = v)),
                    const SizedBox(width: AppSpacing.sm),
                    _priorityChip(2, 'Medium', AppColors.warning,
                        priority, (v) => setModal(() => priority = v)),
                    const SizedBox(width: AppSpacing.sm),
                    _priorityChip(3, 'High', AppColors.danger, priority,
                        (v) => setModal(() => priority = v)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Deadline
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (c, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                              primary: AppColors.primary),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setModal(() => deadline = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            color: AppColors.textMuted, size: 16),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          deadline == null
                              ? 'Set deadline (optional)'
                              : '${deadline!.day}/${deadline!.month}/${deadline!.year}',
                          style: TextStyle(
                              color: deadline == null
                                  ? AppColors.textMuted
                                  : AppColors.text,
                              fontSize: AppFontSizes.sm),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      Navigator.pop(ctx);
                      await databaseServiceProvider.saveTask({
                        'title': title,
                        'deadline':
                            deadline?.millisecondsSinceEpoch,
                        'priority': priority,
                        'status': 'pending',
                        'extracted_from_chat': 0,
                      });
                      await _loadTasks();
                    },
                    child: const Text('Add Task',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: AppFontSizes.md)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _priorityChip(int value, String label, Color color,
      int selected, void Function(int) onTap) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : AppColors.surfaceElevated,
          border: Border.all(
              color: isSelected ? color : Colors.transparent, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? color : AppColors.textMuted,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: AppFontSizes.sm)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for refreshes from the chat tab
    ref.listen(chatRefreshProvider, (prev, next) {
      _loadTasks();
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTaskManually,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tasks',
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: AppFontSizes.xxl,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '${_pendingTasks.length} pending · ${_doneTasks.length} completed',
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: AppFontSizes.sm),
                  ),
                ],
              ),
            ),

            // ── Tabs ────────────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.primary,
                dividerColor: AppColors.surfaceElevated,
                tabs: const [
                  Tab(text: 'Pending'),
                  Tab(text: 'Completed'),
                ],
              ),
            ),

            // ── Content ─────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTaskList(_pendingTasks, isDone: false),
                        _buildTaskList(_doneTasks, isDone: true),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList(List<Map<String, dynamic>> tasks,
      {required bool isDone}) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDone ? Icons.check_circle_outline : Icons.task_alt,
              color: AppColors.textMuted,
              size: 64,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isDone ? 'No completed tasks yet' : 'No pending tasks! 🎉',
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: AppFontSizes.md),
            ),
            if (!isDone) ...[
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Add a task manually or mention tasks in chat',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: AppFontSizes.sm),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _loadTasks,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
        itemCount: tasks.length,
        itemBuilder: (ctx, i) => _TaskCard(
          task: tasks[i],
          isDone: isDone,
          onComplete: isDone ? null : () => _markDone(tasks[i]),
          onDelete: () => _deleteTask(tasks[i]['id'] as String),
        ),
      ),
    );
  }
}

// ── Task Card Widget ────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final bool isDone;
  final VoidCallback? onComplete;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.task,
    required this.isDone,
    required this.onComplete,
    required this.onDelete,
  });

  Color get _priorityColor {
    final p = task['priority'] as int? ?? 2;
    if (p == 3) return AppColors.danger;
    if (p == 2) return AppColors.warning;
    return AppColors.info;
  }

  String get _priorityLabel {
    final p = task['priority'] as int? ?? 2;
    if (p == 3) return 'High';
    if (p == 2) return 'Medium';
    return 'Low';
  }

  String get _deadlineLabel {
    final ms = task['deadline'] as int?;
    if (ms == null) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    
    // Normalize to date (midnight) for calendar day difference
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDate = DateTime(d.year, d.month, d.day);
    final daysDiff = deadlineDate.difference(today).inDays;

    if (daysDiff < 0) return 'Overdue';
    if (daysDiff == 0) return 'Due today';
    if (daysDiff == 1) return 'Due tomorrow';
    return 'Due in ${daysDiff}d';
  }

  bool get _isOverdue {
    final ms = task['deadline'] as int?;
    if (ms == null) return false;
    return DateTime.fromMillisecondsSinceEpoch(ms).isBefore(DateTime.now());
  }

  bool get _fromChat => (task['extracted_from_chat'] as int? ?? 0) == 1;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(task['id'] as String),
      direction: isDone
          ? DismissDirection.endToStart
          : DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd && !isDone) {
          onComplete?.call();
          return false; // handled by callback
        }
        // endToStart = delete
        return true;
      },
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppSpacing.lg),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Icon(Icons.check, color: AppColors.success),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isDone
                ? Colors.transparent
                : _isOverdue
                    ? AppColors.danger.withValues(alpha: 0.4)
                    : AppColors.surfaceElevated,
            width: 1,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          leading: GestureDetector(
            onTap: onComplete,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : Colors.transparent,
                border: Border.all(
                    color: isDone ? AppColors.primary : AppColors.textMuted,
                    width: 2),
              ),
              child: isDone
                  ? const Icon(Icons.check,
                      color: AppColors.primary, size: 16)
                  : null,
            ),
          ),
          title: Text(
            task['title'] as String? ?? '',
            style: TextStyle(
              color: isDone ? AppColors.textMuted : AppColors.text,
              fontSize: AppFontSizes.md,
              fontWeight: FontWeight.w600,
              decoration:
                  isDone ? TextDecoration.lineThrough : TextDecoration.none,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: 4,
              children: [
                // Priority badge
                _badge(_priorityLabel, _priorityColor),

                // Deadline badge
                if (_deadlineLabel.isNotEmpty)
                  _badge(
                    _deadlineLabel,
                    _isOverdue ? AppColors.danger : AppColors.textMuted,
                  ),

                // Chat-extracted badge
                if (_fromChat)
                  _badge('From Chat', AppColors.accent),
              ],
            ),
          ),
          trailing: !isDone
              ? PopupMenuButton<String>(
                  color: AppColors.surfaceElevated,
                  icon: const Icon(Icons.more_vert,
                      color: AppColors.textMuted, size: 20),
                  onSelected: (val) {
                    if (val == 'done') onComplete?.call();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'done',
                        child: Row(children: [
                          Icon(Icons.check_circle_outline,
                              color: AppColors.success, size: 18),
                          SizedBox(width: 8),
                          Text('Mark done',
                              style: TextStyle(color: AppColors.text))
                        ])),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline,
                              color: AppColors.danger, size: 18),
                          SizedBox(width: 8),
                          Text('Delete',
                              style: TextStyle(color: AppColors.text))
                        ])),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: AppFontSizes.xs,
              fontWeight: FontWeight.w600)),
    );
  }
}
