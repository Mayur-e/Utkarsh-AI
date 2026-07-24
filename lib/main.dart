import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'services/decision/groq_client.dart';
import 'services/burnout/burnout_service.dart';
import 'services/emotion/emotion_service.dart';
import 'services/input/speech_service.dart';
import 'services/intent/intent_service.dart';
import 'services/notifications/notification_service.dart';
import 'services/storage/database_service.dart';
import 'pipeline/layer9_response/llm_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 1. Load .env ───────────────────────────────────────────────────
  await dotenv.load(fileName: '.env');

  // ── 2. Groq API key ────────────────────────────────────────────────
  final groqKey = dotenv.env['GROQ_API_KEY'] ?? '';
  if (groqKey.isNotEmpty) {
    groqClientProvider.setApiKey(groqKey);
    debugPrint('[Main] ✅ Groq API key loaded — LLM mode active');
  } else {
    debugPrint('[Main] ⚠️ GROQ_API_KEY not found — using offline templates');
  }

  // ── 3. Database & Local AI ─────────────────────────────────────────
  debugPrint('[Main] ⏳ Initializing core services...');
  // Database is essential for initial navigation check (auth state)
  await databaseServiceProvider.initialize();
  debugPrint('[Main] ✅ Core services initialized');

  // ── 4. Supabase & Notifications (Deferred) ──────────────────────────
  // Do not await these in main() to prevent boot-up ANR
  unawaited(_backgroundInit());

  // ── 6. System UI ───────────────────────────────────────────────────
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1A2332),
    ),
  );

  runApp(const UtkarshApp());
}

/// Heavy background setup that shouldn't block the initial screen paint
Future<void> _backgroundInit() async {
  // Supabase
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    debugPrint('[Main] ⏳ Starting Supabase...');
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      debugPrint('[Main] ✅ Supabase ready');
    } catch (e) {
      debugPrint('[Main] ⚠️ Supabase init failed: $e');
    }
  }

  // Notifications
  debugPrint('[Main] ⏳ Starting Notifications...');
  try {
    await notificationService.initialize();
    debugPrint('[Main] ✅ Notification Service Ready');
    final granted = await notificationService.requestPermission();
    if (granted) notificationService.scheduleEveningCheckin();
  } catch (e) {
    debugPrint('[Main] ⚠️ Notification init failed: $e');
  }

  // Local engine init (non-blocking)
  // LLM and other engines are initialized inside AuthWrapper or on-demand
  unawaited(emotionServiceSingleton.initialize());
  unawaited(intentServiceSingleton.initialize());
  unawaited(burnoutServiceSingleton.initialize());
  unawaited(SpeechService.instance.initialize());
  unawaited(LLMService.instance.initialize());
}
