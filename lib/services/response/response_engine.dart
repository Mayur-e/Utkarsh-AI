import '../input/input_capture_service.dart';
import '../emotion/emotion_service.dart';
import '../intent/intent_service.dart';
import '../behavior/behavior_service.dart';
import '../tasks/task_extraction_service.dart';
import '../cws/cws_engine.dart';
import '../decision/decision_engine.dart';
import '../decision/groq_client.dart';
import '../storage/database_service.dart';
import '../growth/xp_service.dart';
import '../notifications/notification_service.dart';
import '../../models/intent.dart';
import '../../models/emotion.dart';
import '../../state/app_state.dart';

class PipelineResult {
  final String response;
  final EmotionLabel emotionLabel;
  final double stressLevel;
  final IntentClass intent;
  final double cwsScore;
  final AIMode aiMode;
  final int tasksExtracted;
  final String sessionId;

  PipelineResult({
    required this.response,
    required this.emotionLabel,
    required this.stressLevel,
    required this.intent,
    required this.cwsScore,
    required this.aiMode,
    required this.tasksExtracted,
    required this.sessionId,
  });
}

/// Singleton ResponseEngine that orchestrates the full 7-layer V2 pipeline.
class ResponseEngine {
  // ── Singleton ──────────────────────────────────────────────────────────
  ResponseEngine._internal();
  static final ResponseEngine _instance = ResponseEngine._internal();
  factory ResponseEngine() => _instance;

  // ── Session ────────────────────────────────────────────────────────────
  late final String _sessionId =
      'session_${DateTime.now().millisecondsSinceEpoch}';

  String get sessionId => _sessionId;

  // ── Services (singletons via top-level providers) ──────────────────────
  final InputCaptureService _inputSvc = inputCaptureServiceProvider;
  final EmotionService _emotionSvc = emotionServiceSingleton;
  final IntentService _intentSvc = intentServiceSingleton;
  final BehaviorService _behaviorSvc = behaviorServiceProvider;
  final TaskExtractionService _taskSvc = taskExtractionServiceProvider;
  final CWSEngine _cwsSvc = cwsEngineProvider;
  final DecisionEngine _decisionSvc = decisionEngineProvider;
  final DatabaseService _db = databaseServiceProvider;

  bool _initialized = false;

  // ── Initialization ─────────────────────────────────────────────────────
  Future<void> ensureInitialized() async {
    if (_initialized) return;

    // 1. Storage first
    await _db.initialize();

    // 2. ML models (these fall back gracefully if ONNX fails)
    await _emotionSvc.initialize();
    await _intentSvc.initialize();

    _initialized = true;
  }

