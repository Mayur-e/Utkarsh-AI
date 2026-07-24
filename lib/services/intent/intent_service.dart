import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/intent.dart';
import '../../pipeline/layer9_response/llm_service.dart';

// ─── Result ───────────────────────────────────────────────────────────────────

class IntentResult {
  final IntentClass intent;
  final double confidence;
  final String source; // 'onnx' | 'llm' | 'rule'

  IntentResult({
    required this.intent,
    required this.confidence,
    required this.source,
  });
}

// ─── IntentService ────────────────────────────────────────────────────────────

class IntentService {
  OrtSession? _session;
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;
  bool? _supportsTokenTypeIds;

  static const String _assetPath = 'assets/models/intent.onnx';

  // Zero-shot NLI hypothesis templates per intent
  static const Map<IntentClass, String> _hypotheses = {
    IntentClass.taskAdd:       'This text is about adding or creating a new task or reminder',
    IntentClass.taskUpdate:    'This text is about updating, completing, or changing a task',
    IntentClass.stressHelp:    'This text is about stress, anxiety, or needing emotional support',
    IntentClass.planning:      'This text is about planning, scheduling, or organizing time',
    IntentClass.knowledgeQuery:'This text is asking a question or wanting to learn something',
    IntentClass.casual:        'This text is casual conversation or small talk',
  };

  // Quick keyword rules for high-confidence obvious matches
  static final List<({List<String> words, IntentClass intent})> _rules = [
    (words: ['update','change','move','done','finish','complete','mark as','set deadline'],
     intent: IntentClass.taskUpdate),
    (words: ['add task','add a task','remind me','save this','note this','create task','to-do'],
     intent: IntentClass.taskAdd),
    (words: ['stressed','anxious','overwhelmed','burnout','not okay','not feeling well','help me','breaking down'],
     intent: IntentClass.stressHelp),
    (words: ['plan','schedule','routine','timetable','organize my','prioritize'],
     intent: IntentClass.planning),
    (words: ['what is','explain','how does','definition','tell me about','what are'],
     intent: IntentClass.knowledgeQuery),
  ];

  Future<void> initialize() async {
    try {
      OrtEnv.instance.init();
      final modelPath = await _extractModel();
      final opts = OrtSessionOptions();
      _session = OrtSession.fromFile(File(modelPath), opts);
      _isLoaded = true;
      debugPrint('[IntentService] ONNX model loaded');
    } catch (e) {
      debugPrint('[IntentService] ONNX init failed: $e — using fallback');
      _isLoaded = true;
    }
  }

