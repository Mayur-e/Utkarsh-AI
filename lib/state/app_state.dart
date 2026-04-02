import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

import '../models/intent.dart';

// ── Enums ──────────────────────────────────────────────────

enum EmotionLabel { positive, neutral, negative }

enum AvatarState { idle, happy, stressed, thinking }

enum RiskLevel { green, yellow, orange, red }

enum AiMode { offline, groq }

// ── App readiness providers ────────────────────────────────

final appReadyProvider = StateProvider<bool>((ref) => false);

final modelsLoadedProvider = StateProvider<bool>((ref) => false);

// ── Layer 2: Emotion ───────────────────────────────────────

final emotionLabelProvider =
    StateProvider<EmotionLabel>((ref) => EmotionLabel.neutral);

final stressLevelProvider = StateProvider<double>((ref) => 0.0);

// ── Layer 3: Intent ────────────────────────────────────────

final currentIntentProvider = StateProvider<IntentClass>((ref) => IntentClass.casual);

// ── Layer 6: CWS ──────────────────────────────────────────

final cwsScoreProvider = StateProvider<double>((ref) => 70.0);

final riskLevelProvider = StateProvider<RiskLevel>((ref) => RiskLevel.green);

// ── Layer 7: AI Mode ───────────────────────────────────────

final isOnlineProvider = StateProvider<bool>((ref) => false);

final aiModeProvider = StateProvider<AiMode>((ref) => AiMode.offline);

// ── Avatar ─────────────────────────────────────────────────

final avatarStateProvider =
    StateProvider<AvatarState>((ref) => AvatarState.idle);

// ── Session ────────────────────────────────────────────────

final sessionIdProvider = StateProvider<String>(
  (ref) => 'session_${DateTime.now().millisecondsSinceEpoch}',
);

final negativeMessageCountProvider = StateProvider<int>((ref) => 0);

final chatRefreshProvider = StateProvider<int>((ref) => 0);

// ── XP and Level ──────────────────────────────────────────

final totalXpProvider = StateProvider<int>((ref) => 0);

final currentLevelProvider =
    StateProvider<String>((ref) => 'Awareness');

// ── Derived: emotion → avatar state ───────────────────────
// Pure function — not a provider. Call it anywhere.

AvatarState emotionToAvatarState(EmotionLabel emotion, double stress) {
  if (emotion == EmotionLabel.positive) return AvatarState.happy;
  if (emotion == EmotionLabel.negative && stress > 60) {
    return AvatarState.stressed;
  }
  if (emotion == EmotionLabel.negative) return AvatarState.thinking;
  return AvatarState.idle;
}

// ── Risk level color helper ────────────────────────────────

Color riskLevelColor(RiskLevel level) {
  switch (level) {
    case RiskLevel.green:  return AppColors.wellbeingGreen;
    case RiskLevel.yellow: return AppColors.wellbeingYellow;
    case RiskLevel.orange: return AppColors.wellbeingOrange;
    case RiskLevel.red:    return AppColors.wellbeingRed;
  }
}

String riskLevelLabel(RiskLevel level) {
  switch (level) {
    case RiskLevel.green:  return 'Stable';
    case RiskLevel.yellow: return 'Mild Stress';
    case RiskLevel.orange: return 'Elevated Risk';
    case RiskLevel.red:    return 'High Risk';
  }
}
