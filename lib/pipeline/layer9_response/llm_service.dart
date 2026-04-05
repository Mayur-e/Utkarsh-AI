import 'package:flutter/foundation.dart';

/// Legacy Role Enum for compatibility
enum MessageRole { user, assistant, system }

/// Support classes for type safety found in legacy implementation
class ChatMessage {
  final dynamic role; // Using dynamic to allow both String and Enum for legacy calls
  final String content;
  ChatMessage({required this.role, required this.content});

  Map<String, String> toMap() {
    return {
      'role': role is MessageRole ? (role as MessageRole).name : role.toString(),
      'content': content,
    };
  }
}

/// A response wrapper expected by the ResponseEngine
class LLMResponse {
  final String text;
  LLMResponse(this.text);
}

class LLMService {
  LLMService._();
  static final LLMService instance = LLMService._();

  bool _isInit = false;

  bool get isReady => _isInit;

  Future<void> initialize() async {
    if (_isInit) return;
    _isInit = true;
    debugPrint('[LLMService] Mock Initialized (Using Cloud AI) ✅');
  }

  Future<void> ensureReady() async {
    if (!_isInit) await initialize();
  }

  /// Compatibility method for EmotionService/IntentService
  Future<String> generate({
    required List<ChatMessage> history,
    required String systemPrompt,
    Function(String)? onToken,
    Duration? timeout,
  }) async {
    return "Offline model is disabled.";
  }

  /// Compatibility method for ResponseEngine
  Future<LLMResponse> generateStream({
    required List<ChatMessage> history,
    required String systemPrompt,
    Function(String)? onToken,
  }) async {
    // Mock simulation of "streaming" for UI
    const mock = "Offline model is disabled. Please use Groq for live chat.";
    if (onToken != null) onToken(mock);
    return LLMResponse(mock);
  }
}
