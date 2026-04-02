import '../../state/app_state.dart';
import '../../core/constants/app_constants.dart';

class AvatarConfig {
  final String assetPath;
  final double speed;
  final bool   loop;

  const AvatarConfig({
    required this.assetPath,
    required this.speed,
    required this.loop,
  });
}

class AvatarService {
  AvatarService._();

  static const Map<AvatarState, AvatarConfig> configs = {
    AvatarState.idle: AvatarConfig(
      assetPath: AppConstants.lottieIdle,
      speed:     0.8,
      loop:      true,
    ),
    AvatarState.happy: AvatarConfig(
      assetPath: AppConstants.lottieHappy,
      speed:     1.2,
      loop:      false,   // plays once then parent resets to idle
    ),
    AvatarState.stressed: AvatarConfig(
      assetPath: AppConstants.lottieStressed,
      speed:     1.0,
      loop:      true,
    ),
    AvatarState.thinking: AvatarConfig(
      assetPath: AppConstants.lottieThinking,
      speed:     0.9,
      loop:      true,
    ),
  };

  static AvatarConfig getConfig(AvatarState state) {
    return configs[state]!;
  }
}
