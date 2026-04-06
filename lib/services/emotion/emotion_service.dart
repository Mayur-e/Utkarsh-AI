import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/emotion.dart';
import '../../pipeline/layer9_response/llm_service.dart';

// ─── Result ───────────────────────────────────────────────────────────────────

class EmotionResult {
  final Emotion sentiment;
  final double stressLevel; // 0–100
  final double confidence;  // 0–1
  final bool isFallback;

  EmotionResult({
    required this.sentiment,
    required this.stressLevel,
    required this.confidence,
    this.isFallback = false,
  });
}

// ─── EmotionService ───────────────────────────────────────────────────────────

class EmotionService {
  OrtSession? _session;
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  static const String _assetPath = 'assets/models/emotion.onnx';

  // twitter-roberta-base-sentiment-latest output labels
  // Index: [negative=0, neutral=1, positive=2]
  static const List<String> _labels = ['negative', 'neutral', 'positive'];

  Future<void> initialize() async {
    try {
      OrtEnv.instance.init();
      final modelPath = await _extractModel();
      final opts = OrtSessionOptions();
      _session = OrtSession.fromFile(File(modelPath), opts);
      _isLoaded = true;
      debugPrint('[EmotionService] ONNX model loaded');
    } catch (e) {
      debugPrint('[EmotionService] ONNX init failed: $e — using fallback');
      _isLoaded = true;
    }
  }

  Future<String> _extractModel() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dest   = '${appDir.path}/models/emotion.onnx';
    final file   = File(dest);
    if (!await file.exists()) {
      final data = await rootBundle.load(_assetPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return dest;
  }

  // ── Main Entry Point ──────────────────────────────────────────────────────
  Future<EmotionResult> analyze(String text) async {
    if (_session != null) {
      try { return await _analyzeOnnx(text); } catch (e) {
        debugPrint('[EmotionService] ONNX error: $e');
      }
    }
    if (LLMService.instance.isReady) {
      try { return await _analyzeLLM(text); } catch (_) {}
    }
    return _analyzeFallback(text);
  }

  // ── ONNX Inference ────────────────────────────────────────────────────────
  Future<EmotionResult> _analyzeOnnx(String text) async {
    final tokens   = _tokenize(text);
    final inputIds = Int64List.fromList(tokens);
    final attnMask = Int64List.fromList(List.filled(tokens.length, 1));

    final t1 = OrtValueTensor.createTensorWithDataList(inputIds,  [1, tokens.length]);
    final t2 = OrtValueTensor.createTensorWithDataList(attnMask,  [1, tokens.length]);

    final runOpts = OrtRunOptions();
    final outputs = _session!.run(runOpts, {
      'input_ids':      t1,
      'attention_mask': t2,
    });
    runOpts.release();
    t1.release();
    t2.release();

    final logits = (outputs[0]?.value as List<List<double>>)[0];
    final probs  = _softmax(logits);
    for (final o in outputs) { o?.release(); }

    final maxIdx = probs.indexOf(probs.reduce(math.max));
    final label  = _labels[maxIdx];
    final conf   = probs[maxIdx];

    // Stress = negative prob × 80 + neutral × 20
    final stress = ((probs[0] * 80.0) + (probs[1] * 20.0)).clamp(0.0, 100.0);

    return EmotionResult(
      sentiment:   _toEmotion(label, stress),
      stressLevel: stress,
      confidence:  conf,
    );
  }

  Emotion _toEmotion(String label, double stress) {
    if (label == 'positive') return Emotion.happy;
    if (label == 'neutral')  return Emotion.neutral;
    if (stress > 75)         return Emotion.stressed;
    if (stress > 50)         return Emotion.anxious;
    return Emotion.sad;
  }

  // ── LLM Fallback ─────────────────────────────────────────────────────────
  Future<EmotionResult> _analyzeLLM(String text) async {
    final prompt = 'Analyze emotion in: "$text"\n'
        'JSON only: {"sentiment":"positive|negative|neutral","stressLevel":0-100}';
    final response = await LLMService.instance.generate(
      history:      [ChatMessage(role: MessageRole.user, content: prompt)],
      systemPrompt: 'Emotion classifier. Output JSON only.',
      timeout:      const Duration(seconds: 10),
    );
    return _parseLLMJson(response);
  }

  EmotionResult _parseLLMJson(String response) {
    try {
      final j  = response.substring(response.indexOf('{'), response.lastIndexOf('}') + 1);
      final s  = RegExp(r'"sentiment"\s*:\s*"(\w+)"').firstMatch(j)?.group(1) ?? 'neutral';
      final sl = double.tryParse(
        RegExp(r'"stressLevel"\s*:\s*(\d+)').firstMatch(j)?.group(1) ?? '30') ?? 30.0;
      return EmotionResult(
        sentiment:   _toEmotion(s, sl),
        stressLevel: sl.clamp(0.0, 100.0),
        confidence:  0.85,
      );
    } catch (_) {
      return _analyzeFallback('');
    }
  }

  // ── Keyword Fallback ──────────────────────────────────────────────────────
  EmotionResult _analyzeFallback(String text) {
    final lower = text.toLowerCase();
    const negWords = ['stressed','sad','anxious','worried','angry','fail','tired',
      'overwhelmed','hate','cry','alone','hurt','pain','scared','stuck',
      'depressed','hopeless','useless','burnout'];
    const posWords = ['happy','great','good','excited','love','awesome','proud',
      'excellent','amazing','motivated','confident','relieved'];

    final neg = negWords.where(lower.contains).length;
    final pos = posWords.where(lower.contains).length;

    if (neg > pos) {
      return EmotionResult(
        sentiment:   neg > 2 ? Emotion.stressed : Emotion.anxious,
        stressLevel: math.min(95.0, 40.0 + neg * 12.0),
        confidence:  0.55,
        isFallback:  true,
      );
    } else if (pos > neg) {
      return EmotionResult(
        sentiment:   Emotion.happy,
        stressLevel: math.max(5.0, 20.0 - pos * 5.0),
        confidence:  0.55,
        isFallback:  true,
      );
    }
    return EmotionResult(
      sentiment:   Emotion.neutral,
      stressLevel: 35.0,
      confidence:  0.45,
      isFallback:  true,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  List<int> _tokenize(String text) {
    const cls = 0, sep = 2, maxLen = 128;
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    final ids   = <int>[cls];
    for (final w in words.take(maxLen - 2)) {
      ids.add(3 + (w.hashCode.abs() % 50261));
    }
    ids.add(sep);
    return ids;
  }

  List<double> _softmax(List<double> logits) {
    final m    = logits.reduce(math.max);
    final exps = logits.map((l) => math.exp(l - m)).toList();
    final sum  = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }

  double toScore(EmotionResult r) {
    switch (r.sentiment) {
      case Emotion.happy:    return 90.0;
      case Emotion.neutral:  return 60.0;
      case Emotion.anxious:  return (100.0 - r.stressLevel).clamp(0, 50);
      case Emotion.stressed: return (100.0 - r.stressLevel).clamp(0, 40);
      case Emotion.sad:      return 25.0;
      case Emotion.angry:    return 20.0;
    }
  }

  void dispose() {
    _session?.release();
    _session = null;
  }
}

final emotionServiceSingleton = EmotionService();
