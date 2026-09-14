import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'groq_client.dart';
import '../../pipeline/layer9_response/llm_service.dart';
import '../../models/intent.dart';
import '../../models/emotion.dart';
import '../../models/context_capsule.dart';
import '../../models/user_profile.dart';

import '../../state/app_state.dart';

class DecisionResult {
  final AiMode mode;
  final String response;
  final String? error;

  /// True when the offline model is needed but not downloaded yet.
  final bool modelNotLoaded;

  DecisionResult({
    required this.mode,
    required this.response,
    this.error,
    this.modelNotLoaded = false,
  });
}

class DecisionEngine {
  final GroqClient _groqClient = groqClientProvider;
  final Connectivity _connectivity = Connectivity();
  static const String _logTag = '[OfflineAI]';

  // ─── Fallback templates (last-resort only — online/offline both failed) ────

  static const Map<IntentClass, Map<String, List<String>>> _offlineTemplates = {
    IntentClass.stressHelp: {
      'negative': [
        "That sounds really tough. You're not alone in feeling this way — one step at a time. 💚",
        "It's okay to feel this way. Take a deep breath. I'm right here with you. 🌿",
      ],
      'neutral': [
        "I'm here whenever you need to talk. What's on your mind?",
        "I'm listening. How can I support you right now? 🍵",
      ],
      'positive': [
        "It's great that you're checking in! Keep it up 🌱",
        "Love the positive energy! Let's keep moving forward! ✨",
      ],
    },
    IntentClass.taskAdd: {
      'negative': [
        "Got it — I've noted that task for you 📝. When things feel heavy, small steps are best.",
        "Task added. Don't worry about doing everything at once. Focus on one small piece. ✅",
      ],
      'neutral': [
        "Task noted! ✅ Check the Tasks tab to see it. Shall we prioritize it?",
        "Done! I've added that to your list. What's next? 🎯",
      ],
      'positive': [
        "Added! 🎯 You're staying organized — great job!",
        "Task saved! Recording these small wins is how you make real progress. 🚀",
      ],
    },
    IntentClass.planning: {
      'negative': [
        "Let's take it slow. Your current tasks are: {{TASKS}}. Focus on just one today. 🐢",
        "Your list: {{TASKS}}. Which one feels most manageable right now? 🍵",
      ],
      'neutral': [
        "I've got your list: {{TASKS}}. How would you like to plan your time? 📅",
        "Planning mode! 🎯 Your current focus: {{TASKS}}. Let's break one down.",
      ],
      'positive': [
        "Great mindset! You have {{TASKS}} on your plate. Let's make it a productive day! 🚀",
        "You're working on: {{TASKS}}. Ready to set a goal? 🎯",
      ],
    },
    IntentClass.knowledgeQuery: {
      'negative': [
        "Looking at your data: {{WELLBEING_SUMMARY}}. Let's focus on relaxation first. 🌿",
        "Your wellbeing trends show: {{WELLBEING_SUMMARY}}. Take it easy today. 🍵",
      ],
      'neutral': [
        "Here's your snapshot: {{TASKS}}. You're making progress! ✅",
        "I can see your progress: {{WELLBEING_SUMMARY}}. What would you like to talk about?",
      ],
      'positive': [
        "Here's your local status: {{WELLBEING_SUMMARY}}. Great progress! 🎯",
        "Here's what I can see: {{WELLBEING_SUMMARY}}. 🚀",
      ],
    },
    IntentClass.taskUpdate: {
      'negative': [
        "I've updated that task for you! Let me know if you need to adjust anything else. 📅",
        "Modifications saved! Take it one step at a time. ✅",
      ],
      'neutral': [
        "Updated! I've noted the new details in your task section. 📝",
        "Got it! That task has been successfully modified. 🎯",
      ],
      'positive': [
        "Great adjustment! I've saved those task updates for you. 🚀",
        "All set! Your task list is up-to-date. ✅",
      ],
    },
    IntentClass.casual: {
      'negative': [
        "I'm always here for you 💚 How are you holding up?",
        "It's okay to have down days. I'm Utkarsh, your ally. Talk to me? 🌿",
      ],
      'neutral': [
        "Hi! I'm Utkarsh — your wellbeing companion. What's on your mind today?",
        "Hello! 👋 I'm here to listen. How can I support you today?",
      ],
      'positive': [
        "That's wonderful! 🌿 Keep that positive energy going!",
        "I'm so glad to hear that! What else is happening in your day? ✨",
      ],
    },
  };

  String _mapEmotionToKey(Emotion emotion) {
    switch (emotion) {
      case Emotion.happy:
        return 'positive';
      case Emotion.neutral:
        return 'neutral';
      case Emotion.sad:
      case Emotion.anxious:
      case Emotion.stressed:
      case Emotion.angry:
        return 'negative';
    }
  }

