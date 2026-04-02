import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF2E7D52);
  static const Color primaryLight = Color(0xFF4CAF78);
  static const Color primaryDark = Color(0xFF1B5E38);

  // Backgrounds
  static const Color background = Color(0xFF0F1923);
  static const Color surface = Color(0xFF1A2332);
  static const Color surfaceElevated = Color(0xFF243040);
  static const Color surfaceHighlight = Color(0xFF2D3A4A);

  // Text
  static const Color text = Color(0xFFE8F5E9);
  static const Color textSecondary = Color(0xFF9ABFAA);
  static const Color textMuted = Color(0xFF607B70);

  // Accent and status
  static const Color accent = Color(0xFF64FFDA);
  static const Color success = Color(0xFF66BB6A);
  static const Color warning = Color(0xFFFFB74D);
  static const Color danger = Color(0xFFEF5350);
  static const Color info = Color(0xFF42A5F5);

  // Wellbeing risk levels
  static const Color wellbeingGreen = Color(0xFF4CAF50);
  static const Color wellbeingYellow = Color(0xFFFFC107);
  static const Color wellbeingOrange = Color(0xFFFF9800);
  static const Color wellbeingRed = Color(0xFFF44336);

  // Utility
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Colors.transparent;
}

class AppFontSizes {
  AppFontSizes._();
  static const double xs = 11;
  static const double sm = 13;
  static const double md = 15;
  static const double lg = 18;
  static const double xl = 22;
  static const double xxl = 28;
  static const double xxxl = 36;
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}

class AppRadius {
  AppRadius._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double full = 999;
}

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.danger,
        onPrimary: AppColors.white,
        onSecondary: AppColors.black,
        onSurface: AppColors.text,
        onError: AppColors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: AppFontSizes.lg,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontSize: AppFontSizes.xs,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: AppFontSizes.xs,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w800,
        ),
        displayMedium: TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: AppColors.text, fontSize: AppFontSizes.md),
        bodyMedium: TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppFontSizes.sm,
        ),
        labelSmall: TextStyle(
          color: AppColors.textMuted,
          fontSize: AppFontSizes.xs,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.surfaceElevated,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}
