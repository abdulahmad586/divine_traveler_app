import 'package:flutter/material.dart';

/// A progress bar that smoothly tweens to a new [value] whenever it changes,
/// rather than jumping. Drop-in for [LinearProgressIndicator].
class AnimatedProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final Color? backgroundColor;
  final double minHeight;
  final BorderRadius? borderRadius;
  final Duration duration;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.color,
    this.backgroundColor,
    this.minHeight = 6,
    this.borderRadius,
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: animatedValue,
            minHeight: minHeight,
            backgroundColor:
                backgroundColor ?? Colors.grey[200],
            color: color,
          ),
        );
      },
    );
  }
}
