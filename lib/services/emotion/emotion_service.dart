import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../pipeline/layer9_response/llm_service.dart';
import '../../state/app_state.dart';

import '../../models/emotion.dart';

class EmotionResult {
  final EmotionLabel sentiment;
  final double stressLevel;
  final double confidence;
  final bool isFallback;
  final List<double>? probabilities;

  EmotionResult({
    required this.sentiment,
    required this.stressLevel,
    required this.confidence,
    this.isFallback = false,
    this.probabilities,
  });

  Emotion get granularEmotion {
    if (sentiment == EmotionLabel.positive) return Emotion.happy;
    if (sentiment == EmotionLabel.neutral) return Emotion.neutral;
    if (stressLevel > 80) return Emotion.stressed;
    if (stressLevel > 50) return Emotion.anxious;
    return Emotion.sad;
  }
}

class EmotionService {
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  Future<void> initialize() async {
    _isLoaded = true; // LLMService is the source of truth now
    debugPrint('[EmotionService] High-fidelity analysis unified via LLMService');
  }

  Future<EmotionResult> analyze(String text) async {
    if (!LLMService.instance.isReady) {
      return _analyzeFallback(text);
    }

    try {
      final prompt = '''
Analyze the emotional state in this student's message: "$text"
Provide the analysis in JSON format exactly like this:
{
  "sentiment": "positive" | "negative" | "neutral",
  "stressLevel": 0-100,
  "reasoning": "short explanation"
}
''';

      final response = await LLMService.instance.generate(
        history: [ChatMessage(role: MessageRole.user, content: prompt)],
        systemPrompt: "You are Utkarsh AI's emotional intelligence unit. You provide precise, JSON-only sentiment and stress level assessments for students.",
        timeout: const Duration(seconds: 10),
      );

      // Simple JSON extraction
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) throw Exception('Invalid JSON response');
      
      final jsonStr = response.substring(jsonStart, jsonEnd + 1);
      final Map<String, dynamic> data = _parseJson(jsonStr);

      final sentimentStr = data['sentiment']?.toString().toLowerCase() ?? 'neutral';
      final stressVal = (data['stressLevel'] as num?)?.toDouble() ?? 30.0;

      EmotionLabel sentiment;
      if (sentimentStr == 'positive') {
        sentiment = EmotionLabel.positive;
      } else if (sentimentStr == 'negative') {
        sentiment = EmotionLabel.negative;
      } else {
        sentiment = EmotionLabel.neutral;
      }

      return EmotionResult(
        sentiment: sentiment,
        stressLevel: stressVal,
        confidence: 0.95, // LLM is higher confidence than small ONNX
        probabilities: [],
      );
    } catch (e) {
      debugPrint('[EmotionService] LLM analysis failed: $e');
      return _analyzeFallback(text);
    }
  }

  Map<String, dynamic> _parseJson(String jsonStr) {
    return json.decode(jsonStr);
  }

  EmotionResult _analyzeFallback(String text) {
    final lower = text.toLowerCase();
    
    final negKeywords = [
      'stressed', 'sad', 'anxious', 'worried', 'angry', 'fail', 'bad', 'tired', 
      'overwhelmed', 'hate', 'cry', 'alone', 'hurt', 'pain', 'scared', 'beat', 
      'laughing on', 'trouble', 'stuck', 'mess', 'worst'
    ];
    final posKeywords = ['happy', 'great', 'good', 'excited', 'love', 'awesome', 'proud', 'excellent', 'amazing'];
    final negators = ['not', 'no', 'never', 'don\'t', 'doesn\'t', 'won\'t'];

    int negCount = negKeywords.where((k) => lower.contains(k)).length;
    int posCount = posKeywords.where((k) => lower.contains(k)).length;

    // Handle negations (e.g. "not feeling good" should be negative)
    for (final neg in negators) {
      for (final pos in posKeywords) {
        if (lower.contains('$neg $pos') || lower.contains('$neg feeling $pos')) {
          negCount += 2; // Stronger signal for negative polarity
          posCount -= 1;
        }
      }
    }

    if (negCount > posCount) {
      return EmotionResult(
        sentiment: EmotionLabel.negative,
        stressLevel: math.min(95.0, 40.0 + negCount * 10.0).toDouble(),
        confidence: 0.65,
        isFallback: true,
      );
    } else if (posCount > negCount) {
       return EmotionResult(
        sentiment: EmotionLabel.positive,
        stressLevel: math.max(5.0, 20.0 - posCount * 5.0).toDouble(),
        confidence: 0.65,
        isFallback: true,
      );
    }

    return EmotionResult(
      sentiment: EmotionLabel.neutral,
      stressLevel: 35.0,
      confidence: 0.55,
      isFallback: true,
    );
  }

  double toEmotionScore(EmotionResult result) {
    if (result.sentiment == EmotionLabel.positive) return 90.0;
    if (result.sentiment == EmotionLabel.neutral) return 60.0;
    return (100.0 - result.stressLevel).clamp(0.0, 50.0);
  }

  void dispose() {
    // Nothing to release
  }
}

// Riverpod provider (for widgets)
final emotionServiceProvider = Provider((ref) => EmotionService());

// Plain singleton for service-layer use (ResponseEngine etc.)
final emotionServiceSingleton = EmotionService();
