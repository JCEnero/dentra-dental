import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'dentra_glass_ui.dart' show dentraMotion;
import 'dentra_mascot.dart';

/// Lets one Rabi serve a whole guide. Each page marks where he stands with
/// a [MascotSpot]; when the page changes he hops from the old spot to the
/// new one, turning round in the air if he has to face the other way.
///
/// He is drawn above [child], so nothing on the page clips him mid-hop.
/// Standing still inside a scrolling area he is clipped to it, like the
/// content around him.
class MascotStage extends StatefulWidget {
  const MascotStage({super.key, required this.child});

  final Widget child;

  @override
  State<MascotStage> createState() => _MascotStageState();
}

class _StageScope extends InheritedWidget {
  const _StageScope({required this.stage, required super.child});

  final _MascotStageState stage;

  @override
  bool updateShouldNotify(_StageScope old) => false;
}

class _MascotStageState extends State<MascotStage>
    with SingleTickerProviderStateMixin {
  /// Every spot on screen, oldest first. Rabi stands on the newest.
  final List<_MascotSpotState> _spots = [];
  _MascotSpotState? _active;

  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
    value: 1,
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) _remember();
    });

  /// Where the hop started, measured from the spot it ends on.
  Offset _startOffset = Offset.zero;
  double _startSize = 0;
  bool _startMirrored = false;

  /// He is arriving from nowhere, so he pops in instead of hopping.
  bool _arriving = true;

  /// Where he last stood on screen, for when that spot is gone.
  Rect? _lastRect;
  bool _settling = false;

  void _add(_MascotSpotState spot) {
    _spots.add(spot);
    _changed();
  }

  void _remove(_MascotSpotState spot) {
    _spots.remove(spot);
    _changed();
  }

  /// Spots come and go while the page builds, so the move waits until the
  /// frame is laid out and both ends can be measured.
  void _changed() {
    if (_settling) return;
    _settling = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _settle());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _settle() {
    _settling = false;
    if (!mounted) return;
    final next = _spots.isEmpty ? null : _spots.last;
    if (next == _active) {
      // Same spot, perhaps a new mood.
      setState(() {});
      return;
    }
    final from = _standing();
    final to = next?._rect();
    setState(() {
      if (next != null) {
        if (from == null || to == null) {
          _arriving = true;
          _startOffset = Offset.zero;
          _startSize = next.widget.size;
          _startMirrored = next.widget.mirrored;
        } else {
          _arriving = false;
          _startOffset = from.topLeft - to.topLeft;
          _startSize = from.width;
          _startMirrored = _facing();
        }
      }
      _active = next;
      // Gone altogether: next time he arrives afresh, not from here.
      if (next == null) _lastRect = null;
    });
    if (next == null) return;
    if (dentraMotion(context) == Duration.zero) {
      _hop.value = 1;
    } else {
      _hop.forward(from: 0);
    }
  }

  /// Where Rabi is drawn right now, in screen coordinates.
  Rect? _standing() {
    final spot = _active;
    final rect = spot?._rect();
    if (spot == null || rect == null) return _lastRect;
    final (offset, size) = _placeAt(_hop.value, spot.widget.size);
    return (rect.topLeft + offset) & Size.square(size);
  }

  /// Which way he faces right now.
  bool _facing() {
    final spot = _active;
    if (spot == null) return false;
    return _hop.value < 0.5 ? _startMirrored : spot.widget.mirrored;
  }

  /// His offset from the spot he is heading to and his size, [t] of the
  /// way through the hop.
  (Offset, double) _placeAt(double t, double size) {
    if (t >= 1 || _arriving) return (Offset.zero, size);
    final e = Curves.easeInOutCubic.transform(t);
    final arc = (_startOffset.distance * 0.28).clamp(12.0, 54.0);
    return (
      _startOffset * (1 - e) - Offset(0, arc * math.sin(math.pi * t)),
      _startSize + (size - _startSize) * e,
    );
  }

  void _remember() {
    final rect = _active?._rect();
    if (rect != null && _hop.value >= 1) _lastRect = rect;
  }

  @override
  void dispose() {
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keeps his last place fresh, in case his spot leaves without a
    // replacement.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _remember();
    });
    final spot = _active;
    return _StageScope(
      stage: this,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (spot != null)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRect(
                  clipper: _StageClip(this, spot),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        child: AnimatedBuilder(
                          animation: _hop,
                          builder: (context, _) => _rabi(spot),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _rabi(_MascotSpotState spot) {
    final look = spot.widget;
    final t = _hop.value;
    final (offset, size) = _placeAt(t, look.size);

    // Turning round mid-hop: he narrows to nothing and opens out facing
    // the other way.
    final turning = !_arriving && _startMirrored != look.mirrored && t < 1;
    final mirrored = t < 0.5 && turning ? _startMirrored : look.mirrored;
    final turn = turning ? math.cos(math.pi * t).abs().clamp(0.06, 1.0) : 1.0;

    // Arriving: a small pop up from his feet.
    final pop = _arriving ? Curves.easeOutBack.transform(t) : 1.0;

    return CompositedTransformFollower(
      link: spot._link,
      showWhenUnlinked: false,
      offset: offset,
      child: Opacity(
        opacity: _arriving ? Curves.easeOut.transform(t) : 1,
        child: Transform(
          alignment: const Alignment(0, 0.9),
          transform: Matrix4.diagonal3Values(
            turn * (0.7 + 0.3 * pop),
            0.7 + 0.3 * pop,
            1,
          ),
          child: DentraMascot(
            mood: look.mood,
            aim: look.aim,
            size: size,
            mirrored: mirrored,
            stage: look.glow,
            busy: look.busy,
            awake: true,
          ),
        ),
      ),
    );
  }
}

/// Clips Rabi to the scrolling area his spot is in, once he has landed.
class _StageClip extends CustomClipper<Rect> {
  _StageClip(this.stage, this.spot) : super(reclip: stage._hop);

  final _MascotStageState stage;
  final _MascotSpotState spot;

  @override
  Rect getClip(Size size) {
    final all = Offset.zero & size;
    if (stage._hop.value < 1) return all;
    final view = spot._viewport();
    final box = stage.context.findRenderObject();
    if (view == null || box is! RenderBox || !view.attached) return all;
    final rect = view.localToGlobal(Offset.zero, ancestor: box) & view.size;
    return rect.intersect(all);
  }

  @override
  bool shouldReclip(_StageClip old) => true;
}

/// Where Rabi stands on a page, and how. Under a [MascotStage] this only
/// holds his place and the stage's one Rabi comes to it; without a stage
/// it shows him itself.
class MascotSpot extends StatefulWidget {
  const MascotSpot({
    super.key,
    this.mood = MascotMood.wave,
    this.aim = MascotAim.side,
    this.size = 104,
    this.mirrored = false,
    this.busy = false,
    this.glow = false,
  });

  final MascotMood mood;
  final MascotAim aim;
  final double size;

  /// Faces (and points) right instead of left.
  final bool mirrored;

  /// Rings ripple out behind him.
  final bool busy;

  /// A soft mint glow behind him.
  final bool glow;

  @override
  State<MascotSpot> createState() => _MascotSpotState();
}

class _MascotSpotState extends State<MascotSpot> {
  final LayerLink _link = LayerLink();
  _MascotStageState? _stage;

  /// The scrolling area this spot is inside, if any.
  RenderBox? _scroller;

  /// False once this spot is on its way out of the tree, when it can no
  /// longer be measured.
  bool _placed = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stage =
        context.getInheritedWidgetOfExactType<_StageScope>()?.stage;
    if (stage != _stage) {
      _stage?._remove(this);
      _stage = stage?.._add(this);
    }
    final box = Scrollable.maybeOf(context)?.context.findRenderObject();
    _scroller = box is RenderBox ? box : null;
  }

  @override
  void activate() {
    super.activate();
    _placed = true;
  }

  @override
  void deactivate() {
    _placed = false;
    super.deactivate();
  }

  @override
  void didUpdateWidget(MascotSpot old) {
    super.didUpdateWidget(old);
    _stage?._changed();
  }

  @override
  void dispose() {
    _stage?._remove(this);
    super.dispose();
  }

  /// This spot on screen, or null while it has no place yet.
  Rect? _rect() {
    if (!mounted || !_placed) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// The scrolling area to clip Rabi to, while this spot is in place.
  RenderBox? _viewport() => mounted && _placed ? _scroller : null;

  @override
  Widget build(BuildContext context) {
    if (_stage == null) {
      return DentraMascot(
        mood: widget.mood,
        aim: widget.aim,
        size: widget.size,
        mirrored: widget.mirrored,
        busy: widget.busy,
        stage: widget.glow,
        awake: true,
      );
    }
    return CompositedTransformTarget(
      link: _link,
      child: SizedBox.square(dimension: widget.size),
    );
  }
}
