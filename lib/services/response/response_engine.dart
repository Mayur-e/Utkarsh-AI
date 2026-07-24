import '../auth/auth_service.dart';
import '../input/input_capture_service.dart';
import '../emotion/emotion_service.dart';
import '../intent/intent_service.dart';
import '../behavior/behavior_service.dart';
import '../tasks/task_extraction_service.dart';
import '../cws/cws_engine.dart';
import '../decision/decision_engine.dart';
import '../decision/groq_client.dart';
import '../../pipeline/layer9_response/llm_service.dart';
import '../storage/database_service.dart';
import '../growth/xp_service.dart';
import '../notifications/notification_service.dart';
import '../assessment/assessment_trigger_service.dart';
import '../assessment/assessment_data.dart';
import '../cloud/cloud_sync_service.dart';
import '../context/context_builder_service.dart';
import '../personalization/personalization_engine.dart';
import '../../models/intent.dart';
import '../../models/user_profile.dart';
import '../../models/task.dart';
import '../../models/emotion.dart';
import '../../state/app_state.dart';

/// Thrown when offline AI mode is set but the GGUF model file is not on-device.
class ModelNotLoadedException implements Exception {
  const ModelNotLoadedException();
  @override
  String toString() => 'ModelNotLoadedException: Offline model not downloaded.';
}

class PipelineResult {
  final String response;
  final Emotion emotionLabel;
  final double stressLevel;
  final IntentClass intent;
  final double cwsScore;
  final AiMode aiMode;
  final int tasksExtracted;
  final String sessionId;
  final String? insight; // Added industry-grade insight
  final bool shouldPromptAssessment;
  final AssessmentType? triggeredAssessment;

  PipelineResult({
    required this.response,
    required this.emotionLabel,
    required this.stressLevel,
    required this.intent,
    required this.cwsScore,
    required this.aiMode,
    required this.tasksExtracted,
    required this.sessionId,
    this.insight,
    this.shouldPromptAssessment = false,
    this.triggeredAssessment,
  });
}

class ResponseEngine {
  ResponseEngine._internal();
  static final ResponseEngine _instance = ResponseEngine._internal();
  factory ResponseEngine() => _instance;

  late final String _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
  String get sessionId => _sessionId;

  final InputCaptureService _inputSvc = inputCaptureServiceProvider;
  final EmotionService _emotionSvc = emotionServiceSingleton;
  final IntentService _intentSvc = intentServiceSingleton;
  final BehaviorService _behaviorSvc = behaviorServiceProvider;
  final TaskExtractionService _taskSvc = taskExtractionServiceProvider;
  final CWSEngine _cwsSvc = cwsEngineProvider;
  final DecisionEngine _decisionSvc = decisionEngineProvider;
  final DatabaseService _db = databaseServiceProvider;

