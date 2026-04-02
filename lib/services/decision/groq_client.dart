import 'dart:convert';
import 'package:http/http.dart' as http;

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

  Future<GroqResponse> sendMessage(List<GroqMessage> messages, {String? systemPrompt}) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Groq API key not configured');
    }

    final List<Map<String, String>> payloadMessages = [
      if (systemPrompt != null) {'role': 'system', 'content': systemPrompt},
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
}

final groqClientProvider = GroqClient();
