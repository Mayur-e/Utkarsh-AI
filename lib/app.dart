import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'navigation/app_router.dart';
import 'services/auth/auth_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/auth/screens/pin_unlock_screen.dart';
import 'features/onboarding/screens/onboarding_flow.dart';
import 'features/onboarding/screens/model_setup_screen.dart';
import 'services/storage/database_service.dart';
import 'pipeline/layer9_response/llm_service.dart';
import 'features/settings/screens/profile_view_screen.dart';

class UtkarshApp extends StatelessWidget {
  const UtkarshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title:                      'Utkarsh',
        debugShowCheckedModeBanner: false,
        theme:                      AppTheme.darkTheme,
        // Using a builder to decide the initial screen based on auth state
        home: const AuthWrapper(),
        routes: {
          '/login':        (context) => const LoginScreen(),
          '/home':         (context) => const AppShell(),
          '/unlock':       (context) => const PinUnlockScreen(),
          '/onboarding':   (context) => const OnboardingFlow(),
          '/signup':       (context) => const OnboardingFlow(isNewUser: true),
          '/profile':      (context) => const ProfileViewScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isInit          = true;
  bool _onboardingDone  = false;
  bool _modelSetupDone  = false;  // shown once after onboarding

  @override
  void initState() {
    super.initState();
    _checkAppStart();
  }

  Future<void> _checkAppStart() async {
    final auth = AuthService.instance;
    // 1. PIN Auto-Unlock
    if (auth.isLoggedIn && !auth.isUnlocked) {
      await auth.tryAutoUnlock();
    }

    // 2. LLM Background Init — don't await, loads while user authenticates
    LLMService.instance.initialize();

    // 3. Profile check (for onboarding gate)
    if (auth.isUnlocked) {
      final profile = await DatabaseService.instance.getProfile(auth.currentUser?.id);
      if (profile != null) {
        _onboardingDone = profile['onboarding_done'] == 1;
        _modelSetupDone = profile['model_setup_done'] == 1;
        // NOTE: DAILY_CHECKIN XP is awarded in AssessmentScreen when user
        // completes their daily mood/stress check-in. Do NOT award here.
      }
    }
    
    if (mounted) {
      setState(() => _isInit = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInit) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1923),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF2E7D52))),
      );
    }

    final isLoggedIn = AuthService.instance.isLoggedIn;
    final isUnlocked = AuthService.instance.isUnlocked;

    if (!isLoggedIn)   return const WelcomeScreen();
    if (!isUnlocked)   return const PinUnlockScreen();
    if (!_onboardingDone) return const OnboardingFlow();

    // Show model download screen once after first onboarding
    if (!_modelSetupDone) {
      return ModelSetupScreen(
        onDone: () async {
          await DatabaseService.instance.updateProfile(
            {'model_setup_done': 1},
            AuthService.instance.currentUser?.id,
          );
          if (mounted) setState(() => _modelSetupDone = true);
        },
      );
    }

    return const AppShell();
  }
}
