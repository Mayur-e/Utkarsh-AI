import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:utkarsh_ai/core/theme/app_theme.dart';
import 'package:utkarsh_ai/core/constants/app_constants.dart';

void main() {
  group('AppColors', () {
    test('primary is Utkarsh green', () {
      expect(AppColors.primary, equals(const Color(0xFF2E7D52)));
    });
    test('background is deep dark', () {
      expect(AppColors.background, equals(const Color(0xFF0F1923)));
    });
    test('all 4 wellbeing risk colors defined', () {
      expect(AppColors.wellbeingGreen,  equals(const Color(0xFF4CAF50)));
      expect(AppColors.wellbeingYellow, equals(const Color(0xFFFFC107)));
      expect(AppColors.wellbeingOrange, equals(const Color(0xFFFF9800)));
      expect(AppColors.wellbeingRed,    equals(const Color(0xFFF44336)));
    });
    test('danger color is correct', () {
      expect(AppColors.error, equals(const Color(0xFFEF5350)));
    });
    test('success color is correct', () {
      expect(AppColors.success, equals(const Color(0xFF66BB6A)));
    });
  });

  group('AppTheme.darkTheme', () {
    test('theme is dark brightness', () {
      expect(AppTheme.darkTheme.brightness, equals(Brightness.dark));
    });
    test('scaffold background is app background color', () {
      expect(
        AppTheme.darkTheme.scaffoldBackgroundColor,
        equals(AppColors.background),
      );
    });
    test('primary color is Utkarsh green', () {
      expect(
        AppTheme.darkTheme.colorScheme.primary,
        equals(AppColors.primary),
      );
    });
  });

  group('AppConstants CWS weights', () {
    test('all 7 CWS weights sum to exactly 1.0', () {
      const weights = [
        AppConstants.cwsWeightEmotion,
        AppConstants.cwsWeightStress,
        AppConstants.cwsWeightTasks,
        AppConstants.cwsWeightActivity,
        AppConstants.cwsWeightRoutine,
        AppConstants.cwsWeightBehavior,
        AppConstants.cwsWeightGrowth,
      ];
      final sum = weights.fold(0.0, (a, b) => a + b);
      expect(sum, closeTo(1.0, 0.0000001));
    });
    test('there are exactly 7 CWS weight factors', () {
      const weights = [
        AppConstants.cwsWeightEmotion,
        AppConstants.cwsWeightStress,
        AppConstants.cwsWeightTasks,
        AppConstants.cwsWeightActivity,
        AppConstants.cwsWeightRoutine,
        AppConstants.cwsWeightBehavior,
        AppConstants.cwsWeightGrowth,
      ];
      expect(weights.length, equals(7));
    });
    test('there are exactly 5 intent classes', () {
      expect(AppConstants.intentClasses.length, equals(5));
    });
    test('intent classes contain stress_help', () {
      expect(AppConstants.intentClasses, contains('stress_help'));
    });
    test('intent classes contain knowledge_query', () {
      expect(AppConstants.intentClasses, contains('knowledge_query'));
    });
  });

  group('AppSpacing', () {
    test('all spacing values are positive', () {
      final values = [
        AppSpacing.xs, AppSpacing.sm, AppSpacing.md,
        AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl,
      ];
      for (final v in values) {
        expect(v, greaterThan(0));
      }
    });
  });
}
