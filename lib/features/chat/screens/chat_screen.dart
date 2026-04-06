import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/app_state.dart';
import '../../../core/theme/app_theme.dart';
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
    final uid = AuthService.instance.currentUser?.id;
    final history = await databaseServiceProvider.getRecentMessages(userId: uid);
    if (mounted) {
      setState(() {
        _messages.clear();
        _messages.addAll(history.map((m) => {
          'role': m['role'],
          'content': m['content'],
          'timestamp': m['timestamp'] as int,
        }));
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
        _isLoading = false;
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

    final avatarState = ref.watch(avatarStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header: Avatar + Mode Indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                children: [
                  AvatarDisplay(
                    state: avatarState,
                    size: 100,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _mode == 'online' ? AppColors.success
                              : (_mode == 'offline-llm' ? AppColors.primary : AppColors.textMuted),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _mode == 'online'
                            ? 'Online AI (Groq)'
                            : (_mode == 'offline-llm'
                                ? 'Offline AI (On-Device LLM) ✅'
                                : 'Template Responses'),
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: AppFontSizes.xs),
                      ),
                    ],
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
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Offline AI Model Not Loaded',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: AppFontSizes.sm,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'You are in Offline mode but the on-device LLM hasn\'t been downloaded yet. '
                      'Download it (~770 MB) or switch to Online AI in Settings.',
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
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('Download Model'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.black,
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
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.surfaceElevated, width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'How are you feeling?',
                          hintStyle: TextStyle(color: AppColors.textMuted),
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
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_upward, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
