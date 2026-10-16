import 'package:flutter/widgets.dart';

/// Shared timing for scan animations, so every transition feels related.
/// Every duration collapses to zero when the platform asks for reduced
/// motion.
abstract class ScanMotion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);

  static const Curve curve = Curves.easeOutCubic;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;

  /// Fade with a slight rise, for content swapped in place.
  static Widget fadeRise(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(parent: animation, curve: curve);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
            .animate(curved),
        child: child,
      ),
    );
  }
}
