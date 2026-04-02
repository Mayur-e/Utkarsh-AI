import 'package:flutter_test/flutter_test.dart';
import 'package:utkarsh_ai/services/avatar/avatar_service.dart';
import 'package:utkarsh_ai/state/app_state.dart';
import 'package:utkarsh_ai/core/constants/app_constants.dart';

void main() {
  group('AvatarService.getConfig()', () {
    test('idle state returns idle lottie path', () {
      final config = AvatarService.getConfig(AvatarState.idle);
      expect(config.assetPath, equals(AppConstants.lottieIdle));
    });

    test('idle state loops', () {
      expect(AvatarService.getConfig(AvatarState.idle).loop, isTrue);
    });

    test('happy state does not loop (plays once)', () {
      expect(AvatarService.getConfig(AvatarState.happy).loop, isFalse);
    });

    test('stressed state loops', () {
      expect(AvatarService.getConfig(AvatarState.stressed).loop, isTrue);
    });

    test('thinking state loops', () {
      expect(AvatarService.getConfig(AvatarState.thinking).loop, isTrue);
    });

    test('idle speed is 0.8 (slow and calming)', () {
      expect(AvatarService.getConfig(AvatarState.idle).speed, equals(0.8));
    });

    test('happy speed is 1.2 (energetic)', () {
      expect(AvatarService.getConfig(AvatarState.happy).speed, equals(1.2));
    });

    test('all 4 states have configs defined', () {
      for (final state in AvatarState.values) {
        expect(
          () => AvatarService.getConfig(state),
          returnsNormally,
        );
      }
    });
  });
}
