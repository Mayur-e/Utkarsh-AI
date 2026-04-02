import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:dart_bert_tokenizer/dart_bert_tokenizer.dart';
import '../../core/utils/model_paths.dart';
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
  OrtSession? _session;
  WordPieceTokenizer? _tokenizer;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  Future<void> initialize() async {
    try {
      // 1. Get model paths
      final modelPath = await getModelPath('emotion_model.onnx');
      final vocabPath = await getModelPath('vocab.txt');

      // 2. Initialize Tokenizer
      _tokenizer = await WordPieceTokenizer.fromVocabFile(vocabPath);

      // 3. Initialize ONNX Runtime
      OrtEnv.instance.init();
      final sessionOptions = OrtSessionOptions();
      
      _session = OrtSession.fromFile(File(modelPath), sessionOptions);
      _isLoaded = true;
      debugPrint('[EmotionService] Model and Tokenizer loaded successfully');
    } catch (e) {
      debugPrint('[EmotionService] Initialization failed: $e');
      _isLoaded = false;
    }
  }

  Future<EmotionResult> analyze(String text) async {
    if (!_isLoaded || _session == null || _tokenizer == null) {
      return _analyzeFallback(text);
    }

    try {
      // 1. Tokenize
      final encoding = _tokenizer!.encode(text);
      final inputIds = encoding.ids;
      final attentionMask = encoding.attentionMask;

      // 2. Prepare inputs
      final shape = [1, inputIds.length];
      
      final inputIdsTensor = OrtValueTensor.createTensorWithDataList(inputIds, shape);
      final attentionMaskTensor = OrtValueTensor.createTensorWithDataList(attentionMask, shape);

      final inputs = {
        'input_ids': inputIdsTensor,
        'attention_mask': attentionMaskTensor,
      };

      // 3. Run inference
      final runOptions = OrtRunOptions();
      final outputs = _session!.run(runOptions, inputs);
      
      // 4. Process Output
      if (outputs.isEmpty || outputs[0] == null) {
        throw Exception('No outputs from model');
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

      // 5. Cleanup
      inputIdsTensor.release();
      attentionMaskTensor.release();
      runOptions.release();
      for (var element in outputs) {
        element?.release();
      }

      // 6. Softmax and Map (7-class DistilBert)
      final probs = _softmax(logits);
      
      // 0:sadness, 1:joy, 2:love, 3:anger, 4:fear, 5:surprise, 6:neutral
      final negProb = probs[0] + (probs.length > 3 ? probs[3] : 0.0) + (probs.length > 4 ? probs[4] : 0.0);
      final posProb = (probs.length > 1 ? probs[1] : 0.0) + (probs.length > 2 ? probs[2] : 0.0) + (probs.length > 5 ? probs[5] : 0.0);
      final neuProb = probs.length > 6 ? probs[6] : 0.1;

      final maxProb = [negProb, posProb, neuProb].reduce(math.max).toDouble();
      
      EmotionLabel sentiment;
      if (maxProb == negProb) {
        sentiment = EmotionLabel.negative;
      } else if (maxProb == posProb) {
        sentiment = EmotionLabel.positive;
      } else {
        sentiment = EmotionLabel.neutral;
      }

      return EmotionResult(
        sentiment: sentiment,
        stressLevel: negProb * 100.0,
        confidence: maxProb,
        probabilities: probs,
      );
    } catch (e) {
      debugPrint('[EmotionService] Inference failed: $e');
      return _analyzeFallback(text);
    }
  }

  EmotionResult _analyzeFallback(String text) {
    final lower = text.toLowerCase();
    
    final negKeywords = ['stressed', 'sad', 'anxious', 'worried', 'angry', 'fail', 'bad', 'tired', 'overwhelmed'];
    final posKeywords = ['happy', 'great', 'good', 'excited', 'love', 'awesome', 'proud'];

    int negCount = negKeywords.where((k) => lower.contains(k)).length;
    int posCount = posKeywords.where((k) => lower.contains(k)).length;

    if (negCount > posCount) {
      return EmotionResult(
        sentiment: EmotionLabel.negative,
        stressLevel: math.min(95.0, 30.0 + negCount * 15.0).toDouble(),
        confidence: 0.6,
        isFallback: true,
      );
    } else if (posCount > negCount) {
       return EmotionResult(
        sentiment: EmotionLabel.positive,
        stressLevel: math.max(5.0, 20.0 - posCount * 5.0).toDouble(),
        confidence: 0.6,
        isFallback: true,
      );
    }

    return EmotionResult(
      sentiment: EmotionLabel.neutral,
      stressLevel: 30.0,
      confidence: 0.5,
      isFallback: true,
    );
  }

  List<double> _softmax(List<double> logits) {
    if (logits.isEmpty) return [];
    final maxLogit = logits.reduce(math.max).toDouble();
    final exps = logits.map((e) => math.exp(e.toDouble() - maxLogit)).toList();
    final sumExps = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sumExps).toList();
  }

  double toEmotionScore(EmotionResult result) {
    if (result.sentiment == EmotionLabel.positive) return 90.0;
    if (result.sentiment == EmotionLabel.neutral) return 60.0;
    return (100.0 - result.stressLevel).clamp(0.0, 50.0);
  }

  void dispose() {
    _session?.release();
  }
}

// Riverpod provider (for widgets)
final emotionServiceProvider = Provider((ref) => EmotionService());

// Plain singleton for service-layer use (ResponseEngine etc.)
final emotionServiceSingleton = EmotionService();
