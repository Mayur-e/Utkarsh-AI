import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/prism_card.dart';
import '../../../services/auth/auth_service.dart';
import '../../../services/storage/database_service.dart';
import '../../../services/response/response_engine.dart';
import '../../../services/growth/xp_service.dart';
import '../../../services/tasks/smart_scheduler.dart';
import '../../../models/task.dart';
import '../../../state/app_state.dart';
import '../../../core/utils/helpers.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DailyPlan? _dailyPlan;
  List<Task> _completedTasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshWork();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshWork() async {
    setState(() => _loading = true);
    await responseEngineProvider.ensureInitialized();
    
    // Get profile and build smart plan
    final profile = await responseEngineProvider.getCurrentProfile();
    
    // For now, assume a baseline stress or get from latest message
    double currentStress = 30.0;
    try {
      final msgs = await databaseServiceProvider.getRecentMessages(limit: 1, userId: profile.id);
      if (msgs.isNotEmpty) {
        currentStress = (msgs.first['stress_level'] as num?)?.toDouble() ?? 30.0;
      }
    } catch (_) {}

    final plan = await SmartScheduler.instance.buildDailyPlan(
      currentStress: currentStress,
      profile: profile,
    );

    final completed = await databaseServiceProvider.getCompletedTasks(profile.id);
    // Convert Map to Task for the completed list
    final completedModels = completed.map((m) => Task.fromMap(m)).toList();

    if (mounted) {
      setState(() {
        _dailyPlan = plan;
        _completedTasks = completedModels;
        _loading = false;
      });
    }
  }

  Future<void> _markDone(Task task) async {
    await databaseServiceProvider.updateTaskStatus(task.id, 'completed');
    final xpEarned = await xpService.award('TASK_COMPLETED');
    await _refreshWork();
    
    if (mounted && xpEarned > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Task done! +$xpEarned XP earned'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      );
    }
  }

  Future<void> _deleteTask(String id) async {
    await databaseServiceProvider.deleteTask(id);
    await _refreshWork();
  }

  Future<void> _editTask(Task task) async {
    final titleCtrl = TextEditingController(text: task.title);
    TaskCategory category = task.category;
    TaskComplexity complexity = task.complexity;
    int priority = task.priority;
    DateTime? deadline = task.deadline != null ? DateTime.fromMillisecondsSinceEpoch(task.deadline!) : null;

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Edit Task', style: AppTypography.h3),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: 'Update title',
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                
                Row(
                  children: [
                    Expanded(
                      child: _dropdown<TaskCategory>(
                        'Category',
                        category,
                        TaskCategory.values,
                        (v) => setModal(() => category = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                const Text('Importance', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (int i = 1; i <= 4; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _priorityBtn(i, priority, (v) => setModal(() => priority = v)),
                      ),
                  ],
                ),
                const Text('Deadline', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: deadline ?? DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setModal(() => deadline = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Text(deadline == null ? 'No Deadline' : '${deadline!.day}/${deadline!.month}/${deadline!.year}', 
                          style: TextStyle(color: deadline == null ? AppColors.textMuted : AppColors.text, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary),
                    onPressed: () async {
                      if (titleCtrl.text.isEmpty) return;
                      final updated = task.copyWith(
                        title: titleCtrl.text,
                        priority: priority,
                        category: category,
                        complexity: complexity,
                        deadline: deadline?.millisecondsSinceEpoch,
                      );
                      await databaseServiceProvider.updateTask(updated);
                      _refreshWork();
                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _addTaskManually() async {
    final titleCtrl = TextEditingController();
    TaskCategory category = TaskCategory.academic;
    TaskComplexity complexity = TaskComplexity.medium;
    int priority = 2;
    DateTime? deadline;

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Add Task', style: AppTypography.h3),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  style: const TextStyle(color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: 'What\'s on your mind?',
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                
                // Category
                Row(
                  children: [
                    Expanded(
                      child: _dropdown<TaskCategory>(
                        'Category',
                        category,
                        TaskCategory.values,
                        (v) => setModal(() => category = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Priority
                const Text('Importance', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (int i = 1; i <= 4; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _priorityBtn(i, priority, (v) => setModal(() => priority = v)),
                      ),
                  ],
                ),
                // Deadline
                const Text('Deadline', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setModal(() => deadline = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Text(deadline == null ? 'Set Optional Deadline' : '${deadline!.day}/${deadline!.month}/${deadline!.year}', 
                          style: TextStyle(color: deadline == null ? AppColors.textMuted : AppColors.text, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary),
                    onPressed: () async {
                      if (titleCtrl.text.isEmpty) return;
                      final t = Task(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        userId: AuthService.instance.currentUser?.id ?? 'local_user',
                        title: titleCtrl.text,
                        priority: priority,
                        status: TaskStatus.pending,
                        category: category,
                        complexity: complexity,
                        createdAt: DateTime.now().millisecondsSinceEpoch,
                        deadline: deadline?.millisecondsSinceEpoch,
                      );
                      await databaseServiceProvider.saveTask(t);
                      _refreshWork();
                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                    child: const Text('Save Task'),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _priorityBtn(int val, int selected, Function(int) onTap) {
    final isSel = val == selected;
    final color = switch(val) {
      4 => AppColors.error,
      3 => AppColors.warning,
      2 => AppColors.primary,
      _ => AppColors.textMuted,
    };
    return GestureDetector(
      onTap: () => onTap(val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? color.withValues(alpha: 0.1) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSel ? color : Colors.transparent),
        ),
        child: Text(
          switch(val) { 4=>'Critical', 3=>'High', 2=>'Med', _=>'Low' },
          style: TextStyle(color: isSel ? color : AppColors.textMuted, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, fontSize: 12),
        ),
      ),
    );
  }

  Widget _dropdown<T extends Enum>(String label, T value, List<T> items, Function(T?) onChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(8)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              dropdownColor: AppColors.surfaceElevated,
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.name, style: const TextStyle(color: AppColors.text, fontSize: 14)))).toList(),
              onChanged: onChange,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chatRefreshProvider, (prev, next) => _refreshWork());

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
            child: Column(
          children: [
            _buildHeader(),
            _buildTabs(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSmartPlanTab(),
                        _buildCompletedTab(),
                      ],
                    ),
            ),
          ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily Engine', style: AppTypography.h1),
                if (_dailyPlan != null)
                  Text(_dailyPlan!.planSummary, style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          IconButton(
            onPressed: _addTaskManually,
            icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primaryLight,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.primary,
        dividerColor: Colors.transparent,
        tabs: const [Tab(text: 'Morning Plan'), Tab(text: 'Archive')],
      ),
    );
  }

  Widget _buildSmartPlanTab() {
    if (_dailyPlan == null || _dailyPlan!.scheduledTasks.isEmpty) {
      return _emptyState('No tasks scheduled. Check in to extract tasks!');
    }

    final visible = _dailyPlan!.scheduledTasks.where((t) => !t.isHiddenDueToStress).toList();

    return RefreshIndicator(
      onRefresh: _refreshWork,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Suggestions Card
          if (_dailyPlan!.suggestions.isNotEmpty)
            _buildSuggestionsCard(),
          const SizedBox(height: AppSpacing.lg),
          
          // Tasks
          for (final stask in visible)
            _TaskTile(
              stask: stask,
              onDone: () => _markDone(stask.task),
              onEdit: () => _editTask(stask.task),
              onDelete: () => _deleteTask(stask.task.id),
            ),
            
          if (_dailyPlan!.deferredTasks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Text('${_dailyPlan!.deferredTasks.length} Deferred Tasks', style: AppTypography.h4.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.md),
            const Text('These are hidden to reduce your cognitive load today.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]
        ],
      ),
    );
  }

  Widget _buildSuggestionsCard() {
    return PrismCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Wellness Strategy', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 8),
          for (final s in _dailyPlan!.suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $s', style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }

  Widget _buildCompletedTab() {
    if (_completedTasks.isEmpty) {
      return _emptyState('Finish a task to see it here!');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _completedTasks.length,
      itemBuilder: (context, i) => _TaskTile(
        stask: ScheduledTask(task: _completedTasks[i], priorityScore: 0),
        isDone: true,
        onEdit: () => _editTask(_completedTasks[i]),
        onDelete: () => _deleteTask(_completedTasks[i].id),
      ),
    );
  }

  Widget _emptyState(String msg) {
    return Center(child: Text(msg, style: const TextStyle(color: AppColors.textMuted)));
  }
}

class _TaskTile extends StatelessWidget {
  final ScheduledTask stask;
  final bool isDone;
  final VoidCallback? onDone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TaskTile({required this.stask, this.isDone = false, this.onDone, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final task = stask.task;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: PrismCard(
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: GestureDetector(
              onTap: onDone,
              child: Icon(isDone ? Icons.check_circle : Icons.circle_outlined, color: isDone ? AppColors.success : AppColors.onSurfaceVariant),
            ),
            title: Text(task.title, style: TextStyle(color: isDone ? AppColors.onSurfaceVariant : AppColors.onSurface, fontWeight: FontWeight.bold, decoration: isDone ? TextDecoration.lineThrough : null), overflow: TextOverflow.ellipsis, maxLines: 1),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _miniBadge(task.category.name, AppColors.primary),
                    if (stask.slot != null)
                      _miniBadge(stask.slot!.label, AppColors.accent),
                    if (task.deadline != null)
                      _miniBadge(formatDate(task.deadline!), AppColors.warning),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, color: AppColors.onSurfaceVariant, size: 20)),
                IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: AppColors.onSurfaceVariant, size: 20)),
              ],
            ),
          ),
          if (stask.microSteps.isNotEmpty && !isDone)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: AppColors.surfaceElevated),
                  const SizedBox(height: 8),
                  const Text('Micro-steps for focus:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  for (final step in stask.microSteps)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.play_arrow, size: 10, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(child: Text(step, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant))),
                        ],
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

  Widget _miniBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }
}
