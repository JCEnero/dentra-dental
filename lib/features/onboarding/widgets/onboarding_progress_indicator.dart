import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Page dots that follow the swipe: the slide in view stretches into a
/// short teal bar, and the bar flows to the next dot as the page moves.
class OnboardingProgressIndicator extends StatelessWidget {
  const OnboardingProgressIndicator({
    super.key,
    required this.controller,
    required this.count,
    required this.current,
  });

  final PageController controller;
  final int count;

  /// The settled slide, for screen readers.
  final int current;

  static const double _dot = 7;
  static const double _bar = 26;
  static const double _gap = 7;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Slide ${current + 1} of $count',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          var page = current.toDouble();
          if (controller.hasClients && controller.position.haveDimensions) {
            page = controller.page ?? page;
          }
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                _Dot(weight: (1 - (page - i).abs()).clamp(0.0, 1.0)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.weight});

  /// 1 for the slide in view, easing to 0 a slide away.
  final double weight;

  @override
  Widget build(BuildContext context) {
    const dot = OnboardingProgressIndicator._dot;
    return Container(
      width: lerpDouble(dot, OnboardingProgressIndicator._bar, weight),
      height: dot,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(dot / 2),
        gradient: LinearGradient(
          colors: [
            Color.lerp(AppColors.g2.withValues(alpha: 0.2), AppColors.g1,
                weight)!,
            Color.lerp(
                AppColors.g2.withValues(alpha: 0.2), AppColors.g2, weight)!,
          ],
        ),
      ),
    );
  }
}
