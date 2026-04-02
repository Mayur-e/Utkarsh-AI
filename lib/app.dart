import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'navigation/app_router.dart';
import 'services/auth/auth_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/pin_unlock_screen.dart';
import 'features/onboarding/screens/onboarding_flow.dart';
import 'services/storage/database_service.dart';

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
          '/login':      (context) => const LoginScreen(),
          '/home':       (context) => const AppShell(),
          '/unlock':     (context) => const PinUnlockScreen(),
          '/onboarding': (context) => const OnboardingFlow(),
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
  bool _isInit = true;
  bool _onboardingDone = false;

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
    
    // 2. Profile Check
    if (auth.isUnlocked) {
      final profile = await DatabaseService.instance.getProfile();
      if (profile != null) {
        _onboardingDone = profile['onboarding_done'] == 1;
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

    if (!isLoggedIn) {
      return const LoginScreen();        // New user or signed out
    }
    
    if (!isUnlocked) {
      return const PinUnlockScreen();   // PIN fallback if auto-unlock fails/missing
    }
    
    if (!_onboardingDone) {
      return const OnboardingFlow();   // Profile needs to be built
    }
    
    return const AppShell();            // Fully authenticated
  }
}
