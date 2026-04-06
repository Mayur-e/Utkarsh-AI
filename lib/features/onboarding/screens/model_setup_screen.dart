import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';

// ── Model specs ─────────────────────────────────────────────────────────────

class _ModelSpec {
  final String key;
  final String label;
  final String emoji;
  final String filename;
  final String url;
  final int sizeMB;

  const _ModelSpec({
    required this.key,
    required this.label,
    required this.emoji,
    required this.filename,
    required this.url,
    required this.sizeMB,
  });
}

const List<_ModelSpec> _models = [
  _ModelSpec(
    key: 'llm',
    label: 'Conversation AI (LLM)',
    emoji: '🧠',
    filename: 'utkarsh_llm.gguf',
    url:
        'https://huggingface.co/RichardErkhov/BunnyBosz_-_llama-3.2-1b-fine-tuned-model-mental-health-gguf/resolve/main/llama-3.2-1b-fine-tuned-model-mental-health.Q4_K_M.gguf',
    sizeMB: 770,
  ),
  _ModelSpec(
    key: 'burnout',
    label: 'Burnout Classifier',
    emoji: '🔥',
    filename: 'burnout.onnx',
    url:
        'https://huggingface.co/SamLowe/roberta-base-go_emotions/resolve/main/onnx/model.onnx',
    sizeMB: 476,
  ),
];

// ── Screen ──────────────────────────────────────────────────────────────────

class ModelSetupScreen extends StatefulWidget {
  /// Called when the user is done (either downloaded or skipped).
  final VoidCallback onDone;

  const ModelSetupScreen({super.key, required this.onDone});

  @override
  State<ModelSetupScreen> createState() => _ModelSetupScreenState();
}

class _ModelSetupScreenState extends State<ModelSetupScreen> {
  final Map<String, double> _progress = {};   // 0–1
  final Map<String, bool>   _done     = {};
  final Map<String, String> _errors   = {};
  bool _downloading   = false;
  bool _anyError      = false;

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(hours: 2),
  ));

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  Future<void> _checkExisting() async {
    final dir = await _modelsDir();
    for (final m in _models) {
      final f = File('${dir.path}/${m.filename}');
      if (await f.exists()) {
        _done[m.key] = true;
        _progress[m.key] = 1.0;
      }
    }
    if (mounted) setState(() {});
  }

  Future<Directory> _modelsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir  = Directory('${base.path}/models');
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> _downloadAll() async {
    setState(() { _downloading = true; _anyError = false; });

    final dir = await _modelsDir();

    for (final m in _models) {
      if (_done[m.key] == true) continue;
      final dest = File('${dir.path}/${m.filename}');

      try {
        await _dio.download(
          m.url,
          dest.path,
          onReceiveProgress: (received, total) {
            if (!mounted) return;
            setState(() {
              _progress[m.key] = total > 0 ? received / total : 0;
            });
          },
        );
        if (mounted) setState(() { _done[m.key] = true; _progress[m.key] = 1.0; });
      } catch (e) {
        if (await dest.exists()) await dest.delete();
        if (mounted) {
          String userFriendlyError = 'Network error occurred. Please check your connection.';
          
          if (e is DioException) {
            if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
              userFriendlyError = 'Connection timed out. Please check your signal.';
            } else if (e.type == DioExceptionType.connectionError) {
              userFriendlyError = 'Could not connect to the server. Are you offline?';
            }
          }

          setState(() {
            _errors[m.key] = userFriendlyError;
            _anyError       = true;
          });
        }
      }
    }

    if (mounted) setState(() => _downloading = false);
  }

  bool get _allDone => _models.every((m) => _done[m.key] == true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              const SizedBox(height: AppSpacing.xl),
              const Text('🤖', style: TextStyle(fontSize: 48)),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Download AI Models',
                style: TextStyle(
                  color:      AppColors.text,
                  fontSize:   AppFontSizes.xxl,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'For fully offline, private AI responses download the on-device models (~1.2 GB). '
                'You can skip this and use Groq Cloud instead.',
                style: TextStyle(
                  color:    AppColors.textSecondary,
                  fontSize: AppFontSizes.sm,
                  height:   1.5,
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Model Cards ─────────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  itemCount: _models.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (ctx, i) {
                    final m    = _models[i];
                    final prog = _progress[m.key] ?? 0.0;
                    final done = _done[m.key] == true;
                    final err  = _errors[m.key];

                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: done
                              ? AppColors.success.withValues(alpha: 0.4)
                              : err != null
                                  ? AppColors.danger.withValues(alpha: 0.4)
                                  : AppColors.surfaceElevated,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(m.emoji, style: const TextStyle(fontSize: 28)),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.label,
                                        style: const TextStyle(
                                          color:      AppColors.text,
                                          fontWeight: FontWeight.w600,
                                          fontSize:   AppFontSizes.md,
                                        )),
                                    Text('${m.sizeMB} MB',
                                        style: const TextStyle(
                                          color:   AppColors.textMuted,
                                          fontSize: AppFontSizes.xs,
                                        )),
                                  ],
                                ),
                              ),
                              if (done)
                                const Icon(Icons.check_circle, color: AppColors.success)
                              else if (err != null)
                                const Icon(Icons.error_outline, color: AppColors.danger),
                            ],
                          ),
                          if (!done && prog > 0) ...[
                            const SizedBox(height: AppSpacing.sm),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.full),
                              child: LinearProgressIndicator(
                                value:           prog,
                                minHeight:       6,
                                backgroundColor: AppColors.surfaceElevated,
                                color:           AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(prog * 100).toStringAsFixed(0)}% · ${(prog * m.sizeMB).toStringAsFixed(0)} / ${m.sizeMB} MB',
                              style: const TextStyle(
                                color:   AppColors.textMuted,
                                fontSize: AppFontSizes.xs,
                              ),
                            ),
                          ],
                          if (err != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '⚠️  $err',
                              style: const TextStyle(
                                color:   AppColors.danger,
                                fontSize: AppFontSizes.xs,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),

              // ── Actions ─────────────────────────────────────────────────
              const SizedBox(height: AppSpacing.lg),

              if (_anyError)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi_off, color: AppColors.danger, size: 18),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Download failed. Check your internet connection and try again. '
                          'You can also skip and use Cloud AI mode.',
                          style: TextStyle(color: AppColors.danger, fontSize: AppFontSizes.xs),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_allDone)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('All Done — Continue'),
                    style: AppTheme.primaryButton,
                    onPressed: widget.onDone,
                  ),
                )
              else if (!_downloading)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.download),
                        label: Text(_anyError ? 'Retry Failed Downloads' : 'Download Offline Models'),
                        style: AppTheme.primaryButton,
                        onPressed: _downloadAll,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.surfaceElevated),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: widget.onDone,
                        child: const Text('Skip — Use Cloud AI Instead'),
                      ),
                    ),
                  ],
                )
              else
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                      SizedBox(height: AppSpacing.sm),
                      Text('Downloading models — keep app open...',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: AppFontSizes.sm)),
                    ],
                  ),
                ),

              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
