class CapturedInput {
  final String original;
  final String normalized;
  final int wordCount;
  final bool hasQuestion;
  final String language; // 'en', 'hi', 'mixed'
  final int timestamp;

  CapturedInput({
    required this.original,
    required this.normalized,
    required this.wordCount,
    required this.hasQuestion,
    required this.language,
    required this.timestamp,
  });
}

class InputCaptureService {
  CapturedInput capture(String rawText) {
    final String original = rawText.trim();
    final String normalized = _normalize(original);
    final int wordCount = normalized.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;

    return CapturedInput(
      original: original,
      normalized: normalized,
      wordCount: wordCount,
      hasQuestion: _detectQuestion(original),
      language: _detectLanguage(normalized),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  String _normalize(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r"[^\w\s'.,!?]"), ' ')
        .trim()
        .substring(0, text.length > 500 ? 500 : text.length);
  }

  bool _detectQuestion(String text) {
    return text.contains('?') ||
        RegExp(r'^(what|why|how|when|where|who|is|are|can|does)', caseSensitive: false).hasMatch(text);
  }

  String _detectLanguage(String text) {
    const List<String> hindiMarkers = ['hai', 'hoon', 'mera', 'tera', 'kyun', 'kya', 'bahut', 'thoda', 'acha', 'theek'];
    final String lower = text.toLowerCase();
    final int hindiCount = hindiMarkers.where((w) => lower.contains(w)).length;
    
    if (hindiCount >= 3) return 'hi';
    if (hindiCount >= 1) return 'mixed';
    return 'en';
  }
}

final inputCaptureServiceProvider = InputCaptureService();
