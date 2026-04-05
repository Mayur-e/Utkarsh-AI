import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:utkarsh_ai/state/app_state.dart';
import 'package:utkarsh_ai/services/cws/cws_engine.dart';

void main() {
  group('emotionToAvatarState()', () {
    test('positive emotion returns happy', () {
      expect(
        emotionToAvatarState(EmotionLabel.positive, 20),
        equals(AvatarState.happy),
      );
    });

    test('negative with stress 80 returns stressed', () {
      expect(
        emotionToAvatarState(EmotionLabel.negative, 80),
        equals(AvatarState.stressed),
      );
    });

    test('negative with stress 40 returns thinking', () {
      expect(
        emotionToAvatarState(EmotionLabel.negative, 40),
        equals(AvatarState.thinking),
      );
    });

    test('negative with stress exactly 60 returns thinking (not > 60)', () {
      expect(
        emotionToAvatarState(EmotionLabel.negative, 60),
        equals(AvatarState.thinking),
      );
    });

    test('negative with stress 61 returns stressed (strictly > 60)', () {
      expect(
        emotionToAvatarState(EmotionLabel.negative, 61),
        equals(AvatarState.stressed),
      );
    });

    test('neutral emotion returns idle', () {
      expect(
        emotionToAvatarState(EmotionLabel.neutral, 0),
        equals(AvatarState.idle),
      );
    });

    test('positive emotion returns happy regardless of stress', () {
      expect(
        emotionToAvatarState(EmotionLabel.positive, 90),
        equals(AvatarState.happy),
      );
    });
  });

  group('Riverpod providers initial state', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('appReadyProvider starts false', () {
      expect(container.read(appReadyProvider), isFalse);
    });

    test('modelsLoadedProvider starts false', () {
      expect(container.read(modelsLoadedProvider), isFalse);
    });

    test('emotionLabelProvider starts neutral', () {
      expect(
        container.read(emotionLabelProvider),
        equals(EmotionLabel.neutral),
      );
    });

    test('stressLevelProvider starts at 0', () {
      expect(container.read(stressLevelProvider), equals(0.0));
    });

    test('avatarStateProvider starts idle', () {
      expect(
        container.read(avatarStateProvider),
        equals(AvatarState.idle),
      );
    });

    test('cwsScoreProvider starts at 70', () {
      expect(container.read(cwsScoreProvider), equals(70.0));
    });

    test('riskLevelProvider starts green', () {
      expect(
        container.read(riskLevelProvider),
        equals(RiskLevel.green),
      );
    });

    test('aiModeProvider starts offline', () {
      expect(container.read(aiModeProvider), equals(AiMode.offline));
    });

    test('isOnlineProvider starts false', () {
      expect(container.read(isOnlineProvider), isFalse);
    });

    test('totalXpProvider starts at 0', () {
      expect(container.read(totalXpProvider), equals(0));
    });

    test('currentLevelProvider starts at Awareness', () {
      expect(container.read(currentLevelProvider), equals('Awareness'));
    });

    test('negativeMessageCountProvider starts at 0', () {
      expect(container.read(negativeMessageCountProvider), equals(0));
    });
  });

  group('Riverpod provider mutations', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('setting emotionLabel updates the value', () {
      container.read(emotionLabelProvider.notifier).state =
          EmotionLabel.negative;
      expect(
        container.read(emotionLabelProvider),
        equals(EmotionLabel.negative),
      );
    });

    test('setting isOnline to true updates aiMode to groq', () {
      container.read(isOnlineProvider.notifier).state = true;
      container.read(aiModeProvider.notifier).state   = AiMode.groq;
      expect(container.read(isOnlineProvider), isTrue);
      expect(container.read(aiModeProvider), equals(AiMode.groq));
    });

    test('incrementing negativeMessageCount works', () {
      container.read(negativeMessageCountProvider.notifier).state = 3;
      expect(container.read(negativeMessageCountProvider), equals(3));
    });

    test('setting cwsScore and riskLevel works', () {
      container.read(cwsScoreProvider.notifier).state  = 45.0;
      container.read(riskLevelProvider.notifier).state = RiskLevel.orange;
      expect(container.read(cwsScoreProvider),  equals(45.0));
      expect(container.read(riskLevelProvider), equals(RiskLevel.orange));
    });
  });

  group('riskLevelColor()', () {
    test('green returns wellbeingGreen color', () {
      expect(
        riskLevelColor(RiskLevel.green),
        equals(const Color(0xFF4CAF50)),
      );
    });
    test('red returns wellbeingRed color', () {
      expect(
        riskLevelColor(RiskLevel.red),
        equals(const Color(0xFFF44336)),
      );
    });
  });

  group('riskLevelLabel()', () {
    test('green returns Stable',         () => expect(riskLevelLabel(RiskLevel.green),  equals('Stable')));
    test('yellow returns Mild Stress',   () => expect(riskLevelLabel(RiskLevel.yellow), equals('Mild Stress')));
    test('orange returns Elevated Risk', () => expect(riskLevelLabel(RiskLevel.orange), equals('Elevated Risk')));
    test('red returns High Risk',        () => expect(riskLevelLabel(RiskLevel.red),    equals('High Risk')));
  });
}