  Future<String> _extractModel() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dest   = '${appDir.path}/models/intent.onnx';
    final file   = File(dest);
    if (!await file.exists()) {
      final data = await rootBundle.load(_assetPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return dest;
  }

  // ── Main Classification ───────────────────────────────────────────────────
  Future<IntentResult> classify(String text) async {
    // 1. Rule-based pre-filter for obvious matches
    final rule = _classifyRule(text);
    if (rule.confidence >= 0.80) return rule;

    // 2. NLI zero-shot ONNX
    if (_session != null) {
      try { return await _classifyOnnx(text); } catch (e) {
        debugPrint('[IntentService] ONNX error: $e');
      }
    }

    // 3. LLM fallback
    if (LLMService.instance.isReady) {
      try { return await _classifyLLM(text); } catch (_) {}
    }

    return rule;
  }

  // ── ONNX Zero-Shot NLI ────────────────────────────────────────────────────
  Future<IntentResult> _classifyOnnx(String text) async {
    final scores = <IntentClass, double>{};

    // Default to false for RoBERTa-style models unless proven otherwise.
    _supportsTokenTypeIds ??= false;
    for (final entry in _hypotheses.entries) {
      final premise    = _tokenize(text);
      final hypothesis = _tokenize(entry.value);

      // [CLS] premise [SEP] hypothesis [SEP]
      final combined  = [0, ...premise, 2, ...hypothesis, 2];
      final typeIds   = [
        ...List.filled(premise.length + 2, 0),
        ...List.filled(hypothesis.length + 1, 1),
      ];

      final inputIds  = Int64List.fromList(combined);
      final attnMask  = Int64List.fromList(List.filled(combined.length, 1));
      final tokenType = Int64List.fromList(typeIds);

      final t1 = OrtValueTensor.createTensorWithDataList(inputIds,  [1, combined.length]);
      final t2 = OrtValueTensor.createTensorWithDataList(attnMask,  [1, combined.length]);
      final t3 = OrtValueTensor.createTensorWithDataList(tokenType, [1, combined.length]);

      final runOpts = OrtRunOptions();
      List<OrtValue?> outputs;
      try {
        // Some ONNX models don't accept token_type_ids (e.g., RoBERTa).
        if (_supportsTokenTypeIds == false) {
          outputs = _session!.run(runOpts, {
            'input_ids':      t1,
            'attention_mask': t2,
          });
        } else {
          outputs = _session!.run(runOpts, {
            'input_ids':      t1,
            'attention_mask': t2,
            'token_type_ids': t3,
          });
        }
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('token_type_ids')) {
          _supportsTokenTypeIds = false;
          outputs = _session!.run(runOpts, {
            'input_ids':      t1,
            'attention_mask': t2,
          });
        } else {
          rethrow;
        }
      }
      runOpts.release();
      t1.release(); t2.release(); t3.release();

      final logits = (outputs[0]?.value as List<List<double>>)[0];
      final probs  = _softmax(logits);
      // NLI logits: [contradiction=0, neutral=1, entailment=2]
      scores[entry.key] = probs.length >= 3 ? probs[2] : probs[0];
      for (final o in outputs) { o?.release(); }
    }

    final best = scores.entries.reduce((a, b) => a.value > b.value ? a : b);
    return IntentResult(intent: best.key, confidence: best.value, source: 'onnx');
  }

  // ── LLM Fallback ─────────────────────────────────────────────────────────
  Future<IntentResult> _classifyLLM(String text) async {
    final classes  = IntentClass.values.map((e) => e.name).join(', ');
    final prompt   = 'Classify intent of: "$text"\nOptions: $classes\n'
        'JSON only: {"intent":"...","confidence":0.0-1.0}';
    final response = await LLMService.instance.generate(
      history:      [ChatMessage(role: MessageRole.user, content: prompt)],
      systemPrompt: 'Intent classifier. Output JSON only.',
      timeout:      const Duration(seconds: 10),
    );
    try {
      final j    = response.substring(response.indexOf('{'), response.lastIndexOf('}') + 1);
      final iStr = RegExp(r'"intent"\s*:\s*"(\w+)"').firstMatch(j)?.group(1) ?? 'casual';
      final conf = double.tryParse(
        RegExp(r'"confidence"\s*:\s*([\d.]+)').firstMatch(j)?.group(1) ?? '0.8') ?? 0.8;
      final intent = IntentClass.values.firstWhere(
        (e) => e.name == iStr, orElse: () => IntentClass.casual);
      return IntentResult(intent: intent, confidence: conf, source: 'llm');
    } catch (_) {
      return IntentResult(intent: IntentClass.casual, confidence: 0.4, source: 'llm');
    }
  }

  // ── Rule-based ────────────────────────────────────────────────────────────
  IntentResult _classifyRule(String text) {
    final lower = text.toLowerCase();
    IntentClass best  = IntentClass.casual;
    int         score = 0;
    double      conf  = 0.30;

    for (final r in _rules) {
      final hits = r.words.where(lower.contains).length;
      if (hits > score) {
        score = hits;
        best  = r.intent;
        conf  = math.min(0.50 + hits * 0.15, 0.92);
      }
    }
    return IntentResult(intent: best, confidence: conf, source: 'rule');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  List<int> _tokenize(String text) {
    const maxLen = 64;
    return text.toLowerCase().split(RegExp(r'\s+')).take(maxLen)
        .map((w) => 3 + (w.hashCode.abs() % 30519))
        .toList();
  }

  List<double> _softmax(List<double> logits) {
    final m    = logits.reduce(math.max);
    final exps = logits.map((l) => math.exp(l - m)).toList();
    final sum  = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }

  void dispose() {
    _session?.release();
    _session = null;
  }
}

final intentServiceSingleton = IntentService();
