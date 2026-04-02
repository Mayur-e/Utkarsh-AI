import 'dart:math' as math;

class ExtractedTask {
  final String title;
  final DateTime? deadline;
  final int priority; // 1, 2, 3
  final double confidence;

  ExtractedTask({
    required this.title,
    this.deadline,
    required this.priority,
    required this.confidence,
  });
}

class TaskExtractionService {
  static const List<String> taskTriggers = [
    'i have to', 'i need to', 'i must', 'i should',
    'need to submit', 'need to finish', 'need to complete',
    'assignment', 'homework', 'exam', 'test', 'quiz', 'project',
    'submit', 'deadline', 'due', 'prepare for', 'study for',
    'finish', 'complete', 'write', 'present', 'presentation',
    'add it', 'add this', 'add to task', 'add to my task', 'add it to my task',
    'remind me', 'note this', 'save this',
  ];

  // Subject prefixes that commonly appear before task types
  static const List<String> subjectPrefixes = [
    'chemistry', 'physics', 'maths', 'math', 'biology', 'english',
    'history', 'geography', 'science', 'computer', 'cs', 'economics',
    'hindi', 'sanskrit', 'social', 'civics', 'accounting', 'commerce',
  ];

  static const List<String> taskTypes = [
    'assignment', 'exam', 'test', 'quiz', 'project', 'report',
    'homework', 'viva', 'presentation', 'lab', 'practicals',
  ];

  static const List<String> priorityHigh = [
    'today', 'tonight', 'tomorrow', 'urgent', 'asap', 'final exam', 'submission day', 'viva'
  ];

  static const List<String> priorityLow = [
    'someday', 'eventually', 'maybe', 'later', 'sometime'
  ];

