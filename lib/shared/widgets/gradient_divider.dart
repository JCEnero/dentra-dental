import 'package:flutter/material.dart';
import '../../core/constants/app_glass.dart';

/// Subtle divider used between sections.
class GradientDivider extends StatelessWidget {
  const GradientDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: AppGlass.divider,
    );
  }
}