  bool _initialized = false;
  UserProfile? _currentPlayer;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    await _db.initialize();
    await _emotionSvc.initialize();
    await _intentSvc.initialize();
    _initialized = true;
  }

  Future<UserProfile> getCurrentProfile() async {
    await ensureInitialized();
    final uid = AuthService.instance.currentUser?.id ?? 'local_user';
    final data = await _db.getProfile(uid);
    if (data != null) {
      _currentPlayer = UserProfile.fromMap(data);
    } else {
      _currentPlayer = UserProfile(id: uid, createdAt: DateTime.now().millisecondsSinceEpoch);
    }
    return _currentPlayer!;
  }

  Future<PipelineResult> process(
    String userText,
    List<GroqMessage> history, {
    required void Function(String token) onToken,
  }) async {
    await ensureInitialized();
    final input = _inputSvc.capture(userText);
    final emotionResult = await _emotionSvc.analyze(input.normalized);
    final emotionLabel = emotionResult.sentiment;
    final stressLevel = emotionResult.stressLevel;
    final granularEmotion = emotionResult.sentiment;
    final intentResult = await _intentSvc.classify(input.normalized);
    final intentEnum = intentResult.intent;
    final behavior = await _behaviorSvc.analyze(stressLevel);

    int tasksExtracted = 0;
    final uid = AuthService.instance.currentUser?.id;
    
    // Convert GroqMessage history to the format expected by task extractor
    final extractionHistory = history.map((m) => {
      'role': m.role,
      'content': m.content,
    }).toList();
    
    final extracted = await _taskSvc.smartExtract(input.normalized, history: extractionHistory);

    if (extracted.isNotEmpty) {
      for (final t in extracted) {
        await _db.saveTask(Task(
          id: DateTime.now().millisecondsSinceEpoch.toString() + tasksExtracted.toString(),
          userId: uid ?? 'local_user',
          title: t.title,
          deadline: t.deadline?.millisecondsSinceEpoch,
          priority: t.priority,
          status: TaskStatus.pending,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          extractedFromChat: true,
        ));
        tasksExtracted++;
      }
    } 

    // Handle updates specifically if intent is taskUpdate
    if (intentEnum == IntentClass.taskUpdate) {
      final activeTasks = await _db.getActiveTasks();
      if (activeTasks.isNotEmpty) {
        Task targetTask = activeTasks.last;
        
        // Try to match task title if mentioned
        for (final t in activeTasks) {
          if (input.normalized.toLowerCase().contains(t.title.toLowerCase())) {
            targetTask = t;
            break;
          }
        }

        final dline = _taskSvc.extractDeadline(input.normalized);
        if (dline != null) {
          await _db.updateTaskDeadline(targetTask.id, dline.millisecondsSinceEpoch);
        }
        if (input.normalized.toLowerCase().contains('priority')) {
           final p = _taskSvc.extractPriority(input.normalized, stressLevel);
           await _db.updateTaskPriority(targetTask.id, p);
        }
        if (input.normalized.toLowerCase().contains('done') || input.normalized.toLowerCase().contains('finished')) {
          await _db.updateTaskStatus(targetTask.id, 'completed');
        }
        tasksExtracted = 1;
      }
    }

    final totalXP = await _db.getTotalXP(uid);
    final growthScore = (totalXP / 500 * 100).clamp(0.0, 100.0);
    final cwsResult = await _cwsSvc.computeAndSave(CWSInputs(
      emotionScore: _emotionSvc.toScore(emotionResult),
      stressLevel: stressLevel,
      taskScore: behavior.behaviorScore,
      activityScore: behavior.activityScore,
      routineScore: behavior.routineScore,
      behaviorScore: behavior.behaviorScore,
      growthScore: growthScore,
    ), uid);

    final profile = await getCurrentProfile();
    final insight = await _cwsSvc.generateInsight(current: cwsResult, profile: profile, userId: uid);

    String? contextData;
    if (intentEnum == IntentClass.knowledgeQuery || intentEnum == IntentClass.planning) {
       final tasks = await _db.getActiveTasks(uid);
       final wellbeing = await _db.getWellbeingHistory(3, uid);
       final taskTitles = tasks.map((t) => t.title).join(', ');
       final stressTrend = wellbeing.map((w) => w['stress_score'].toString()).join(', ');
       contextData = "Tasks pending: ${taskTitles.isEmpty ? 'none' : taskTitles}. Stress Snapshot: $stressTrend.";
    }

    final capsule = await ContextBuilderService.instance.buildWeeklyCapsule(uid ?? 'local_user');
    final decision = await _decisionSvc.decide(
      intent: intentEnum,
      userMessage: input.normalized,
      history: history,
      emotion: granularEmotion,
      stressLevel: stressLevel,
      contextData: contextData,
      context: capsule,
      profile: profile,
    );

    String finalResponse;

    if (decision.modelNotLoaded) {
      // Offline mode chosen but model not downloaded — surface this to the UI
      throw const ModelNotLoadedException();
    } else if (decision.mode == AiMode.llm) {
      // Offline Path: On-device LLM
      final historyList = history.map((m) => ChatMessage(
        role: m.role == 'user' ? MessageRole.user : MessageRole.assistant,
        content: m.content,
      )).toList();

      final result = await LLMService.instance.generateStream(
        history:      historyList,
        systemPrompt: PersonalizationEngine.instance.buildSystemPrompt(profile),
        onToken:      onToken,
      );
      finalResponse = result.text;
    } else if (decision.mode == AiMode.groq) {
      // Online Path: Groq API
      finalResponse = decision.response;
      onToken(finalResponse);
    } else {
      // Template Path
      finalResponse = decision.response;
      
      // ────────────────────────────────────────────────────────────────────────
      // 🧠 DEMO MODE: "SMART" REAL OFFLINE AWARENESS
      // ────────────────────────────────────────────────────────────────────────
      final lowerText = input.normalized.toLowerCase();
      
      // If they ask about tasks, prepend their actual database tasks!
      if (lowerText.contains("task") || lowerText.contains("to do") || lowerText.contains("todo")) {
        final tasks = await _db.getActiveTasks(uid);
        if (tasks.isNotEmpty) {
           final titles = tasks.map((t) => "• ${t.title}").join("\n");
           finalResponse = "Here are your current pending tasks:\n$titles\n\n$finalResponse";
        } else {
           finalResponse = "You don't have any active tasks right now! $finalResponse";
        }
      }
      
      // If they ask about wellbeing/stress, prepend their actual database score!
      if (lowerText.contains("wellbeing") || lowerText.contains("stress") || lowerText.contains("score")) {
         final wellbeing = await _db.getWellbeingHistory(1, uid);
         if (wellbeing.isNotEmpty) {
            final score = (wellbeing.first['cws_score'] as num).toDouble();
            finalResponse = "I just checked your vitals. Your current Comprehensive Wellness Score is ${score.toStringAsFixed(0)}/100.\n\n$finalResponse";
         }
      }
      // ────────────────────────────────────────────────────────────────────────

      onToken(finalResponse);
    }

    await _db.saveMessage(role: 'user', content: input.original, sessionId: _sessionId, stress: stressLevel, intent: intentEnum, userId: uid);
    await _db.saveMessage(role: 'assistant', content: finalResponse, sessionId: _sessionId, userId: uid);

    await notificationService.sendStressAlert(cwsResult.smoothedCWS);
    await xpService.checkAndAwardStressReduction(uid);
    await xpService.checkAndAwardWeeklyStreak(uid);
    cloudSyncService.syncWellbeingHistory();
    final triggerAssessment = await AssessmentTriggerService.instance.checkTriggers();

    return PipelineResult(
      response: finalResponse,
      emotionLabel: emotionLabel,
      stressLevel: stressLevel,
      intent: intentEnum,
      cwsScore: cwsResult.smoothedCWS,
      aiMode: decision.mode,
      tasksExtracted: tasksExtracted,
      sessionId: _sessionId,
      insight: insight,
      shouldPromptAssessment: triggerAssessment != null,
      triggeredAssessment: triggerAssessment,
    );
  }

  Future<String> generateGreeting() async {
    await ensureInitialized();
    final profile = await getCurrentProfile();
    final name = profile.displayName ?? 'Mayuresh';
    
    // ────────────────────────────────────────────────────────────────────────
    // 🧠 DEMO MODE: INSTANT GREETING
    // ────────────────────────────────────────────────────────────────────────
    return "Hi $name! It's so good to see you again. I noticed you've been working hard lately. How are you feeling today? 💚";
  }
}

final responseEngineProvider = ResponseEngine();
