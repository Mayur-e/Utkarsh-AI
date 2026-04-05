class AppConstants {
  AppConstants._();

  // Model file names
  static const String emotionModelFile = 'emotion_model.onnx';
  static const String intentModelFile = 'intent_classifier.onnx';
  static const String llmModelFile = 'utkarsh_llm.gguf'; // ~750MB
  static const String llmModelFallback =
      'utkarsh_llm_tiny.gguf'; // ~397MB (Qwen 0.5B)

  // Lottie animation asset paths
  static const String lottieIdle = 'assets/lottie/avatar_idle.json';
  static const String lottieHappy = 'assets/lottie/avatar_happy.json';
  static const String lottieStressed = 'assets/lottie/avatar_stressed.json';
  static const String lottieThinking = 'assets/lottie/avatar_thinking.json';

  // CWS formula weights (must sum to exactly 1.0)
  static const double cwsWeightEmotion = 0.25;
  static const double cwsWeightStress = 0.15;
  static const double cwsWeightTasks = 0.15;
  static const double cwsWeightActivity = 0.10;
  static const double cwsWeightRoutine = 0.10;
  static const double cwsWeightBehavior = 0.15;
  static const double cwsWeightGrowth = 0.10;

  // XP rewards
  static const int xpTaskCompleted = 10;
  static const int xpReflectionAdded = 5;
  static const int xpStressReduced = 15;
  static const int xpWeeklyStreak = 20;
  static const int xpAssessmentComplete = 8;
  static const int xpDailyCheckin = 3;
  static const int xpMoodImproved = 10;

  // Groq API
  static const String groqModel = 'llama3-8b-8192';
  static const int groqMaxTokens = 512;
  static const double groqTemperature = 0.72;
  static const String groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  // Intent classes
  static const List<String> intentClasses = [
    'stress_help',
    'task_add',
    'planning',
    'knowledge_query',
    'casual',
  ];

  // Encryption
  static const String encryptionKeyAlias = 'utkarsh_v2_master_key';

  // Database
  static const String dbName = 'utkarsh_v2.db';
  static const int dbVersion = 2;
}