  List<ExtractedTask> extract(String text, {double currentStressLevel = 30.0, List<Map<String, dynamic>>? history}) {
    final lower = text.toLowerCase();
    
    // Check if user is referencing a previous context (e.g. "add it", "note that")
    bool isContextual = lower.contains('add it') || 
                        lower.contains('add this') || 
                        lower.contains('save this') || 
                        lower.contains('note that');

    // IF it's a modification request, don't extract as a NEW task
    if (lower.contains('update') || lower.contains('change') || lower.contains('set')) {
      if (lower.contains('its') || lower.contains('that') || lower.contains(' it ') || lower.endsWith(' it')) {
        return [];
      }
    }

    if (!taskTriggers.any((t) => lower.contains(t))) return [];

    final List<ExtractedTask> tasks = [];
    
    // If contextual, try to find the subject or task type in the last 4 messages of history
    if (isContextual && history != null && history.isNotEmpty) {
      for (final msg in history.reversed.take(4)) {
        final content = (msg['content'] as String).toLowerCase();
        
        bool foundAny = false;
        // Search for academic subjects (Chemistry, Physics, etc.)
        for (final subject in subjectPrefixes) {
          if (content.contains(subject)) {
             String taskTypeFound = 'Task';
             for (final tt in taskTypes) {
               if (content.contains(tt)) {
                 taskTypeFound = tt;
                 break;
               }
             }
             final title = '${_capitalize(subject)} ${_capitalize(taskTypeFound)}';
             if (!tasks.any((t) => t.title == title)) {
               tasks.add(ExtractedTask(
                 title: title,
                 deadline: _extractDeadline(lower) ?? _extractDeadline(content),
                 priority: _calcPriority(lower, currentStressLevel),
                 confidence: 0.95,
               ));
               foundAny = true;
             }
          }
        }
        
        // If no subject found, search for standalone task types (Exam, Assignment, etc.)
        if (!foundAny) {
           for (final tt in taskTypes) {
             if (content.contains(tt)) {
                final title = _capitalize(tt);
                if (!tasks.any((t) => t.title == title)) {
                   tasks.add(ExtractedTask(
                     title: title,
                     deadline: _extractDeadline(lower) ?? _extractDeadline(content),
                     priority: _calcPriority(lower, currentStressLevel),
                     confidence: 0.90,
                   ));
                   foundAny = true;
                }
             }
           }
        }
        
        if (tasks.isNotEmpty) break; // Found the context
      }
    }

    // ── Pattern 0: "deadline for <subject> <taskType>" ───────────────────
    for (final subject in subjectPrefixes) {
      for (final taskType in taskTypes) {
        if (lower.contains('$subject $taskType') ||
            lower.contains('$subject\'s $taskType')) {
          final title =
              '${_capitalize(subject)} ${_capitalize(taskType)}';
          if (!tasks.any((t) => t.title.toLowerCase() == title.toLowerCase())) {
            tasks.add(ExtractedTask(
              title: title,
              deadline: _extractDeadline(lower),
              priority: _calcPriority(lower, currentStressLevel),
              confidence: 0.90,
            ));
          }
        }
      }
    }

    // ── Pattern 1: "deadline for X" or "due for X" ───────────────────────
    final deadlineForRegex =
        RegExp(r'(?:deadline|due)\s+for\s+([\w\s]{3,40}?)(?:\s+is|\s+on|\s*$|[.,!?])',
            caseSensitive: false);
    for (final m in deadlineForRegex.allMatches(text)) {
      final raw = m.group(1)?.trim() ?? '';
      if (raw.length >= 3) {
        final title = _capitalize(raw);
        if (!tasks.any((t) => t.title.toLowerCase() == title.toLowerCase())) {
          tasks.add(ExtractedTask(
            title: title,
            deadline: _extractDeadline(lower),
            priority: _calcPriority(lower, currentStressLevel),
            confidence: 0.85,
          ));
        }
      }
    }

    // ── Pattern 2: {count} {taskType}s ──────────────────────────────────
    final countRegex = RegExp(r'(\d+|two|three|four|five)\s+(assignments?|tasks?|projects?|reports?|submissions?)', caseSensitive: false);
    final countMatches = countRegex.allMatches(text);

    for (final match in countMatches) {
      final rawCount = match.group(1)!;
      final count = int.tryParse(rawCount) ?? _wordToNum(rawCount) ?? 1;
      final type = match.group(2)!.replaceAll(RegExp(r's$'), ''); // Singularize
      
      for (int i = 1; i <= math.min(count, 5); i++) {
        tasks.add(ExtractedTask(
          title: '${_capitalize(type)} $i',
          deadline: _extractDeadline(lower),
          priority: _calcPriority(lower, currentStressLevel),
          confidence: 0.8,
        ));
      }
    }

    // ── Single task extraction from sentences ────────────────────────────
    if (tasks.isEmpty) {
      final sentences = text.split(RegExp(r'[.!?\n]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      for (final sentence in sentences) {
        final sLower = sentence.toLowerCase();
        if (!taskTriggers.any((t) => sLower.contains(t))) continue;
        if (sentence.length < 8) continue;

        final title = _cleanTitle(sentence);
        if (title.isEmpty || title.length < 5) continue;
        if (tasks.any((t) => t.title.toLowerCase() == title.toLowerCase())) continue;

        tasks.add(ExtractedTask(
          title: title.length > 120 ? title.substring(0, 120) : title,
          deadline: _extractDeadline(sLower),
          priority: _calcPriority(sLower, currentStressLevel),
          confidence: 0.75,
        ));
      }
    }

    return tasks.take(6).toList(); // Max 6 tasks
  }

  int? _wordToNum(String word) {
    const map = {'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5};
    return map[word.toLowerCase()];
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _cleanTitle(String sentence) {
    return sentence
        .replaceFirst(RegExp(r'^(i have to|i need to|i must|i should|need to)\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*(by|due|before|on|at)\s+\w+.*$', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*(today|tonight|tomorrow|next week|this week)\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[.!?,;]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  DateTime? extractDeadline(String text) => _extractDeadline(text.toLowerCase());
  int extractPriority(String text, double stressLevel) => _calcPriority(text.toLowerCase(), stressLevel);

  DateTime? _extractDeadline(String lower) {
    final now = DateTime.now();

    if (lower.contains('yesterday')) {
      final d = now.subtract(const Duration(days: 1));
      return DateTime(d.year, d.month, d.day, 23, 59);
    }
    if (lower.contains('today') || lower.contains('tonight')) {
      return DateTime(now.year, now.month, now.day, 23, 59);
    }
    if (lower.contains('tomorrow')) {
      final d = now.add(const Duration(days: 1));
      return DateTime(d.year, d.month, d.day, 23, 59);
    }
    
    final inDaysMatch = RegExp(r'in (\d+) days?').firstMatch(lower);
    if (inDaysMatch != null) {
      final n = int.tryParse(inDaysMatch.group(1)!);
      if (n != null) {
        final d = now.add(Duration(days: n));
        return DateTime(d.year, d.month, d.day, 23, 59);
      }
    }

    if (lower.contains('this week')) {
      final d = now.add(const Duration(days: 5));
      return DateTime(d.year, d.month, d.day, 23, 59);
    }
    if (lower.contains('next week')) {
      final d = now.add(const Duration(days: 7));
      return DateTime(d.year, d.month, d.day, 23, 59);
    }

    return null;
  }

  int _calcPriority(String lower, double stressLevel) {
    int priority = 2;
    if (priorityHigh.any((k) => lower.contains(k))) {
      priority = 3;
    } else if (priorityLow.any((k) => lower.contains(k))) {
      priority = 1;
    }

    // Stress protection logic
    if (stressLevel >= 75.0 && priority == 3) return 2;
    if (stressLevel >= 90.0 && priority >= 2) return 1;

    return priority;
  }
}

final taskExtractionServiceProvider = TaskExtractionService();
