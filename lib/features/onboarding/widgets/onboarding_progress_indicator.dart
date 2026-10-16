import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Understated pagination: small white dots, with the current step drawn as
/// a short pill.
class OnboardingProgressIndicator extends StatelessWidget {
  const OnboardingProgressIndicator({
    super.key,
    required this.count,
    required this.current,
  });

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 320);

    return Semantics(
      label: 'Step ${current + 1} of $count',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutCubic,
                margin: EdgeInsets.only(right: i == count - 1 ? 0 : 6),
                width: i == current ? 22 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == current
                      ? AppColors.white
                      : AppColors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
