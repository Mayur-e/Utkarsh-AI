import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/app_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/prism_card.dart';
import '../widgets/avatar_display.dart';
import '../widgets/message_bubble.dart';
import '../../../services/response/response_engine.dart';
import '../../../services/storage/database_service.dart';
import '../../../services/decision/groq_client.dart';
import '../../assessment/screens/assessment_screen.dart';
import '../../../services/assessment/assessment_data.dart';
import '../../../services/auth/auth_service.dart';
import '../../../models/emotion.dart';
import '../../../pipeline/layer9_response/llm_service.dart';
import '../../onboarding/screens/model_setup_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _modelNotReady = false; // true when offline mode ON but LLM not downloaded
  String _mode = 'offline';

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    // Ensure DB + ML models are ready before reading history
    await responseEngineProvider.ensureInitialized();
    final history = await databaseServiceProvider.getRecentMessages(userId: AuthService.instance.currentUser?.id);
    final profile = await responseEngineProvider.getCurrentProfile();
    final isOnline = profile.onlineAiEnabled;
    await LLMService.instance.checkDiskPresence();
    
    if (mounted) {
      setState(() {
        _messages.clear();
        _messages.addAll(history.map((m) => {
          'role': m['role'],
          'content': m['content'],
          'timestamp': m['timestamp'] as int,
        }));
        // Use isDownloaded (disk) instead of isReady (RAM) for the initial banner check
        _modelNotReady = !isOnline && !LLMService.instance.isDownloaded;
      });
      _scrollToBottom();

      // Trigger proactive greeting
      if (history.isEmpty) {
        _generateGreeting();
      } else {
        final lastStamp = history.last['timestamp'] as int;
        if (DateTime.now().millisecondsSinceEpoch - lastStamp > 14400000) {
          _generateGreeting();
        }
      }
    }
  }

  Future<void> _generateGreeting() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final greeting = await responseEngineProvider.generateGreeting();
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': greeting,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('[ChatScreen] Greeting error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    _controller.clear();
    setState(() {
      _messages.add({
        'role': 'user',
        'content': text,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      _isLoading = true;
    });
    _scrollToBottom();

    // Set avatar to thinking
    ref.read(avatarStateProvider.notifier).state = AvatarState.thinking;

    try {
      // Prepare history for Groq context (Taking the 6 most recent messages)
      final history = _messages
          .skip(_messages.length > 6 ? _messages.length - 6 : 0)
          .take(6)
          .map((m) => GroqMessage(
                role: m['role'] as String,
                content: m['content'] as String,
              ))
          .toList();

      final result = await responseEngineProvider.process(
        text,
        history,
        onToken: (token) {
          if (mounted) {
            setState(() {
              // If the last message is from assistant, appended to it
              if (_messages.isNotEmpty && _messages.last['role'] == 'assistant') {
                _messages.last['content'] += token;
              } else {
                _messages.add({
                  'role': 'assistant',
                  'content': token,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                });
              }
            });
            _scrollToBottom();
          }
        },
      );

      setState(() {
        _mode = result.aiMode == AiMode.groq
            ? 'online'
            : (result.aiMode == AiMode.llm ? 'offline-llm' : 'offline');
        _isLoading     = false;
        _modelNotReady = false; // Dismiss banner on any successful response
      });

      // NEW: Trigger Refresh if a task was added in the background
      if (result.tasksExtracted > 0) {
        ref.read(chatRefreshProvider.notifier).update((s) => s + 1);
      }

      // Update Avatar based on emotion
      ref.read(avatarStateProvider.notifier).state = 
          result.emotionLabel == Emotion.happy ? AvatarState.happy : 
          (result.stressLevel > 60 ? AvatarState.stressed : AvatarState.idle);

      // Trigger Assessment Prompt (Phase 12, Part A, Step 3)
      if (result.shouldPromptAssessment && result.triggeredAssessment != null && mounted) {
        _showAssessmentInvitation(result.triggeredAssessment!);
      }

    } catch (e) {
      if (e is ModelNotLoadedException) {
        // Offline mode is on but model hasn't been downloaded yet
        setState(() {
          _modelNotReady = true;
          _isLoading = false;
          // Remove the user message we just added so it's not orphaned
          if (_messages.isNotEmpty && _messages.last['role'] == 'user') {
            _messages.removeLast();
          }
        });
        _controller.text = text; // restore typed text
      } else {
        debugPrint('[ChatScreen] Pipeline error: $e');
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': "Sorry, I had a moment. Please try again. 💚",
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
          _isLoading = false;
        });
      }
      ref.read(avatarStateProvider.notifier).state = AvatarState.idle;
    } finally {
      _scrollToBottom();
    }
  }

  void _showAssessmentInvitation(AssessmentType type) {
    String title = '🛡️ Wellness Check-in';
    String message = "I've noticed something. Would you like to take a brief wellness assessment? It helps me understand your state better.";
    
    if (type == AssessmentType.phq9 || type == AssessmentType.gad7) {
       title = '🛡️ Safety Check-in';
       message = "I've noticed you're going through a lot. Would you like to take a brief, private wellness assessment (${type.name.toUpperCase()})? It helps me understand how to support you better.";
    } else if (type == AssessmentType.dailyMood || type == AssessmentType.dailyStress) {
       title = '📊 Daily Progress';
       message = "Would you like to complete your daily ${type == AssessmentType.dailyMood ? 'mood' : 'stress'} check-in now? This keeps your wellbeing history accurate.";
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.white, foregroundColor: Colors.black),
                onPressed: () {
                  Navigator.pop(context);
                  _startAssessment(type);
                }, 
                child: const Text('Start Assessment'),
              ),
            ),
            TextButton(
              onPressed: () async {
                // Record skip so it doesn't pop up again today
                final navigator = Navigator.of(context);
                final uid = AuthService.instance.currentUser?.id;
                await databaseServiceProvider.saveAssessment({
                  'type': type.name,
                  'responses': '[]',
                  'severity': 'skipped',
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                  'date': DateTime.now().toIso8601String().split('T')[0],
                }, uid);
                
                if (!context.mounted) return;
                navigator.pop();
              },
              child: const Text('Maybe later', style: TextStyle(color: AppColors.textMuted)),
            ),
          ],
        ),
      ),
    );
  }

  void _startAssessment(AssessmentType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssessmentScreen(
          type: type,
          onComplete: (res) {
            Navigator.pop(context); // back to chat
            setState(() {
              _messages.add({
                'role': 'assistant',
                'content': "Thank you for completing that. Your score indicates '${res.severity}' symptoms. I've noted this, and we'll focus on stabilizing things together. 💚",
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              });
            });
            _scrollToBottom();
          },
          onDismiss: () => Navigator.pop(context),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    ref.listen(chatRefreshProvider, (prev, next) {
      _loadMessages();
    });

    final isOnline = ref.watch(isOnlineProvider);
    
    // Auto-dismiss the "Not Ready" banner if the user just finished setup and returned here
    if (_modelNotReady && !isOnline && LLMService.instance.isDownloaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _modelNotReady = false);
      });
    }

    final avatarState = ref.watch(avatarStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.11),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.06),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
            // Header: Avatar + Mode Indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Column(
                children: [
                  AvatarDisplay(
                    state: avatarState,
                    size: 92,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Utkarsh AI',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Your Wellbeing Companion',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            // ── Model not ready banner ──────────────────────────────────
            if (_modelNotReady)
              Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.45)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: AppColors.warning, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Offline AI Model Not Initialized',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.bold,
                            fontSize: AppFontSizes.sm,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'You are in Offline mode but the on-device AI models haven\'t been initialized yet. '
                      'Complete the one-time local setup (~1.2 GB) or switch to Online AI.',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppFontSizes.xs,
                          height: 1.4),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.settings_suggest_rounded, size: 16),
                            label: const Text('Initialize AI'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning,
                              foregroundColor: AppColors.black,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              textStyle: const TextStyle(
                                  fontSize: AppFontSizes.xs,
                                  fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ModelSetupScreen(
                                    onDone: () async {
                                      Navigator.pop(context);
                                      // Force reload so LLMService picks up the new file
                                      await LLMService.instance.reinitialize();
                                      if (mounted) {
                                        setState(() {
                                          _modelNotReady = !LLMService.instance.isReady;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/settings');
                          },
                          child: const Text('Settings',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: AppFontSizes.xs)),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        TextButton(
                          onPressed: () async {
                              final uid = AuthService.instance.currentUser?.id;
                              if (uid != null) {
                                await databaseServiceProvider.updateProfile({'online_ai_enabled': 1}, uid);
                                // Sync back to local state
                                await responseEngineProvider.getCurrentProfile();
                                if (mounted) {
                                  setState(() {
                                    _modelNotReady = false;
                                    _mode = 'online';
                                  });
                                }
                              }
                          },
                          child: const Text('Switch to Online',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: AppFontSizes.xs,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Message List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return MessageBubble(
                    role: msg['role'] as String,
                    content: msg['content'] as String,
                    timestamp: msg['timestamp'] as int,
                  );
                },
              ),
            ),

            // Loading indicator
            if (_isLoading)
               const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
              ),

            // Input Row
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                        boxShadow: PrismShadows.ambientShadow,
                      ),
                      child: TextField(
                        controller: _controller,
                        style: AppTypography.bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'How are you feeling?',
                          hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant),
                          border: InputBorder.none,
                        ),
                        maxLines: 4,
                        minLines: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 48,
                      height: 48,
                      margin: const EdgeInsets.only(bottom: 2), // Align visually with text field
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: PrismShadows.ambientShadow,
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_upward, color: AppColors.onPrimary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
