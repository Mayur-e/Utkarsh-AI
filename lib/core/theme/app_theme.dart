import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // Primary Tier
  static const Color primary = Color(0xFF4f46e5);
  static const Color onPrimary = Color(0xFFffffff);
  static const Color primaryContainer = Color(0xFF4f46e5);
  static const Color onPrimaryContainer = Color(0xFFffffff);
  static const Color primaryFixed = Color(0xFFe0e7ff);
  static const Color primaryFixedDim = Color(0xFFc7d2fe);

  // Secondary Tier
  static const Color secondary = Color(0xFF6366f1);
  static const Color onSecondary = Color(0xFFffffff);
  static const Color secondaryContainer = Color(0xFFe0e7ff);
  static const Color onSecondaryContainer = Color(0xFF4338ca);
  static const Color secondaryFixed = Color(0xFFe0e7ff);
  static const Color secondaryFixedDim = Color(0xFFc7d2fe);

  // Tertiary Tier
  static const Color tertiary = Color(0xFFf97316);
  static const Color onTertiary = Color(0xFFffffff);
  static const Color tertiaryContainer = Color(0xFFffedd5);
  static const Color onTertiaryContainer = Color(0xFF9a3412);
  static const Color tertiaryFixed = Color(0xFFffedd5);
  static const Color tertiaryFixedDim = Color(0xFFfed7aa);

  // Error Tier
  static const Color error = Color(0xFFef4444);
  static const Color onError = Color(0xFFffffff);
  static const Color errorContainer = Color(0xFFfee2e2);
  static const Color onErrorContainer = Color(0xFF991b1b);

  // Surface & Background
  static const Color background = Color(0xFFf8fafc);
  static const Color onBackground = Color(0xFF0f172a);
  static const Color surface = Color(0xFFffffff);
  static const Color onSurface = Color(0xFF0f172a);
  static const Color surfaceVariant = Color(0xFFf1f5f9);
  static const Color onSurfaceVariant = Color(0xFF475569);
  static const Color inverseSurface = Color(0xFF1e293b);
  static const Color inverseOnSurface = Color(0xFFf1f5f9);
  static const Color inversePrimary = Color(0xFFc7d2fe);

  // Generics & Outlines
  static const Color outline = Color(0xFFcbd5e1);
  static const Color outlineVariant = Color(0xFFe2e8f0);

  // Surface Environs
  static const Color surfaceContainerLowest = Color(0xFFffffff);
  static const Color surfaceContainerLow = Color(0xFFffffff);
  static const Color surfaceContainer = Color(0xFFffffff);
  static const Color surfaceContainerHigh = Color(0xFFf1f5f9);
  static const Color surfaceContainerHighest = Color(0xFFe2e8f0);
  static const Color surfaceBright = Color(0xFFffffff);
  static const Color surfaceDim = Color(0xFFf8fafc);
  static const Color surfaceTint = Color(0xFF4f46e5);

  // Status Extras
  static const Color success = Color(0xFF10b981);
  static const Color warning = Color(0xFFf59e0b);
  
  static const Color wellbeingGreen = Color(0xFF10b981);
  static const Color wellbeingYellow = Color(0xFFf59e0b);
  static const Color wellbeingOrange = Color(0xFFf97316);
  static const Color wellbeingRed = Color(0xFFef4444);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Colors.transparent;

  // Legacy Aliases for unmigrated screens
  static const Color text = onSurface;
  static const Color textSecondary = onSurfaceVariant;
  static const Color textMuted = Color(0xFF64748b);
  static const Color textInverse = surface;
  static const Color surfaceElevated = surfaceContainerHigh;
  static const Color surfaceHighlight = surfaceContainerHighest;
  static const Color danger = error;
  static const Color accent = tertiary;
  static const Color primaryLight = primaryFixed;
  static const Color primaryDark = onPrimary;
}

class PrismShadows {
  PrismShadows._();
  
  // Indigo Ethereal ambient soft shadow
  static final List<BoxShadow> ambientShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      offset: const Offset(0, 4),
      blurRadius: 15,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: const Color(0xFF4F46E5).withOpacity(0.04),
      offset: const Offset(0, 10),
      blurRadius: 25,
      spreadRadius: -5,
    ),
  ];
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
  static const double xl = 16; // Indigo Ethereal bento minimum is 1rem (16px) instead of 24
  static const double xxl = 24;
  static const double full = 9999; // Pill / Pin controls
}

class AppTypography {
  AppTypography._();

  static TextStyle get display => GoogleFonts.plusJakartaSans(
    letterSpacing: -0.02,
    color: AppColors.onSurface,
  );

  static TextStyle get functional => GoogleFonts.inter(
    color: AppColors.onSurface,
  );

  // Indigo Ethereal recommends Plus Jakarta Sans for Headers (Display scale)
  static TextStyle get displayLg => display.copyWith(fontSize: 48, fontWeight: FontWeight.w800);
  static TextStyle get displayMd => display.copyWith(fontSize: 36, fontWeight: FontWeight.w800);
  static TextStyle get displaySm => display.copyWith(fontSize: 28, fontWeight: FontWeight.w800);

  static TextStyle get headlineLg => display.copyWith(fontSize: 24, fontWeight: FontWeight.w700);
  static TextStyle get headlineMd => display.copyWith(fontSize: 20, fontWeight: FontWeight.w700);
  static TextStyle get headlineSm => display.copyWith(fontSize: 18, fontWeight: FontWeight.w700);

  // Indigo Ethereal recommends Inter for Content
  static TextStyle get titleLg => functional.copyWith(fontSize: 18, fontWeight: FontWeight.w600);
  static TextStyle get titleMd => functional.copyWith(fontSize: 16, fontWeight: FontWeight.w600);
  static TextStyle get titleSm => functional.copyWith(fontSize: 14, fontWeight: FontWeight.w600);

  static TextStyle get bodyLg => functional.copyWith(fontSize: 16, fontWeight: FontWeight.w400);
  static TextStyle get bodyMd => functional.copyWith(fontSize: 14, fontWeight: FontWeight.w400);
  static TextStyle get bodySm => functional.copyWith(fontSize: 12, fontWeight: FontWeight.w400);

  static TextStyle get labelLg => functional.copyWith(fontSize: 14, fontWeight: FontWeight.w500);
  static TextStyle get labelMd => functional.copyWith(fontSize: 12, fontWeight: FontWeight.w500);
  static TextStyle get labelSm => functional.copyWith(fontSize: 10, fontWeight: FontWeight.w500);

  // Legacy Aliases
  static TextStyle get h1 => displayMd;
  static TextStyle get h2 => displaySm;
  static TextStyle get h3 => headlineLg;
  static TextStyle get h4 => titleLg;
  static TextStyle get bodyLarge => bodyLg;
  static TextStyle get bodyMedium => bodyMd;
  static TextStyle get bodySmall => bodySm;
  static TextStyle get bodyBold => bodyMd.copyWith(fontWeight: FontWeight.w700);
  static TextStyle get labelSmall => labelSm;
}

class AppTheme {
  // Use Indigo Ethereal Background
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: AppColors.onPrimary,
        onSecondary: AppColors.onSecondary,
        onSurface: AppColors.onSurface,
        onError: AppColors.onError,
      ),
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: AppColors.onSurface,
        displayColor: AppColors.onSurface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full), // Pill shape 
          ),
          elevation: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
    );
  }

  // Temporary alias for legacy
  @Deprecated('Use ThemeData instead.')
  static ThemeData get darkTheme => lightTheme;
}
