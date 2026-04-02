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
  String _mode = 'offline';

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    // Ensure DB + ML models are ready before reading history
    await responseEngineProvider.ensureInitialized();
    final history = await databaseServiceProvider.getRecentMessages();
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

      final result = await responseEngineProvider.process(text, history);
      
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': result.response,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        _mode = result.aiMode == AiMode.groq ? 'online' : 'offline';
        _isLoading = false;
      });

      // NEW: Trigger Refresh if a task was added in the background
      if (result.tasksExtracted > 0) {
        ref.read(chatRefreshProvider.notifier).update((s) => s + 1);
      }

      // Update Avatar based on emotion
      ref.read(avatarStateProvider.notifier).state = 
          result.emotionLabel == EmotionLabel.positive ? AvatarState.happy : 
          (result.stressLevel > 60 ? AvatarState.stressed : AvatarState.idle);

      // Trigger Assessment Prompt (Phase 12, Part A, Step 3)
      if (result.shouldPromptAssessment && mounted) {
        _showAssessmentInvitation();
      }

    } catch (e) {
      debugPrint('[ChatScreen] Pipeline error: $e');
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': "Sorry, I had a moment. Please try again. 💚",
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        _isLoading = false;
      });
      ref.read(avatarStateProvider.notifier).state = AvatarState.idle;
    } finally {
      _scrollToBottom();
    }
  }

  void _showAssessmentInvitation() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🛡️ Safety Check-in', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.md),
            const Text(
              "I've noticed you're going through a lot. Would you like to take a brief, private wellness assessment (PHQ-9)? It helps me understand how to support you better.",
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.white, foregroundColor: Colors.black),
                onPressed: () {
                  Navigator.pop(context);
                  _startAssessment(AssessmentType.phq9);
                }, 
                child: const Text('Start Assessment'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
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
                          color: _mode == 'online' ? AppColors.success : AppColors.textMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _mode == 'online' ? 'Online AI (Llama 3)' : 'Offline AI (Local)',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: AppFontSizes.xs),
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
