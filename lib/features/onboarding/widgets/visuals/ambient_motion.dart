import 'package:flutter/widgets.dart';

/// Drives a slow, looping 0→1 value for ambient illustration motion.
///
/// Only ticks while [active] (the visible slide) and the platform has not
/// requested reduced motion. Otherwise it holds at [restingValue], so every
/// illustration still renders a complete, meaningful frame.
class AmbientMotion extends StatefulWidget {
  const AmbientMotion({
    super.key,
    required this.active,
    required this.period,
    required this.builder,
    this.restingValue = 0.25,
    this.child,
  });

  final bool active;
  final Duration period;
  final double restingValue;
  final ValueWidgetBuilder<double> builder;

  /// Static subtree passed through to [builder] so it is not rebuilt per frame.
  final Widget? child;

  @override
  State<AmbientMotion> createState() => _AmbientMotionState();
}

class _AmbientMotionState extends State<AmbientMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
    value: widget.restingValue,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AmbientMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _controller.duration = widget.period;
    }
    _sync();
  }

  void _sync() {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.active && !reduceMotion) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = widget.restingValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) =>
          widget.builder(context, _controller.value, child),
    );
  }
}
