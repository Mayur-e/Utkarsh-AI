import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../state/app_state.dart';
import '../../../services/avatar/avatar_service.dart';

class AvatarDisplay extends StatefulWidget {
  final AvatarState state;
  final double      size;
  final VoidCallback? onHappyComplete;

  const AvatarDisplay({
    super.key,
    required this.state,
    this.size = 140,
    this.onHappyComplete,
  });

  @override
  State<AvatarDisplay> createState() => _AvatarDisplayState();
}

class _AvatarDisplayState extends State<AvatarDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _startAnimation();
  }

  @override
  void didUpdateWidget(AvatarDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    if (_controller.duration == null) return;
    
    final config = AvatarService.getConfig(widget.state);
    _controller.reset();
    if (config.loop) {
      _controller.repeat();
    } else {
      _controller.forward().then((_) {
        widget.onHappyComplete?.call();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = AvatarService.getConfig(widget.state);
    return SizedBox(
      width:  widget.size,
      height: widget.size,
      child: Lottie.asset(
        config.assetPath,
        controller:  _controller,
        width:       widget.size,
        height:      widget.size,
        fit:         BoxFit.contain,
        onLoaded: (composition) {
          _controller.duration = Duration(
            milliseconds: (composition.duration.inMilliseconds / config.speed).round(),
          );
          _startAnimation();
        },
      ),
    );
  }
}
