import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'navigation/app_router.dart';
import 'services/auth/auth_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/pin_unlock_screen.dart';

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
          '/login':  (context) => const LoginScreen(),
          '/home':   (context) => const AppShell(),
          '/unlock': (context) => const PinUnlockScreen(),
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

  @override
  void initState() {
    super.initState();
    _checkAutoUnlock();
  }

  Future<void> _checkAutoUnlock() async {
    final auth = AuthService.instance;
    // If logged in but key not in memory, try auto-unlock with saved PIN
    if (auth.isLoggedIn && !auth.isUnlocked) {
      await auth.tryAutoUnlock();
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
    
    return const AppShell();            // Fully authenticated
  }
}
