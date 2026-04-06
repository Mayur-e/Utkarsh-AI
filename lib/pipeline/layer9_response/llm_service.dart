import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path_provider/path_provider.dart';

// ─── Data Classes ─────────────────────────────────────────────────────────────

enum MessageRole { user, assistant, system }

class ChatMessage {
  final dynamic role; // MessageRole or String
  final String content;

  ChatMessage({required this.role, required this.content});

  String get roleStr =>
      role is MessageRole ? (role as MessageRole).name : role.toString();

  Map<String, String> toMap() => {'role': roleStr, 'content': content};
}

class LLMResponse {
  final String text;
  final int tokensGenerated;
  final bool timedOut;

  LLMResponse(this.text, {this.tokensGenerated = 0, this.timedOut = false});
}

// ─── LLMService ───────────────────────────────────────────────────────────────

class LLMService {
  LLMService._();
  static final LLMService instance = LLMService._();

  Llama? _llama;
  bool _hasModel = false; // true only when _llama is loaded in memory

  /// True only when the GGUF model is actually loaded in memory.
  bool get isReady => _hasModel && _llama != null;

  // ── Model Config (tuned for EmoSApp / mental-health fine-tune) ────────────
  static const int    _maxTokens    = 512;
  static const int    _contextSize  = 2048;
  static const int    _threads      = 4;
  static const int    _maxHistory   = 10; // turns
  static const double _temperature  = 0.72;
  static const double _topP         = 0.9;
  static const double _repeatPenalty = 1.1;

  // ── Initialize ────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_hasModel) return; // model already in memory

    final modelPath = await _resolveModelPath();
    if (modelPath == null) {
      debugPrint('[LLMService] No GGUF model found — falling back to cloud AI');
      return;
    }

    try {
      debugPrint('[LLMService] Loading: ${modelPath.split('/').last}');

      final modelParams   = ModelParams();
      final contextParams = ContextParams()
        ..nCtx     = _contextSize
        ..nThreads = _threads
        ..nBatch   = 512
        ..nPredict = _maxTokens;

      final samplerParams = SamplerParams()
        ..temp         = _temperature
        ..topP         = _topP
        ..penaltyRepeat = _repeatPenalty;

      _llama = Llama(
        modelPath,
        modelParams:   modelParams,
        contextParams: contextParams,
        samplerParams: samplerParams,
      );

      _hasModel = true;
      debugPrint('[LLMService] ✅ Ready: ${modelPath.split('/').last}');
    } catch (e) {
      debugPrint('[LLMService] Load failed: $e');
      _hasModel = false;
    }
  }

  Future<void> ensureReady() async => await initialize();

  /// Call this after downloading the model to load it without restarting the app.
  Future<void> reinitialize() async {
    _hasModel = false;
    _llama?.dispose();
    _llama = null;
    await initialize();
  }

  // ── Model Path Resolution ─────────────────────────────────────────────────
  Future<String?> _resolveModelPath() async {
    final appDir = await getApplicationDocumentsDirectory();

    // Priority: full model > tiny fallback
    final candidates = [
      '${appDir.path}/models/utkarsh_llm.gguf',
      '${appDir.path}/models/utkarsh_llm_tiny.gguf',
    ];

    for (final path in candidates) {
      if (await File(path).exists()) {
        debugPrint('[LLMService] Found cached model: $path');
        return path;
      }
    }

    // Extract from Flutter assets
    return await _extractFromAssets(appDir.path);
  }

  Future<String?> _extractFromAssets(String appDirPath) async {
    final dir = Directory('$appDirPath/models');
    await dir.create(recursive: true);

    final assetCandidates = [
      ('assets/models/utkarsh_llm.gguf',      '$appDirPath/models/utkarsh_llm.gguf'),
      ('assets/models/utkarsh_llm_tiny.gguf', '$appDirPath/models/utkarsh_llm_tiny.gguf'),
    ];

    for (final (src, dst) in assetCandidates) {
      try {
        debugPrint('[LLMService] Extracting $src...');
        final data  = await rootBundle.load(src);
        final bytes = data.buffer.asUint8List();
        await File(dst).writeAsBytes(bytes, flush: true);
        debugPrint('[LLMService] Extracted ${(bytes.length / 1e6).toStringAsFixed(0)} MB');
        return dst;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  // ── Prompt Formatting — LLaMA 3.2 Instruct (MANDATORY FORMAT) ─────────────
  String _buildPrompt(List<ChatMessage> history, String systemPrompt) {
    final buf = StringBuffer();
    buf.write('<|begin_of_text|>');
    buf.write('<|start_header_id|>system<|end_header_id|>\n');
    buf.write(systemPrompt);
    buf.write('<|eot_id|>\n');

    // Keep last N turns to fit context
    final turns = history.length > _maxHistory * 2
        ? history.sublist(history.length - _maxHistory * 2)
        : history;

    for (final msg in turns) {
      buf.write('<|start_header_id|>${msg.roleStr}<|end_header_id|>\n');
      buf.write(msg.content);
      buf.write('<|eot_id|>\n');
    }
    buf.write('<|start_header_id|>assistant<|end_header_id|>\n');
    return buf.toString();
  }

  // ── Streaming Generation ──────────────────────────────────────────────────
  Future<LLMResponse> generateStream({
    required List<ChatMessage> history,
    required String systemPrompt,
    void Function(String token)? onToken,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    await ensureReady();

    if (_llama == null) {
      const msg = '[Offline — cloud AI required]';
      onToken?.call(msg);
      return LLMResponse(msg);
    }

    final prompt   = _buildPrompt(history, systemPrompt);
    final buf      = StringBuffer();
    int   count    = 0;
    bool  timedOut = false;
    final deadline = DateTime.now().add(timeout);

    try {
      _llama!.setPrompt(prompt);

      while (count < _maxTokens) {
        if (DateTime.now().isAfter(deadline)) {
          timedOut = true;
          break;
        }
        final (token, isDone) = _llama!.getNext();
        if (isDone) break;
        buf.write(token);
        onToken?.call(token);
        count++;
      }
    } catch (e) {
      debugPrint('[LLMService] Generation error: $e');
      const err = 'I had trouble responding. Please try again.';
      onToken?.call(err);
      return LLMResponse(err);
    }

    return LLMResponse(
      buf.toString().trim(),
      tokensGenerated: count,
      timedOut: timedOut,
    );
  }

  // ── Simple generate (emotion/intent JSON calls) ───────────────────────────
  Future<String> generate({
    required List<ChatMessage> history,
    required String systemPrompt,
    void Function(String)? onToken,
    Duration? timeout,
  }) async {
    final result = await generateStream(
      history:      history,
      systemPrompt: systemPrompt,
      onToken:      onToken,
      timeout:      timeout ?? const Duration(seconds: 15),
    );
    return result.text;
  }

  void dispose() {
    _llama?.dispose();
    _llama    = null;
    _hasModel = false;
  }
}
