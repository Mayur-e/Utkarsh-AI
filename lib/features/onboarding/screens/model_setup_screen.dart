import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_theme.dart';

class _AssetSpec {
  final String key;
  final String assetPath;
  final String destination;
  final int minBytes;
  final bool required;

  const _AssetSpec({
    required this.key,
    required this.assetPath,
    required this.destination,
    required this.minBytes,
    this.required = true,
  });
}

const List<_AssetSpec> _kCoreAssets = [
  _AssetSpec(
    key: 'llm_full',
    assetPath: 'assets/models/utkarsh_llm.gguf',
    destination: 'utkarsh_llm.gguf',
    minBytes: 700 * 1024 * 1024,
    required: false,
  ),
  _AssetSpec(
    key: 'llm_tiny',
    assetPath: 'assets/models/utkarsh_llm_tiny.gguf',
    destination: 'utkarsh_llm_tiny.gguf',
    minBytes: 300 * 1024 * 1024,
    required: false,
  ),
  _AssetSpec(
    key: 'burnout',
    assetPath: 'assets/models/burnout.onnx',
    destination: 'burnout.onnx',
    minBytes: 1024 * 1024,
  ),
  _AssetSpec(
    key: 'emotion',
    assetPath: 'assets/models/emotion.onnx',
    destination: 'emotion.onnx',
    minBytes: 1024 * 1024,
  ),
  _AssetSpec(
    key: 'intent',
    assetPath: 'assets/models/intent.onnx',
    destination: 'intent.onnx',
    minBytes: 1024 * 1024,
  ),
  _AssetSpec(
    key: 'whisper_encoder',
    assetPath: 'assets/models/whisper/base-encoder.int8.onnx',
    destination: 'whisper/base-encoder.int8.onnx',
    minBytes: 1024 * 1024,
  ),
  _AssetSpec(
    key: 'whisper_decoder',
    assetPath: 'assets/models/whisper/base-decoder.int8.onnx',
    destination: 'whisper/base-decoder.int8.onnx',
    minBytes: 1024 * 1024,
  ),
  _AssetSpec(
    key: 'whisper_tokens',
    assetPath: 'assets/models/whisper/base-tokens.txt',
    destination: 'whisper/base-tokens.txt',
    minBytes: 1024,
  ),
];

class ModelSetupScreen extends StatefulWidget {
  final VoidCallback onDone;
  final bool fromSettings;

  const ModelSetupScreen({super.key, required this.onDone, this.fromSettings = false});

  @override
  State<ModelSetupScreen> createState() => _ModelSetupScreenState();
}

class _ModelSetupScreenState extends State<ModelSetupScreen> {
  int _completed = 0;
  int _total = 1;
  String _status = 'Checking bundled AI components...';
  bool _working = false;
  bool _allDone = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkReady();
  }

  Future<void> _checkReady() async {
    final specs = await _collectSpecs();
    final modelsDir = await _modelsDir();

    int done = 0;
    for (final spec in specs) {
      final file = File('${modelsDir.path}/${spec.destination}');
      if (await file.exists() && await file.length() >= spec.minBytes) {
        done++;
      }
    }

    final llmReady = await _hasAnyLlm(modelsDir.path);
    if (mounted) {
      setState(() {
        _total = specs.length;
        _completed = done;
        _allDone = llmReady && done >= specs.length;
        _status = _allDone
            ? 'All offline AI components are ready on this device.'
            : 'Local AI setup is required once.';
      });
    }
  }

  Future<Directory> _modelsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/models');
    await dir.create(recursive: true);
    return dir;
  }

  Future<List<_AssetSpec>> _collectSpecs() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets().toSet();

    final specs = <_AssetSpec>[];
    for (final spec in _kCoreAssets) {
      if (assets.contains(spec.assetPath)) {
        specs.add(spec);
      } else if (spec.required) {
        specs.add(spec);
      }
    }

    // Optional Kokoro pack (if bundled in this app build).
    final kokoroAssets = assets
        .where((a) => a.startsWith('assets/models/kokoro/'))
        .toList()
      ..sort();
    for (final a in kokoroAssets) {
      specs.add(
        _AssetSpec(
          key: 'kokoro_${a.split('/').last}',
          assetPath: a,
          destination: a.replaceFirst('assets/models/', ''),
          minBytes: 512,
          required: false,
        ),
      );
    }

    return specs;
  }

  Future<bool> _hasAnyLlm(String modelsRoot) async {
    final full = File('$modelsRoot/utkarsh_llm.gguf');
    final tiny = File('$modelsRoot/utkarsh_llm_tiny.gguf');
    final fullOk = await full.exists() && await full.length() >= 700 * 1024 * 1024;
    final tinyOk = await tiny.exists() && await tiny.length() >= 300 * 1024 * 1024;
    return fullOk || tinyOk;
  }

  Future<void> _runLocalSetup() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
      _status = 'Preparing local AI files...';
    });

    try {
      final specs = await _collectSpecs();
      final modelsDir = await _modelsDir();

      int completed = 0;
      for (final spec in specs) {
        final ok = await _ensureAsset(spec, modelsDir.path);
        if (!ok && spec.required) {
          throw Exception('Missing required asset: ${spec.assetPath}');
        }

        completed++;
        if (mounted) {
          setState(() {
            _completed = completed;
            _total = specs.length;
            _status = 'Installing ${spec.destination}';
          });
        }
      }

      final llmReady = await _hasAnyLlm(modelsDir.path);
      if (!llmReady) {
        throw Exception('No usable LLM model found (full or tiny).');
      }

      if (mounted) {
        setState(() {
          _allDone = true;
          _status = 'Offline AI setup complete.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Local setup failed: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<bool> _ensureAsset(_AssetSpec spec, String modelsRoot) async {
    final dest = File('$modelsRoot/${spec.destination}');
    if (await dest.exists() && await dest.length() >= spec.minBytes) {
      return true;
    }

    try {
      final data = await rootBundle.load(spec.assetPath);
      final bytes = data.buffer.asUint8List();
      await dest.parent.create(recursive: true);
      await dest.writeAsBytes(bytes, flush: true);
      return bytes.length >= spec.minBytes;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total == 0 ? 0.0 : (_completed / _total).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.fromSettings
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text('Offline AI Setup', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
              centerTitle: true,
              iconTheme: const IconThemeData(color: AppColors.text),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              const Icon(Icons.memory_rounded, color: AppColors.primary, size: 42),
              const SizedBox(height: AppSpacing.md),
              Text(
                _allDone ? 'Offline AI Ready' : 'Finalize Local AI Setup',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: AppFontSizes.xxl,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.surfaceElevated,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$_completed / $_total components',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, fontSize: AppFontSizes.xs),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger, fontSize: AppFontSizes.xs),
                  ),
                ),
              ],
              const Spacer(),
              if (_allDone)
                ElevatedButton.icon(
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: Text(widget.fromSettings ? 'Done' : 'Get Started'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary),
                  onPressed: widget.onDone,
                )
              else
                ElevatedButton.icon(
                  icon: _working
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black),
                        )
                      : const Icon(Icons.build_circle_rounded),
                  label: Text(_working ? 'Installing locally...' : 'Install Local Components'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary),
                  onPressed: _working ? null : _runLocalSetup,
                ),
              if (!widget.fromSettings && !_allDone && !_working) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: widget.onDone,
                  child: const Text('Continue with Cloud AI for now'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
