import 'package:flutter/material.dart';

import '../scan_motion.dart';

/// Whether [context]'s widget is at least partly on screen.
bool isOnScreen(BuildContext context, {double margin = 0}) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return false;
  final top = box.localToGlobal(Offset.zero).dy;
  final height = MediaQuery.sizeOf(context).height;
  return top < height - margin && top + box.size.height > margin;
}

/// Hands [builder] a value from 0 to 1, once, the first time this scrolls into
/// view, so a chart draws itself when someone is actually looking at it. Jumps
/// straight to 1 under reduced motion.
class InViewAnimation extends StatefulWidget {
  const InViewAnimation({
    super.key,
    required this.builder,
    this.duration = const Duration(milliseconds: 1100),
    this.curve = ScanMotion.curve,
  });

  final Widget Function(BuildContext context, double t) builder;
  final Duration duration;
  final Curve curve;

  @override
  State<InViewAnimation> createState() => _InViewAnimationState();
}

class _InViewAnimationState extends State<InViewAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  ScrollPosition? _position;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ScanMotion.reduced(context)) {
      _started = true;
      _detach();
      _c.value = 1;
      return;
    }
    if (_started) return;
    final next = Scrollable.maybeOf(context)?.position;
    if (next != _position) {
      _detach();
      _position = next?..addListener(_check);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_started || !mounted || !isOnScreen(context, margin: 40)) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _detach());
    _c.forward();
  }

  void _detach() {
    _position?.removeListener(_check);
    _position = null;
  }

  @override
  void dispose() {
    _detach();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) =>
          widget.builder(context, widget.curve.transform(_c.value)),
    );
  }
}
