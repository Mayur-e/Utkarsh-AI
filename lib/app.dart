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
  @override
  Widget build(BuildContext context) {
    final isLoggedIn = AuthService.instance.isLoggedIn;
    final isUnlocked = AuthService.instance.isUnlocked;

    if (!isLoggedIn) {
      return const LoginScreen();        // New user or signed out
    }
    
    if (!isUnlocked) {
      return const PinUnlockScreen();   // Returning user needs PIN
    }
    
    return const AppShell();            // Fully authenticated
  }
}