  // ── Main Pipeline ──────────────────────────────────────────────────────
  Future<PipelineResult> process(
      String userText, List<GroqMessage> history) async {
    await ensureInitialized();

    // Layer 1 – Input Capture
    final input = _inputSvc.capture(userText);

    // Layer 2 – Emotion Detection
    final emotionResult = await _emotionSvc.analyze(input.normalized);
    final emotionLabel = emotionResult.sentiment;
    final stressLevel = emotionResult.stressLevel;
    final granularEmotion = emotionResult.granularEmotion;

    // Layer 3 – Intent Classification
    final intentResult = await _intentSvc.classify(input.normalized);
    final intentEnum = intentResult.intent;

    // Layer 4 – Behavioral Analysis
    final behavior = await _behaviorSvc.analyze(stressLevel);

    // Layer 5 – Task Extraction
    int tasksExtracted = 0;
    if (intentEnum == IntentClass.taskAdd) {
      final extracted = _taskSvc.extract(
        input.normalized,
        currentStressLevel: stressLevel,
        history: history.map((m) => {'role': m.role, 'content': m.content}).toList(),
      );
      for (final t in extracted) {
        await _db.saveTask({
          'title': t.title,
          'deadline': t.deadline?.millisecondsSinceEpoch,
          'priority': t.priority,
          'status': 'pending',
          'extracted_from_chat': 1,
        });
      }
      tasksExtracted = extracted.length;
    } else if (intentEnum == IntentClass.taskUpdate) {
      final activeTasks = await _db.getActiveTasks();
      if (activeTasks.isNotEmpty) {
        final lastTask = activeTasks.last;
        final dline = _taskSvc.extractDeadline(input.normalized);
        
        // Update deadline if found
        if (dline != null) {
          await _db.updateTaskDeadline(lastTask['id'] as String, dline.millisecondsSinceEpoch);
        }
        
        // Update priority if mentioned
        if (input.normalized.toLowerCase().contains('priority')) {
           final p = _taskSvc.extractPriority(input.normalized, stressLevel);
           await _db.updateTaskPriority(lastTask['id'] as String, p);
        }

        // Mark as done
        if (input.normalized.toLowerCase().contains('done') || 
            input.normalized.toLowerCase().contains('finished')) {
          await _db.updateTaskStatus(lastTask['id'] as String, 'completed');
        }
        
        tasksExtracted = 1; // Trigger UI refresh
      }
    }

    // Layer 6 – CWS Score
    // Use live totalXP for growthScore (normalized 0-100 over first 500 XP)
    final totalXP = await _db.getTotalXP();
    final growthScore = (totalXP / 500 * 100).clamp(0.0, 100.0);

    final cwsResult = await _cwsSvc.computeAndSave(CWSInputs(
      emotionScore: _emotionSvc.toEmotionScore(emotionResult),
      stressLevel: stressLevel,
      taskScore: behavior.behaviorScore,
      activityScore: behavior.activityScore,
      routineScore: behavior.routineScore,
      behaviorScore: behavior.behaviorScore,
      growthScore: growthScore,
    ));

    // Layer 7 – Decision Engine → Response
    String? contextData;
    if (intentEnum == IntentClass.knowledgeQuery || intentEnum == IntentClass.planning) {
       final tasks = await _db.getActiveTasks();
       final wellbeing = await _db.getWellbeingHistory(3);
       
       final taskTitles = tasks.map((t) => t['title']).join(', ');
       final stressTrend = wellbeing.map((w) => w['stress_level'].toString()).join(', ');
       
       contextData = "Tasks pending: ${taskTitles.isEmpty ? 'none' : taskTitles}. "
                    "Stress level snapshot (last 3): ${stressTrend.isEmpty ? 'none' : stressTrend}.";
    }

    final decision = await _decisionSvc.decide(
      intent: intentEnum,
      userMessage: input.normalized,
      history: history,
      emotion: granularEmotion,
      stressLevel: stressLevel,
      contextData: contextData,
    );

    // Persist both turns to DB
    await _db.saveMessage(
      role: 'user',
      content: input.original,
      sessionId: _sessionId,
      stress: stressLevel,
      intent: intentEnum,
    );
    await _db.saveMessage(
      role: 'assistant',
      content: decision.response,
      sessionId: _sessionId,
    );

    // ── Post-pipeline side-effects ────────────────────────────────────
    // Fire stress alert if CWS drops to red zone
    await notificationService.sendStressAlert(cwsResult.smoothedCWS);

    // Check XP bonuses (stress reduction, weekly streak)
    await xpService.checkAndAwardStressReduction();
    await xpService.checkAndAwardWeeklyStreak();

    return PipelineResult(
      response: decision.response,
      emotionLabel: emotionLabel,
      stressLevel: stressLevel,
      intent: intentEnum,
      cwsScore: cwsResult.smoothedCWS,
      aiMode: decision.mode,
      tasksExtracted: tasksExtracted,
      sessionId: _sessionId,
    );
  }

  /// Layer 7+ – Proactive Logic: Synthesizes a context-aware greeting
  Future<String> generateGreeting() async {
    await ensureInitialized();
    
    // Check pending tasks and last wellbeing state
    final tasks = await _db.getActiveTasks();
    final history = await _db.getWellbeingHistory(1);
    final profile = await _db.getProfile();
    
    final name = profile?['display_name'] ?? 'there';
    String contextPrompt = "The student ($name) just opened the app.";
    
    if (tasks.isNotEmpty) {
      contextPrompt += " They have ${tasks.length} pending tasks.";
    }
    if (history.isNotEmpty) {
      final lastStress = history.first['stress_score'] as double;
      contextPrompt += " Their last recorded stress level was ${lastStress.toStringAsFixed(0)}/100.";
    }

    final greeting = await _decisionSvc.decide(
      intent: IntentClass.casual,
      userMessage: "[SYSTEM: Generate a 1-2 sentence warm, supportive greeting for the user. Mention tasks or previous stress if relevant. Context: $contextPrompt]",
      history: [],
      emotion: Emotion.neutral,
      stressLevel: history.isNotEmpty ? (history.first['stress_score'] as double) : 0.0,
    );

    return greeting.response;
  }
}

// Top-level singleton accessor
final responseEngineProvider = ResponseEngine();
