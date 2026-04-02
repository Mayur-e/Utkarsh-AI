import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:dart_bert_tokenizer/dart_bert_tokenizer.dart';
import '../../models/intent.dart';
import '../../core/utils/model_paths.dart';

class IntentResult {
  final IntentClass intent;
  final double confidence;
  final String source; // 'onnx' | 'fallback'

  IntentResult({
    required this.intent,
    required this.confidence,
    required this.source,
  });
}

class IntentService {
  OrtSession? _session;
  WordPieceTokenizer? _tokenizer;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  // Ordered patterns: earlier = higher priority for ties
  static final List<({List<String> keywords, IntentClass intent})> _patterns = [
    // Explicit task-management commands — checked FIRST
    (
      keywords: [
        'update', 'change', 'move', 'set', 'mark', 'its', 'that', 'deadline', 'priority', 'done',
      ],
      intent: IntentClass.taskUpdate,
    ),
    (
      keywords: [
        'add', 'save', 'note', 'remind', 'create', 'todo', 'to-do', 'list',
      ],
      intent: IntentClass.taskAdd,
    ),
    // Stress / emotional support
    (
      keywords: [
        'overwhelmed', 'stressed', 'i am stressed', 'feeling stressed',
        'anxious', 'can\'t cope', 'feeling down', 'burnout', 'exhausted',
        'depressed', 'scared', 'worried', 'hopeless', 'i am sad', 'i feel bad',
      ],
      intent: IntentClass.stressHelp,
    ),
    // Academic tasks mentioned in context
    (
      keywords: [
        'assignment', 'homework', 'submit', 'deadline', 'exam', 'test',
        'quiz', 'project', 'due', 'report', 'viva', 'i have to', 'i need to',
        'finish', 'complete', 'presentation', 'lab report', 'internship',
      ],
      intent: IntentClass.taskAdd,
    ),
    // Planning
    (
      keywords: [
        'plan', 'schedule', 'routine', 'organise', 'organize', 'timetable',
        'prioritize', 'help me plan', 'what should i do', 'how to manage',
        'check', 'show', 'list', 'my tasks', 'current tasks', 'pending',
      ],
      intent: IntentClass.planning,
    ),
    // Knowledge queries
    (
      keywords: [
        'what is', 'explain', 'how does', 'why is', 'define', 'tell me about',
        'what are', 'difference between', 'formula', 'concept', 'theory',
        'my progress', 'how am i', 'wellbeing status', 'task section',
        'due date', 'deadline', 'priority', 'status', 'when is it',
      ],
      intent: IntentClass.knowledgeQuery,
    ),
  ];

  Future<void> initialize() async {
    try {
      final modelPath = await getModelPath('intent_model.onnx');
      final vocabPath = await getModelPath('vocab.txt');

      _tokenizer = await WordPieceTokenizer.fromVocabFile(vocabPath);

      OrtEnv.instance.init();
      final sessionOptions = OrtSessionOptions();
      
      _session = OrtSession.fromFile(File(modelPath), sessionOptions);
      _isLoaded = true;
      debugPrint('[IntentService] Model and Tokenizer loaded successfully');
    } catch (e) {
      debugPrint('[IntentService] ONNX unavailable, using rule-based fallback: $e');
      _isLoaded = false;
    }
  }

  Future<IntentResult> classify(String text) async {
    if (!_isLoaded || _session == null || _tokenizer == null) {
      return _classifyFallback(text);
    }

    try {
      final encoding = _tokenizer!.encode(text);
      final inputIds = encoding.ids;
      final attentionMask = encoding.attentionMask;

      final shape = [1, inputIds.length];
      
      final inputIdsTensor = OrtValueTensor.createTensorWithDataList(inputIds, shape);
      final attentionMaskTensor = OrtValueTensor.createTensorWithDataList(attentionMask, shape);

      final inputs = {
        'input_ids': inputIdsTensor,
        'attention_mask': attentionMaskTensor,
      };

      final runOptions = OrtRunOptions();
      final outputs = _session!.run(runOptions, inputs);
      
      if (outputs.isEmpty || outputs[0] == null) {
        throw Exception('No outputs from intent model');
      }

      final logitsValue = outputs[0]!.value;
      List<double> logits;
      
      if (logitsValue is List<List<double>>) {
        logits = logitsValue[0];
      } else if (logitsValue is List<double>) {
        logits = logitsValue;
      } else if (logitsValue is List<List<num>>) {
         logits = logitsValue[0].map((e) => e.toDouble()).toList();
      } else {
        throw Exception('Unexpected logits type: ${logitsValue.runtimeType}');
      }

      inputIdsTensor.release();
      attentionMaskTensor.release();
      runOptions.release();
      for (var element in outputs) {
        element?.release();
      }

      final probs = _softmax(logits);
      final maxIdx = probs.indexOf(probs.reduce(math.max).toDouble());
      
      // Index to Intent mapping. Order: stressHelp, taskAdd, planning, knowledgeQuery, casual
      final intent = IntentClass.values[maxIdx % IntentClass.values.length];

      return IntentResult(
        intent: intent,
        confidence: probs[maxIdx],
        source: 'onnx',
      );
    } catch (e) {
      debugPrint('[IntentService] Inference failed: $e');
      return _classifyFallback(text);
    }
  }

  IntentResult _classifyFallback(String text) {
    final lower = text.toLowerCase();

    // Score every pattern, pick the one with the highest match count
    IntentClass bestIntent = IntentClass.casual;
    int bestScore = 0;
    double bestConfidence = 0.4;

    for (final pattern in _patterns) {
      int matchCount =
          pattern.keywords.where((k) => lower.contains(k)).length;
      
      // Boost taskUpdate if pronouns are present
      if (pattern.intent == IntentClass.taskUpdate && 
          (lower.contains('it') || lower.contains('its') || lower.contains('that') || lower.contains('this'))) {
        matchCount += 2;
      }
      
      if (matchCount > bestScore) {
        bestScore = matchCount;
        bestIntent = pattern.intent;
        bestConfidence =
            math.min(0.5 + matchCount * 0.15, 0.95).toDouble();
      }
    }

    return IntentResult(
      intent: bestIntent,
      confidence: bestConfidence,
      source: 'fallback',
    );
  }

  List<double> _softmax(List<double> logits) {
    if (logits.isEmpty) return [];
    final maxLogit = logits.reduce(math.max).toDouble();
    final exps = logits.map((e) => math.exp(e.toDouble() - maxLogit)).toList();
    final sumExps = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sumExps).toList();
  }

  void dispose() {
    _session?.release();
  }
}

// Riverpod provider (for widgets)
final intentServiceProvider = Provider((ref) => IntentService());

// Plain singleton for service-layer use (ResponseEngine etc.)
final intentServiceSingleton = IntentService();
