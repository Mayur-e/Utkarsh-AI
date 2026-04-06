import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';

// ── Model registry (internal only — not shown to user) ────────────────────────

class _ModelSpec {
  final String key;
  final String filename;
  final String url;
  final int sizeMB;
  const _ModelSpec({required this.key, required this.filename, required this.url, required this.sizeMB});
}

const _kModels = [
  _ModelSpec(
    key: 'llm',
    filename: 'utkarsh_llm.gguf',
    url: 'https://huggingface.co/RichardErkhov/BunnyBosz_-_llama-3.2-1b-fine-tuned-model-mental-health-gguf/resolve/main/llama-3.2-1b-fine-tuned-model-mental-health.Q4_K_M.gguf',
    sizeMB: 770,
  ),
  _ModelSpec(
    key: 'burnout',
    filename: 'burnout.onnx',
    url: 'https://huggingface.co/SamLowe/roberta-base-go_emotions/resolve/main/onnx/model.onnx',
    sizeMB: 476,
  ),
];

const _kTotalMB = 1246; // sum of all model sizes

// ── Screen ────────────────────────────────────────────────────────────────────

class ModelSetupScreen extends StatefulWidget {
  /// Called when all models are ready (or user explicitly skips).
  final VoidCallback onDone;

  /// If true (from Settings), don't show skip button — user must download or
  /// press the back button.
  final bool fromSettings;

  const ModelSetupScreen({super.key, required this.onDone, this.fromSettings = false});

  @override
  State<ModelSetupScreen> createState() => _ModelSetupScreenState();
}

class _ModelSetupScreenState extends State<ModelSetupScreen> {
  final Map<String, double> _progress = {};
  final Map<String, bool>   _done     = {};
  String? _errorMessage;
  bool _downloading = false;

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(hours: 3),
  ));

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  Future<void> _checkExisting() async {
    final dir = await _modelsDir();
    for (final m in _kModels) {
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

  bool get _allDone => _kModels.every((m) => _done[m.key] == true);

  // Overall 0–1 progress across all models
  double get _overallProgress {
    if (_kModels.isEmpty) return 0;
    double total = 0;
    for (final m in _kModels) {
      total += _progress[m.key] ?? 0.0;
    }
    return total / _kModels.length;
  }

  // Current MB downloaded (approximate)
  int get _downloadedMB => (_overallProgress * _kTotalMB).round();

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _errorMessage = null;
    });

    final dir = await _modelsDir();

    for (final m in _kModels) {
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
        if (mounted) {
          setState(() {
            _done[m.key] = true;
            _progress[m.key] = 1.0;
          });
        }
      } catch (e) {
        // Clean up partial file
        if (await dest.exists()) await dest.delete();

        String msg = 'Network error occurred. Please check your connection and try again.';
        if (e is DioException) {
          if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
            msg = 'Connection timed out. Please check your internet signal.';
          } else if (e.type == DioExceptionType.connectionError) {
            msg = 'Could not connect to the server. Are you offline?';
          }
        }

        if (mounted) setState(() => _errorMessage = msg);
        break; // stop — don't attempt remaining models if network failed
      }
    }

    if (mounted) setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxl),

              // ── Header icon ──────────────────────────────────────────────
              Center(
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                  ),
                  child: const Icon(Icons.memory_rounded, color: AppColors.primary, size: 40),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Title ────────────────────────────────────────────────────
              Center(
                child: Text(
                  _allDone ? 'Offline AI Ready' : 'Complete Offline Setup',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: AppFontSizes.xxl,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              Center(
                child: Text(
                  _allDone
                      ? 'All AI components are installed on your device. Utkarsh can now run fully privately, without any internet connection.'
                      : 'To enable fully private, on-device AI responses, extra data needs to be downloaded (~${_kTotalMB / 1024 ~/ 1} GB). This is a one-time setup.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFontSizes.sm,
                    height: 1.55,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              const Spacer(),

              // ── Progress section (visible while downloading) ─────────────
              if (_downloading || (_overallProgress > 0 && !_allDone)) ...[
                _ProgressSection(
                  progress: _overallProgress,
                  downloadedMB: _downloadedMB,
                  totalMB: _kTotalMB,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // ── Success state ────────────────────────────────────────────
              if (_allDone) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
                      SizedBox(width: AppSpacing.sm),
                      Text(
                        'All components installed',
                        style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // ── Error banner ─────────────────────────────────────────────
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.signal_wifi_off_rounded, color: AppColors.danger, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.danger, fontSize: AppFontSizes.xs),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // ── Action buttons ───────────────────────────────────────────
              if (_allDone)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.rocket_launch_rounded),
                    label: Text(widget.fromSettings ? 'Done' : 'Get Started'),
                    style: AppTheme.primaryButton,
                    onPressed: widget.onDone,
                  ),
                )
              else if (_downloading)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          _dio.close(force: true);
                          setState(() => _downloading = false);
                        },
                        child: const Text('Cancel Download'),
                      ),
                    ),
                    if (!widget.fromSettings) ...[
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: widget.onDone,
                        child: const Text('Continue with Cloud AI for now',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: AppFontSizes.sm)),
                      ),
                    ],
                  ],
                )
              else
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.download_rounded),
                        label: Text(
                          _errorMessage != null ? 'Retry Download' : 'Download & Complete Setup',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: AppTheme.primaryButton,
                        onPressed: _startDownload,
                      ),
                    ),
                    if (!widget.fromSettings) ...[
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
                  ],
                ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Progress widget ───────────────────────────────────────────────────────────

class _ProgressSection extends StatelessWidget {
  final double progress;
  final int downloadedMB;
  final int totalMB;

  const _ProgressSection({
    required this.progress,
    required this.downloadedMB,
    required this.totalMB,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Downloading AI components...',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: AppFontSizes.sm),
            ),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: AppFontSizes.sm),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.surfaceElevated,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$downloadedMB MB / $totalMB MB · Keep the app open',
          style: const TextStyle(color: AppColors.textMuted, fontSize: AppFontSizes.xs),
        ),
      ],
    );
  }
}
