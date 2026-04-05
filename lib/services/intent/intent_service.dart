import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/intent.dart';
import '../../pipeline/layer9_response/llm_service.dart';

class IntentResult {
  final IntentClass intent;
  final double confidence;
  final String source; // 'llm' | 'fallback'

  IntentResult({
    required this.intent,
    required this.confidence,
    required this.source,
  });
}

class IntentService {
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  // Rule-based keywords for quick checks or fallback
  static final List<({List<String> keywords, IntentClass intent})> _patterns = [
    (
      keywords: ['update', 'change', 'move', 'set', 'mark', 'its', 'that', 'deadline', 'priority', 'done'],
      intent: IntentClass.taskUpdate,
    ),
    (
      keywords: ['add', 'save', 'note', 'remind', 'create', 'todo', 'to-do', 'list', 'tasks'],
      intent: IntentClass.taskAdd,
    ),
    (
      keywords: ['overwhelmed', 'stressed', 'anxious', 'burnout', 'exhausted', 'sad', 'scared', 'angry', 'beat', 'fight', 'shouting', 'crying', 'broken', 'not good', 'help me', 'not feeling', 'what should i'],
      intent: IntentClass.stressHelp,
    ),
    (
      keywords: ['plan', 'schedule', 'routine', 'timetable', 'prioritize', 'organize'],
      intent: IntentClass.planning,
    ),
    (
      keywords: ['what is', 'explain', 'how does', 'definition', 'formula', 'concept'],
      intent: IntentClass.knowledgeQuery,
    ),
  ];

  Future<void> initialize() async {
    _isLoaded = true;
    debugPrint('[IntentService] Unified intelligence initialized via LLMService');
  }

  Future<IntentResult> classify(String text) async {
    if (!LLMService.instance.isReady) {
      return _classifyFallback(text);
    }

    try {
      final prompt = '''
Classify the intent of this student's message: "$text"
Options: taskAdd, taskUpdate, stressHelp, planning, knowledgeQuery, casual

Response must be JSON:
{
  "intent": "...",
  "confidence": 0.0-1.0
}
''';

      final response = await LLMService.instance.generate(
        history: [ChatMessage(role: MessageRole.user, content: prompt)],
        systemPrompt: "You are the intent classification unit of Utkarsh AI. You precisely categorize student requests into predefined classes.",
        timeout: const Duration(seconds: 10),
      );

      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) throw Exception('Invalid JSON');
      
      final Map<String, dynamic> data = json.decode(response.substring(jsonStart, jsonEnd + 1));
      final String intentStr = data['intent'] ?? 'casual';
      final double conf = (data['confidence'] as num?)?.toDouble() ?? 0.9;

      IntentClass intent = IntentClass.values.firstWhere(
        (e) => e.name == intentStr,
        orElse: () => IntentClass.casual,
      );

      return IntentResult(
        intent: intent,
        confidence: conf,
        source: 'llm',
      );
    } catch (e) {
      debugPrint('[IntentService] LLM classification failed: $e');
      return _classifyFallback(text);
    }
  }

  IntentResult _classifyFallback(String text) {
    final lower = text.toLowerCase();
    IntentClass bestIntent = IntentClass.casual;
    int bestScore = 0;
    double bestConfidence = 0.4;

    for (final pattern in _patterns) {
      int matchCount = pattern.keywords.where((k) => lower.contains(k)).length;
      if (matchCount > bestScore) {
        bestScore = matchCount;
        bestIntent = pattern.intent;
        bestConfidence = math.min(0.5 + matchCount * 0.1, 0.9).toDouble();
      }
    }

    return IntentResult(
      intent: bestIntent,
      confidence: bestConfidence,
      source: 'fallback',
    );
  }

  void dispose() {}
}

final intentServiceProvider = Provider((ref) => IntentService());
final intentServiceSingleton = IntentService();
