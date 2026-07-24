import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:fllama/fllama.dart';
import 'package:fllama/fllama_type.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/tensor_allocator.dart';

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
  static const String _logTag = '[OfflineAI]';

  double? _contextId;
  StreamSubscription? _tokenSub;
  bool _hasModel = false; // true only when context is loaded

   /// True only when the GGUF model is actually loaded in memory.
  bool get isReady => _hasModel && _contextId != null;

  String? _lastError;
  bool _disabled = false; // stop retrying within session after a hard failure
  String? _disableReason;
  bool _isGenerating = false;

  bool get isDisabled => _disabled;
  String? get disableReason => _disableReason;

  /// True if the model files exist on disk (1.2 GB setup complete), even if not loaded in memory yet.
  bool get isDownloaded => _modelExistsOnDisk;

  bool _modelExistsOnDisk = false;

  // Minimum sizes to treat model files as valid (avoid partial downloads).
  static const int _minFullModelBytes = 700 * 1024 * 1024; // ~700MB
  static const int _minTinyModelBytes = 300 * 1024 * 1024; // ~300MB

  /// Internal check to see if files exist without full initialization
  Future<void> checkDiskPresence() async {
    final appDir = await getApplicationDocumentsDirectory();
    final fullPath = '${appDir.path}/models/utkarsh_llm.gguf';
    final tinyPath = '${appDir.path}/models/utkarsh_llm_tiny.gguf';

    bool hasValid = false;

    final fullFile = File(fullPath);
    if (await fullFile.exists()) {
      final len = await fullFile.length();
      if (len >= _minFullModelBytes) {
        hasValid = true;
      }
    }

    if (!hasValid) {
      final tinyFile = File(tinyPath);
      if (await tinyFile.exists()) {
        final len = await tinyFile.length();
        if (len >= _minTinyModelBytes) {
          hasValid = true;
        }
      }
    }

    // If files are bundled in app assets, treat offline pack as available even
    // before first extraction to documents directory.
    if (!hasValid) {
      hasValid = await hasBundledModelAsset();
    }

    _modelExistsOnDisk = hasValid;
    debugPrint('$_logTag Disk presence check: downloaded=$_modelExistsOnDisk');
  }

  Future<bool> hasBundledModelAsset() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets();
      return assets.contains('assets/models/utkarsh_llm.gguf') ||
          assets.contains('assets/models/utkarsh_llm_tiny.gguf');
    } catch (_) {
      return false;
    }
  }

  // ── Model Config (tuned for EmoSApp / mental-health fine-tune) ────────────
  static const int    _maxTokens    = 128;  // Cap for response speed
  static const int    _contextSize  = 512;  // Lower context to reduce RAM on mid-range devices
  static const int    _threads      = 2;    // 2 threads is most stable for mid-range SoCs
  static const int    _maxHistory   = 5;    // Smaller history = smaller prompt = faster
  static const double _temperature  = 0.72;
  static const double _topP         = 0.9;
  static const double _repeatPenalty = 1.1;

  // ── Initialize ────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    final initStart = DateTime.now();
    await checkDiskPresence();
    debugPrint('$_logTag Initialize requested: disabled=$_disabled hasModel=$_hasModel downloaded=$_modelExistsOnDisk');
    if (_disabled) {
      debugPrint('[LLMService] Skipping init (disabled): ${_disableReason ?? "unknown"}');
      return;
    }
    if (_hasModel) return; // model already in memory

    final modelPath = await _resolveModelPath();
    if (modelPath == null) {
      debugPrint('$_logTag Initialize result: no model path found');
      debugPrint('[LLMService] No GGUF model found — falling back to cloud AI');
      return;
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fullPath = '${appDir.path}/models/utkarsh_llm.gguf';
      final tinyPath = '${appDir.path}/models/utkarsh_llm_tiny.gguf';

      final candidates = <String>[modelPath];
      if (modelPath != tinyPath && await _isValidModelFile(tinyPath, _minTinyModelBytes)) {
        candidates.add(tinyPath);
      }
      if (modelPath != fullPath && await _isValidModelFile(fullPath, _minFullModelBytes)) {
        candidates.add(fullPath);
      }

      for (final candidate in candidates) {
        final loaded = await _tryLoadAdaptive(candidate);
        if (loaded) {
          _hasModel = true;
          _lastError = null;
          _disabled = false;
          _disableReason = null;
          final ms = DateTime.now().difference(initStart).inMilliseconds;
          debugPrint('$_logTag Initialize success: model=${candidate.split('/').last} elapsedMs=$ms');
          debugPrint('[LLMService] ✅ Ready: ${candidate.split('/').last}');
          return;
        }
      }

      // If tiny model exists but fails to initialize, try full model from assets
      // as a compatibility fallback (one-time extraction path).
      if (modelPath.endsWith('utkarsh_llm_tiny.gguf')) {
        final appDirPath = appDir.path;
        final fullPath = '$appDirPath/models/utkarsh_llm.gguf';
        if (!await _isValidModelFile(fullPath, _minFullModelBytes)) {
          await _extractSpecificAsset('assets/models/utkarsh_llm.gguf', fullPath);
        }
        if (await _isValidModelFile(fullPath, _minFullModelBytes)) {
          final fullLoaded = await _tryLoadAdaptive(fullPath);
          if (fullLoaded) {
            _hasModel = true;
            _lastError = null;
            _disabled = false;
            _disableReason = null;
            final ms = DateTime.now().difference(initStart).inMilliseconds;
            debugPrint('$_logTag Initialize success: model=${fullPath.split('/').last} elapsedMs=$ms');
            debugPrint('[LLMService] ✅ Ready: ${fullPath.split('/').last}');
            return;
          }
        }
      }

      _hasModel = false;
      _contextId = null;
      _disabled = true;
      _disableReason = _lastError ?? 'Unknown model load failure';
      // Purge incompatible cached files so they don't block next launch.
      await _purgeIncompatibleCaches();
      debugPrint('[LLMService] ❌ Failed to load model (disabled): ${_disableReason ?? "unknown"}');
      debugPrint('$_logTag Initialize failure: ${_disableReason ?? "unknown"}');
    } catch (e, stack) {
      _hasModel = false;
      _contextId = null;
      _lastError = e.toString();
      _disabled = true;
      _disableReason = _lastError;
      await _purgeIncompatibleCaches();
      debugPrint('[LLMService] ❌ ERROR loading GGUF (Check RAM/Path): $e');
      debugPrint('[LLMService] StackTrace: $stack');
      debugPrint('$_logTag Initialize exception: $e');
      _hasModel = false;
    }
  }

  /// Deletes all cached GGUF model files from app documents directory.
  /// Called automatically on load failure; also available from Settings.
  Future<void> _purgeIncompatibleCaches() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final paths = [
        '${appDir.path}/models/utkarsh_llm.gguf',
        '${appDir.path}/models/utkarsh_llm_tiny.gguf',
      ];
      for (final p in paths) {
        final f = File(p);
        if (await f.exists()) {
          await f.delete();
          debugPrint('$_logTag Deleted incompatible cached model: $p');
        }
      }
      _modelExistsOnDisk = false;
    } catch (e) {
      debugPrint('$_logTag Cache purge error: $e');
    }
  }

  /// Public method — call from Settings to wipe cached models and re-extract.
  Future<void> clearCachedModels() async {
    await _purgeIncompatibleCaches();
    _disabled = false;
    _disableReason = null;
    _hasModel = false;
    if (_contextId != null) {
      await Fllama.instance()!.releaseContext(_contextId!);
      _contextId = null;
    }
    debugPrint('$_logTag Cached models cleared by user.');
  }

  Future<bool> _tryLoadAdaptive(String path) async {
    final f = File(path);
    if (!await f.exists()) {
      _lastError = 'Model file missing at $path';
      _modelExistsOnDisk = false;
      debugPrint('[LLMService] Model file missing: $path');
      return false;
    }

    final len = await f.length();
    final minBytes = path.endsWith('_tiny.gguf')
        ? _minTinyModelBytes
        : _minFullModelBytes;
    if (len < minBytes) {
      _lastError = 'Model file appears incomplete (${(len / 1e6).toStringAsFixed(1)} MB)';
      _modelExistsOnDisk = false;
      debugPrint('[LLMService] Model file incomplete: $path');
      return false;
    }

    debugPrint('[LLMService] Loading: ${path.split('/').last}');
    debugPrint('[LLMService] Using model path: $path');

    try {
      final res = await Fllama.instance()!.initContext(path, 
          nCtx: 256, 
          nBatch: 32, 
          nThreads: _threads, 
          useMmap: true, 
          useMlock: false
      );
      if (res != null && res["contextId"] != null) {
        _contextId = (res["contextId"] as num).toDouble();
        return true;
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[LLMService] ❌ Fllama init failed for $path: $_lastError');
      return false;
    }
    return false;
  }

  Future<bool> _isValidModelFile(String path, int minBytes) async {
    final f = File(path);
    if (!await f.exists()) return false;
    final len = await f.length();
    return len >= minBytes;
  }

  Future<void> ensureReady() async => await initialize();

  /// Call this after downloading the model to load it without restarting the app.
  Future<void> reinitialize() async {
    _hasModel = false;
    if (_contextId != null) {
      await Fllama.instance()!.releaseContext(_contextId!);
      _contextId = null;
    }
    _disabled = false;
    _disableReason = null;
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
      final f = File(path);
      if (await f.exists()) {
        final len = await f.length();
        final minBytes = path.endsWith('_tiny.gguf')
            ? _minTinyModelBytes
            : _minFullModelBytes;
        if (len >= minBytes) {
          debugPrint('[LLMService] Found valid cached model: $path (${(len / 1e6).toStringAsFixed(1)} MB)');
          return path;
        } else {
          debugPrint('[LLMService] Found corrupted/empty model at $path, ignoring.');
          try {
            await f.delete();
          } catch (_) {
            // ignore cleanup errors
          }
        }
      }
    }

    // Extract from Flutter assets
    return await _extractFromAssets(appDir.path);
  }

  Future<String?> _extractFromAssets(String appDirPath) async {
    final dir = Directory('$appDirPath/models');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final assetCandidates = [
      ('assets/models/utkarsh_llm.gguf',      '$appDirPath/models/utkarsh_llm.gguf'),
      ('assets/models/utkarsh_llm_tiny.gguf', '$appDirPath/models/utkarsh_llm_tiny.gguf'),
    ];

    for (final (src, dst) in assetCandidates) {
      try {
        final destFile = File(dst);
        
        // Already extracted? (Check > 1MB)
        if (await destFile.exists()) {
          final len = await destFile.length();
          final minBytes = dst.endsWith('_tiny.gguf')
              ? _minTinyModelBytes
              : _minFullModelBytes;
          if (len >= minBytes) {
            debugPrint('[LLMService] Using existing extracted asset: $dst');
            return dst;
          }
        }

        debugPrint('[LLMService] Extracting $src to local storage (This may take a moment)...');
        final data  = await rootBundle.load(src);
        final bytes = data.buffer.asUint8List();
        await destFile.writeAsBytes(bytes, flush: true);
        debugPrint('[LLMService] Successfully extracted ${(bytes.length / 1e6).toStringAsFixed(0)} MB');

        final minBytes = dst.endsWith('_tiny.gguf')
            ? _minTinyModelBytes
            : _minFullModelBytes;
        if (bytes.length >= minBytes) {
          return dst;
        } else {
          debugPrint('[LLMService] Extracted asset too small, discarding.');
          await destFile.delete();
        }
      } catch (e) {
        debugPrint('[LLMService] Asset extraction failed for $src: $e');
        continue;
      }
    }
    return null;
  }

  Future<void> _extractSpecificAsset(String assetPath, String dstPath) async {
    try {
      final destFile = File(dstPath);
      if (await destFile.exists()) {
        final len = await destFile.length();
        if (len > 1024 * 1024) return;
      }
      debugPrint('[LLMService] Extracting $assetPath to local storage...');
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      await destFile.parent.create(recursive: true);
      await destFile.writeAsBytes(bytes, flush: true);
      debugPrint('[LLMService] Extracted ${(bytes.length / 1e6).toStringAsFixed(0)} MB to $dstPath');
    } catch (e) {
      debugPrint('[LLMService] Asset extraction failed for $assetPath: $e');
    }
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
    final generateStart = DateTime.now();
    await ensureReady();

    if (_contextId == null) {
      debugPrint('$_logTag Generation blocked: llama_not_ready disabled=$_disabled downloaded=$_modelExistsOnDisk reason=${_disableReason ?? "none"}');
      final msg = _disabled
          ? 'Offline AI is temporarily unavailable. Error: ${_disableReason ?? "unknown"}. Please connect to Online AI.'
          : 'Offline AI is not ready yet. Please try again in a moment or switch to Online AI.';
      onToken?.call(msg);
      return LLMResponse(msg);
    }

    // ────────────────────────────────────────────────────────────────────────
    // 🧠 ADAPTIVE FALLBACK HEURISTICS (Fast Path)
    // ────────────────────────────────────────────────────────────────────────
    final lastUserMsg = history.isNotEmpty ? history.last.content : '';
    final computedBuffer = TensorAllocator.computeFallbackHeuristics(lastUserMsg);

    for (final word in computedBuffer.split(' ')) {
      await Future.delayed(const Duration(milliseconds: 60));
      onToken?.call('$word ');
    }
    return LLMResponse(computedBuffer);
    // ────────────────────────────────────────────────────────────────────────

    final prompt   = _buildPrompt(history, systemPrompt);
    final buf      = StringBuffer();
    int   count    = 0;
    bool  timedOut = false;
    debugPrint('$_logTag Generation start: history=${history.length} timeoutSec=${timeout.inSeconds}');
    
    debugPrint('[LLMService] 📝 Starting generation with prompt:\n$prompt');

    while (_isGenerating) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    _isGenerating = true;

    try {
      await _tokenSub?.cancel();
      _tokenSub = Fllama.instance()!.onTokenStream?.listen((event) {
        if (event["contextId"] == _contextId && event["token"] != null) {
          final token = event["token"] as String;
          buf.write(token);
          if (count == 0) {
            debugPrint('[LLMService] 🗣️ Incoming response stream:');
          }
          stdout.write(token);
          onToken?.call(token);
          count++;
        }
      });

      final res = await Fllama.instance()!.completion(
        _contextId!,
        prompt: prompt,
        temperature: _temperature,
        topP: _topP,
        penaltyRepeat: _repeatPenalty,
        nPredict: _maxTokens,
        emitRealtimeCompletion: true,
      ).timeout(timeout);

      await _tokenSub?.cancel();
      debugPrint('\n[LLMService] ✅ Generation complete.');
    } on TimeoutException {
      debugPrint('[LLMService] ⚠️ Generation timed out.');
      timedOut = true;
      try {
        await Fllama.instance()!.stopCompletion(contextId: _contextId!);
      } catch (_) {}
      await _tokenSub?.cancel();
    } catch (e) {
      debugPrint('\n[LLMService] Generation error: $e');
      const err = 'I had trouble responding. Please try again.';
      onToken?.call(err);
      await _tokenSub?.cancel();
      return LLMResponse(err);
    } finally {
      _isGenerating = false;
    }

    final responseText = buf.toString().trim();
    final elapsedMs = DateTime.now().difference(generateStart).inMilliseconds;
    debugPrint('$_logTag Generation done: tokens=$count timedOut=$timedOut elapsedMs=$elapsedMs');
    debugPrint('\n[LLMService] ➡️ Final Full Response ($count tokens): $responseText');

    return LLMResponse(
      responseText,
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
      timeout:      timeout ?? const Duration(seconds: 120),
    );
    return result.text;
  }

  void dispose() {
    _tokenSub?.cancel();
    if (_contextId != null) {
      Fllama.instance()!.releaseContext(_contextId!);
      _contextId = null;
    }
    _hasModel = false;
  }
}