  Future<DecisionResult> decide({
    required IntentClass intent,
    required String userMessage,
    required List<GroqMessage> history,
    required Emotion emotion,
    required double stressLevel,
    String? contextData,
    ContextCapsule? context,
    UserProfile? profile,
  }) async {

    // Refresh disk presence each decision to avoid stale model status.
    await LLMService.instance.checkDiskPresence();

    final bool onlineEnabled  = profile?.onlineAiEnabled ?? true;
    final bool offlineEnabled = profile?.offlineLlmEnabled ?? true;
    final bool hasLocalModel  = LLMService.instance.isDownloaded;
    final bool llmInMemory    = LLMService.instance.isReady;
    final bool llmDisabled    = LLMService.instance.isDisabled;
    print(
      '$_logTag Decision: onlineEnabled=$onlineEnabled '
      'offlineEnabled=$offlineEnabled hasLocalModel=$hasLocalModel '
      'llmInMemory=$llmInMemory llmDisabled=$llmDisabled intent=${intent.name}',
    );

    // Whether the on-device LLM is actually usable right now.
    final bool llmUsable = hasLocalModel && offlineEnabled && !llmDisabled;

    // ── PATH A: User explicitly wants offline AI ────────────────────────────
    if (!onlineEnabled) {
      if (llmUsable) {
        print('$_logTag Route selected: offline-llm (forced by settings)');
        return DecisionResult(mode: AiMode.llm, response: 'LLM_PLACEHOLDER');
      }
      // Model not ready or incompatible — show download/incompatible prompt.
      print('$_logTag Route selected: offline-required-but-model-not-ready (disabled=$llmDisabled)');
      return DecisionResult(
        mode: AiMode.offline,
        response: '__MODEL_NOT_LOADED__',
        modelNotLoaded: true,
      );
    }

    // ── PATH B: Online mode — try Groq first, fall back to LLM if available ─
    final List<ConnectivityResult> conn = await _connectivity.checkConnectivity();
    final bool isOnline = conn.isNotEmpty && !conn.contains(ConnectivityResult.none);

    if (isOnline) {
      try {
        final List<GroqMessage> messages = [
          ...history.skip(history.length > 8 ? history.length - 8 : 0),
          GroqMessage(role: 'user', content: userMessage),
        ];

        String extraContext = '';
        if (stressLevel > 50.0) {
          extraContext +=
              'User appears ${emotion.name} with stress level ${stressLevel.toStringAsFixed(0)}/100. '
              'Respond with empathy first.';
        }
        if (contextData != null) {
          extraContext += '\nContext: $contextData';
        }

        // Knowledge queries always go to Groq when online.
        if (intent == IntentClass.knowledgeQuery) {
          print('$_logTag Route selected: groq-cloud (knowledge_query)');
          final response = await _groqClient.sendMessage(
            messages,
            context:      context,
            profile:      profile,
            extraContext: extraContext.isEmpty ? null : extraContext,
          );
          return DecisionResult(mode: AiMode.groq, response: response.content);
        }

        // Prefer on-device LLM if ready AND not disabled/incompatible.
        if (llmUsable) {
          print('$_logTag Route selected: offline-llm (preferred while online)');
          return DecisionResult(mode: AiMode.llm, response: 'LLM_PLACEHOLDER');
        }

        // Offline unavailable — use Groq for all intents.
        print('$_logTag Route selected: groq-cloud (offline disabled/incompatible)');
        final response = await _groqClient.sendMessage(
          messages,
          context:      context,
          profile:      profile,
          extraContext: extraContext.isEmpty ? null : extraContext,
        );
        return DecisionResult(mode: AiMode.groq, response: response.content);
      } catch (e) {
        // Groq failed — fall back to local LLM if compatible.
        print('$_logTag Groq failure: $e');
        if (llmUsable) {
          print('$_logTag Route selected: offline-llm (after groq failure)');
          return DecisionResult(mode: AiMode.llm, response: 'LLM_PLACEHOLDER');
        }
        // No working AI — use template as last resort.
        print('$_logTag Route selected: template-fallback (after groq failure)');
        return _templateFallback(intent, emotion, contextData,
            error: 'Cloud AI temporarily unavailable.');
      }
    }

    // ── PATH C: Online preferred but no internet ────────────────────────────
    if (llmUsable) {
      print('$_logTag Route selected: offline-llm (no internet)');
      return DecisionResult(mode: AiMode.llm, response: 'LLM_PLACEHOLDER');
    }

    // ── LAST RESORT: template ───────────────────────────────────────────────
    print('$_logTag Route selected: template-fallback (offline no model or disabled)');
    return _templateFallback(intent, emotion, contextData);
  }

  DecisionResult _templateFallback(
    IntentClass intent,
    Emotion emotion,
    String? contextData, {
    String? error,
  }) {
    final emotionKey = _mapEmotionToKey(emotion);
    final templates = _offlineTemplates[intent]?[emotionKey] ??
        _offlineTemplates[intent]?['neutral'] ??
        ["I'm here for you. Tell me more."];

    String response = templates[Random().nextInt(templates.length)];

    if (contextData != null) {
      final parts   = contextData.split('. ');
      final tasks   = parts.isNotEmpty ? parts[0].replaceAll('Tasks pending: ', '') : 'none';
      final wbeing  = parts.length > 1
          ? parts[1].replaceAll('Stress level snapshot (last 3): ', '')
          : 'none';
      response = response
          .replaceAll('{{TASKS}}',           tasks == 'none' ? 'your list' : tasks)
          .replaceAll('{{WELLBEING_SUMMARY}}', wbeing == 'none' ? 'your recent progress' : 'stress at $wbeing');
    } else {
      response = response
          .replaceAll('{{TASKS}}', 'your tasks')
          .replaceAll('{{WELLBEING_SUMMARY}}', 'your daily progress');
    }

    return DecisionResult(mode: AiMode.offline, response: response, error: error);
  }
}

final decisionEngineProvider = DecisionEngine();
