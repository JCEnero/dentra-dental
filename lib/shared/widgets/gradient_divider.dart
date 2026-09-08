import 'package:flutter/material.dart';

/// Subtle divider used on gradient backgrounds.
class GradientDivider extends StatelessWidget {
  const GradientDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: Colors.white.withValues(alpha: 0.10),
    );
  }
}
