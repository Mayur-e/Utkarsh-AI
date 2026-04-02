import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/context_capsule.dart';
import '../../models/user_profile.dart';

class GroqMessage {
  final String role;
  final String content;

  GroqMessage({required this.role, required this.content});

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class GroqResponse {
  final String content;
  final String model;
  final int totalTokens;

  GroqResponse({
    required this.content,
    required this.model,
    required this.totalTokens,
  });
}

class GroqClient {
  static const String _endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  String? _apiKey;

  void setApiKey(String key) => _apiKey = key;

  Future<GroqResponse> sendMessage(
    List<GroqMessage> messages, {
    ContextCapsule? context,
    UserProfile? profile,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Groq API key not configured');
    }

    final systemPrompt = profile != null 
        ? _buildSystemPrompt(context, profile) 
        : 'You are Utkarsh, a warm and empathetic AI companion for students.';

    final List<Map<String, String>> payloadMessages = [
      {'role': 'system', 'content': systemPrompt},
      ...messages.map((m) => m.toJson()),
    ];

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile', // Default high-quality model
        'messages': payloadMessages,
        'temperature': 0.7,
        'max_tokens': 1024,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Groq API Error: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(response.body);
    return GroqResponse(
      content: data['choices'][0]['message']['content'],
      model: data['model'],
      totalTokens: data['usage']['total_tokens'] ?? 0,
    );
  }

  /// Build a privacy-safe system prompt incorporating user context.
  String _buildSystemPrompt(ContextCapsule? context, UserProfile profile) {
    final buffer = StringBuffer();

    buffer.writeln('You are Utkarsh, a warm and empathetic AI companion for students.');
    buffer.writeln('');

    // User profile context (personalization — Phase 2)
    buffer.writeln('USER PROFILE:');
    buffer.writeln('Name: ${profile.displayName ?? "User"}');
    buffer.writeln('Age: ${profile.age ?? "N/A"}');
    buffer.writeln('Profession: ${profile.profession ?? "Student"}');
    if (profile.institution != null) {
      buffer.writeln('Institution: ${profile.institution}');
    }
    if (profile.yearOfStudy != null) {
      buffer.writeln('Year of Study: ${profile.yearOfStudy}');
    }
    buffer.writeln('');

    // Behavioral context from capsule
    if (context != null) {
      buffer.writeln('RECENT CONTEXT (last 7 days):');
      buffer.writeln('Emotional trend: ${context.dominantEmotion}');
      buffer.writeln('Average stress: ${context.averageStressLevel.toStringAsFixed(0)}/100');
      if (context.behavioralFlags.isNotEmpty) {
        buffer.writeln('Behavioral patterns: ${context.behavioralFlags.join(', ')}');
      }
      if (context.consecutiveNegativeDays >= 2) {
        buffer.writeln('Note: User has had ${context.consecutiveNegativeDays} difficult days recently.');
      }
      if (context.sessionThemes.isNotEmpty) {
        buffer.writeln('Recurring themes: ${context.sessionThemes.map((t) => t.name).join(', ')}');
      }
      buffer.writeln('');
    }

    buffer.writeln('GUIDELINES:');
    buffer.writeln('- Address user by name: ${profile.displayName ?? "User"}');
    buffer.writeln('- Keep responses concise (2-4 sentences)');
    buffer.writeln('- Acknowledge feelings before offering solutions');
    buffer.writeln('- Reference their academic context naturally');
    buffer.writeln('- Never diagnose. Suggest professional help for serious concerns');
    buffer.writeln('- Respond in same language the student uses');
    buffer.writeln('');
    buffer.writeln('PRIVACY: Never repeat PHQ-9/GAD-7 raw scores in conversation.');

    return buffer.toString();
  }
}

final groqClientProvider = GroqClient();
