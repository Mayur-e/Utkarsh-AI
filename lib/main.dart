import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/decision/groq_client.dart';
import 'services/emotion/emotion_service.dart';
import 'services/intent/intent_service.dart';
import 'services/notifications/notification_service.dart';
import 'services/growth/xp_service.dart';
import 'services/storage/database_service.dart';
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

  // ── 3. Database & Local AI MUST be initialized first ─────────────────────────
  await databaseServiceProvider.initialize();
  await emotionServiceSingleton.initialize();
  await intentServiceSingleton.initialize();
  debugPrint('[Main] ✅ Database & Local Models initialized');

  // ── 4. Supabase & Cloud Setup ─────────────────────────────────────
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    debugPrint('[Main] ✅ Supabase initialized');
  } else {
    debugPrint('[Main] ⚠️ Supabase credentials missing');
  }

  // ── 4. Daily check-in XP (DB is now ready) ────────────────────────
  try {
    await xpService.onDailyCheckin();
    debugPrint('[Main] ✅ Daily check-in XP awarded (+3)');
  } catch (e) {
    debugPrint('[Main] Check-in XP skipped: $e');
  }

  // ── 5. Notifications ───────────────────────────────────────────────
  await notificationService.initialize();
  final permGranted = await notificationService.requestPermission();
  if (permGranted) {
    await notificationService.scheduleEveningCheckin();
    debugPrint('[Main] ✅ Notifications initialized');
  }

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
