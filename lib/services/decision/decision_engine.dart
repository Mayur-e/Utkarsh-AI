import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'groq_client.dart';
import '../../models/intent.dart';
import '../../models/emotion.dart';

enum AIMode { groq, offlineTemplate }

class DecisionResult {
  final AIMode mode;
  final String response;
  final String? error;

  DecisionResult({required this.mode, required this.response, this.error});
}

class DecisionEngine {
  final GroqClient _groqClient = groqClientProvider;
  final Connectivity _connectivity = Connectivity();
  
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
        "Added! 🎯 You're staying organized and on top of it. Great job!",
        "Task saved! Recording these small wins is how you make real progress. 🚀",
      ],
    },
    IntentClass.planning: {
      'negative': [
        "Let's take it slow. Your current tasks are: {{TASKS}}. Focus on just one today. 🐢",
        "Checking your list: {{TASKS}}. Which one feels most manageable right now? 🍵",
      ],
      'neutral': [
        "I've got your list: {{TASKS}}. How would you like to plan your time? 📅",
        "Planning mode! 🎯 Your current focus is: {{TASKS}}. Let's break one down.",
      ],
      'positive': [
        "Great mindset! You have {{TASKS}} on your plate. Let's make it a productive day! 🚀",
        "Let's keep the momentum! You're working on: {{TASKS}}. Ready to set a goal? 🎯",
      ],
    },
    IntentClass.knowledgeQuery: {
      'negative': [
        "I need internet for deep analysis, but looking at your data: {{WELLBEING_SUMMARY}}. Let's focus on relaxation first. 🌿",
        "Offline right now, but your wellbeing trends show: {{WELLBEING_SUMMARY}}. Take it easy today. 🍵",
      ],
      'neutral': [
        "Deep knowledge requires internet, but here's your snapshot: {{TASKS}}. You're making progress! ✅",
        "I can't reach the full web, but I can see your progress: {{WELLBEING_SUMMARY}}. What would you like to talk about?",
      ],
      'positive': [
        "Smart question! While I'm offline, I see you're on track with: {{TASKS}}. Connect and I'll explain more! 🎯",
        "Great curiosity! Here's your local status: {{WELLBEING_SUMMARY}}. I can give you a better answer once we're online! 🚀",
      ],
    },
    IntentClass.taskUpdate: {
      'negative': [
        "I've updated that task for you! Let me know if you need to adjust anything else. 📅",
        "Modifications saved! Take it one step at a time. ✅",
      ],
      'neutral': [
        "Updated! I've noted the new details in your task section. 📝",
        "Got it! That task has been successfully modified locally. 🎯",
      ],
      'positive': [
        "Great adjustment! I've saved those task updates for you. 🚀",
        "All set! Your task list is up-to-date with your new changes. ✅",
      ],
    },
    IntentClass.casual: {
      'negative': [
        "I'm always here for you 💚 How are you holding up?",
        "It's okay to have down days. I'm Utkarsh, your friend. Talk to me? 🌿",
      ],
      'neutral': [
        "Hi! I'm Utkarsh — your wellbeing companion. What's on your mind today?",
        "Hello! 👋 Hope your day is going smoothly. How can I help you today?",
      ],
      'positive': [
        "That's wonderful to hear! 🌿 Keep that energy going!",
        "Seeing you happy makes my circuits light up! ✨ What's the best part of your day?",
      ],
    },
  };

  static const String utkarshSystemPrompt = """
You are Utkarsh, a warm and empathetic AI companion for students.
Guidelines:
- Acknowledge feelings before offering solutions
- Keep responses concise (2–4 sentences)
- When the student mentions tasks, note them supportively
- Never diagnose. For serious concerns, suggest professional support
- Always respond in the same language the student uses""";

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
  }) async {
    
    final List<ConnectivityResult> connectivityResults = await _connectivity.checkConnectivity();
    final bool isOnline = connectivityResults.isNotEmpty && 
                          !connectivityResults.contains(ConnectivityResult.none);

    final bool shouldUseGroq = isOnline && (
      intent == IntentClass.knowledgeQuery ||
      intent == IntentClass.planning ||
      stressLevel < 80.0
    );

    if (shouldUseGroq) {
      try {
        final List<GroqMessage> messages = [
          ...history.take(6),
          GroqMessage(role: 'user', content: userMessage),
        ];

        String dynamicPrompt = utkarshSystemPrompt;
        if (stressLevel > 60.0) {
          dynamicPrompt += "\n[Context: User appears ${emotion.name} with stress level ${stressLevel.toStringAsFixed(0)}/100. Lead with empathy.]";
        }
        if (contextData != null) {
          dynamicPrompt += "\n[Current Student Data: $contextData]";
        }

        final response = await _groqClient.sendMessage(messages, systemPrompt: dynamicPrompt);
        return DecisionResult(mode: AIMode.groq, response: response.content);
        
      } catch (e) {
        // Fallback to offline on API error
      }
    }

    // Offline Template response with dynamic variety and data-injection
    final emotionKey = _mapEmotionToKey(emotion);
    final templates = _offlineTemplates[intent]?[emotionKey] ?? 
                     _offlineTemplates[intent]?['neutral'] ??
                     ["I'm here for you. Tell more more."];
    
    String response = templates[Random().nextInt(templates.length)];

    // Inject data if available
    if (contextData != null) {
      final parts = contextData.split('. ');
      final tasks = parts.isNotEmpty ? parts[0].replaceAll('Tasks pending: ', '') : 'none';
      final wellbeing = parts.length > 1 ? parts[1].replaceAll('Stress level snapshot (last 3): ', '') : 'none';
      
      response = response.replaceAll('{{TASKS}}', tasks == 'none' ? 'your list' : tasks);
      response = response.replaceAll('{{WELLBEING_SUMMARY}}', wellbeing == 'none' ? 'your recent progress' : "stress levels at $wellbeing");
    } else {
      response = response.replaceAll('{{TASKS}}', 'your tasks');
      response = response.replaceAll('{{WELLBEING_SUMMARY}}', 'your daily progress');
    }

    return DecisionResult(mode: AIMode.offlineTemplate, response: response);
  }
}

final decisionEngineProvider = DecisionEngine();
