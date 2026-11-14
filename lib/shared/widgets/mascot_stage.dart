import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'dentra_glass_ui.dart' show dentraMotion;
import 'dentra_mascot.dart';

/// How Rabi comes and goes: a pop and a poof, both the moment he is called
/// for. He springs up from between his feet with a quick overshoot while a
/// ring pops out round him, and vanishes by shrinking into a little puff of
/// mint cloud. He never slides.
abstract final class MascotPop {
  static const Duration enter = Duration(milliseconds: 340);

  /// Long enough for the puff to burst and fade; he himself is gone within
  /// the first [_gone] of it.
  static const Duration leave = Duration(milliseconds: 380);
  static const double _gone = 0.4;

  /// He grows from between his feet, where his shadow is, so he lands on
  /// the spot rather than dropping onto it.
  static const Alignment _feet = Alignment(0, 0.91);

  /// He shrinks into the middle of his body, where the puff bursts.
  static const Alignment _heart = Alignment(0, 0.12);

  /// Shoots about 6% past full size and snaps back: a pop.
  static const Curve _pop = Cubic(0.3, 1.5, 0.6, 1);

  /// His scale and opacity [t] of the way through appearing.
  static (double, double) appearing(double t) => (
        0.2 + 0.8 * _pop.transform(t),
        Curves.easeOut.transform((t / 0.25).clamp(0.0, 1.0)),
      );

  /// His scale and opacity [t] of the way through leaving, starting from
  /// [scale] and [opacity] (he can leave before he has fully appeared).
  static (double, double) leaving(
    double t, {
    double scale = 1,
    double opacity = 1,
  }) {
    final p = (t / _gone).clamp(0.0, 1.0);
    return (
      scale + (0.15 - scale) * Curves.easeIn.transform(p),
      opacity * (1 - Curves.easeInCubic.transform(p)),
    );
  }

  static Widget _scaled(
    (double, double) look,
    Alignment from,
    Widget child,
  ) {
    final (scale, opacity) = look;
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(scale: scale, alignment: from, child: child),
    );
  }

  /// [rabi] [t] of the way through popping in, with the ring behind him.
  static Widget appear(double t, Widget rabi) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _PopPainter(t, vanish: false)),
        ),
        _scaled(appearing(t), _feet, rabi),
      ],
    );
  }

  /// [rabi] [t] of the way through vanishing, the puff in front of him.
  static Widget vanish(
    double t,
    Widget rabi, {
    double scale = 1,
    double opacity = 1,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _scaled(leaving(t, scale: scale, opacity: opacity), _heart, rabi),
        Positioned.fill(
          child: CustomPaint(
            painter: _PopPainter(t, vanish: true, strength: opacity),
          ),
        ),
      ],
    );
  }
}

/// The ring that pops out as Rabi lands, or the puff he vanishes into,
/// laid out from the square he stands in.
class _PopPainter extends CustomPainter {
  const _PopPainter(this.t, {required this.vanish, this.strength = 1});

  final double t;
  final bool vanish;

  /// How much of him there was to vanish (he may go before he has fully
  /// appeared).
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final s = size.shortestSide;
    final c = Offset(size.width / 2, s * 0.56);

    if (!vanish) {
      final p = (t / 0.75).clamp(0.0, 1.0);
      if (p >= 1) return;
      final e = Curves.easeOutCubic.transform(p);
      canvas.drawCircle(
        c,
        s * (0.2 + 0.32 * e),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8 + s * 0.022 * (1 - p)
          ..color = AppColors.g1.withValues(alpha: 0.55 * (1 - p)),
      );
      return;
    }

    // Blooms as he shrinks into it, and outlasts him.
    final p = ((t - 0.12) / 0.88).clamp(0.0, 1.0);
    if (p <= 0) return;
    final e = Curves.easeOutCubic.transform(p);
    final alpha = strength *
        (p / 0.18).clamp(0.0, 1.0) *
        (1 - Curves.easeIn.transform(p));
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.g1.withValues(alpha: 0.4 * alpha);
    Paint fill(int i) => Paint()
      ..color = (i.isEven ? AppColors.white : AppColors.mintGreen)
          .withValues(alpha: 0.95 * alpha);

    // The cloud where he was, swelling as it thins out...
    const cloud = [(-0.08, 0.02), (0.08, 0.03), (0.0, -0.06)];
    for (var i = 0; i < cloud.length; i++) {
      final (x, y) = cloud[i];
      final at = c + Offset(x * s, y * s) * (0.6 + 0.8 * e);
      final r = s * (0.05 + 0.09 * e) * (1 - 0.35 * p);
      canvas
        ..drawCircle(at, r, fill(i))
        ..drawCircle(at, r, rim);
    }

    // ...little puffs bursting out of it, drifting up a touch...
    for (var i = 0; i < 8; i++) {
      final a = i / 8 * 2 * math.pi - math.pi / 2 + 0.35;
      final reach = s * (0.1 + (0.28 + 0.05 * (i % 3)) * e);
      final at = c +
          Offset(math.cos(a), math.sin(a)) * reach -
          Offset(0, s * 0.05 * e);
      final r = s * (0.045 + 0.014 * (i % 3)) * (1 - 0.5 * p);
      canvas
        ..drawCircle(at, r, fill(i + 1))
        ..drawCircle(at, r, rim);
    }

    // ...and a ring going out round them.
    canvas.drawCircle(
      c,
      s * (0.16 + 0.3 * e),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, s * 0.018 * (1 - p))
        ..color = AppColors.g1.withValues(alpha: 0.4 * alpha),
    );
  }

  @override
  bool shouldRepaint(_PopPainter old) =>
      old.t != t || old.vanish != vanish || old.strength != strength;
}

/// Lets one Rabi serve a whole guide. Each page marks where he stands with
/// a [MascotSpot]. When the page changes he vanishes in a puff where he
/// stood and, in the same moment, pops up on the new spot, held where the
/// new page will come to rest while it slides in. He is never seen moving
/// across the screen.
///
/// He is drawn above [child], so nothing on the page clips him while he
/// grows. Inside a scrolling area he is clipped to it, like the content
/// around him.
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

/// Marks a page of a guide as the one showing ([current]) or one on its
/// way out. Rabi only appears on spots of the current page, so he never
/// stops on a page that is leaving, even when the page is rebuilt as it
/// goes. Spots outside any [MascotScene] count as current.
class MascotScene extends InheritedWidget {
  const MascotScene({
    super.key,
    required this.current,
    this.shift,
    required super.child,
  });

  final bool current;

  /// How far the page is slid, as a part of its size: what its
  /// [SlideTransition] is given. Rabi pops up where the page will come to
  /// rest instead of sliding in with it.
  final Animation<Offset>? shift;

  @override
  bool updateShouldNotify(MascotScene old) =>
      old.current != current || old.shift != shift;
}

/// Rabi on his way out: where he stood and how he looked, frozen.
class _Leaving {
  const _Leaving({
    required this.look,
    required this.rect,
    required this.clip,
    required this.scale,
    required this.opacity,
    required this.key,
  });

  final MascotSpot look;

  /// Where he stood, in the stage's coordinates.
  final Rect rect;

  /// The scrolling area he was clipped to, if any.
  final Rect? clip;
  final double scale;
  final double opacity;

  /// The same key he had on his spot, so he keeps his pose as he goes.
  final GlobalKey key;
}

class _MascotStageState extends State<MascotStage>
    with TickerProviderStateMixin {
  /// Every spot on screen, oldest first. Rabi belongs on the newest
  /// current one.
  final List<_MascotSpotState> _spots = [];

  /// The spot he is on.
  _MascotSpotState? _on;

  /// Set while he vanishes where he last stood.
  _Leaving? _leaving;

  /// The Rabi on screen. Kept across the move from following his spot to
  /// vanishing where he stood, so his pose carries on; a new one for each
  /// spot he appears on.
  GlobalKey _rabiKey = GlobalKey();

  late final AnimationController _appear = AnimationController(
    vsync: this,
    duration: MascotPop.enter,
  );

  late final AnimationController _leave = AnimationController(
    vsync: this,
    duration: MascotPop.leave,
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _leaving = null);
      }
    });

  /// Where he last stood and what clipped him, in the stage's coordinates,
  /// for when his spot leaves before it can be measured.
  Rect? _lastRect;
  Rect? _lastClip;

  bool _settling = false;

  bool get _still => dentraMotion(context) == Duration.zero;

  void _add(_MascotSpotState spot) {
    _spots.add(spot);
    _changed();
  }

  void _remove(_MascotSpotState spot) {
    _spots.remove(spot);
    _changed();
  }

  /// Spots come and go while the page builds, so the change waits until
  /// the frame is laid out and the spots can be measured.
  void _changed() {
    if (_settling) return;
    _settling = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _settle());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _settle() {
    _settling = false;
    if (!mounted) return;
    final current = _spots.where((s) => s._current);
    final next = current.isEmpty ? null : current.last;
    if (next == _on) {
      // Same spot, perhaps a new mood: he changes pose where he stands.
      setState(() {});
      return;
    }
    // Out where he was and in where he is wanted, at the same moment.
    final on = _on;
    final leaving = on == null ? null : _leavingFrom(on);
    setState(() {
      if (on != null) _leaving = leaving;
      _on = next;
      _rabiKey = GlobalKey();
    });
    if (leaving != null) _leave.forward(from: 0);
    if (next != null) {
      if (_still) {
        _appear.value = 1;
      } else {
        _appear.forward(from: 0);
      }
    }
  }

  /// Rabi frozen as he stands on [on], ready to vanish; null when there is
  /// nothing to see go.
  _Leaving? _leavingFrom(_MascotSpotState on) {
    final rect = _drawn(on) ?? _lastRect;
    final (scale, opacity) = _appear.isAnimating
        ? MascotPop.appearing(_appear.value)
        : (1.0, _appear.value);
    _appear.stop();
    if (_still || rect == null || opacity <= 0.01) return null;
    return _Leaving(
      look: on.widget,
      rect: rect,
      clip: _clipOf(on) ?? _lastClip,
      scale: scale,
      opacity: opacity,
      key: _rabiKey,
    );
  }

  Rect? _toStage(Rect global) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.globalToLocal(global.topLeft) & global.size;
  }

  /// Where Rabi is drawn on [spot], in the stage's coordinates: the spot,
  /// less however far its page is still sliding.
  Rect? _drawn(_MascotSpotState spot) {
    final global = spot._rect();
    if (global == null) return null;
    return _toStage(global.shift(-spot._slide()));
  }

  /// The scrolling area [spot] is in, in the stage's coordinates.
  Rect? _clipOf(_MascotSpotState spot) {
    final view = spot._viewport();
    if (view == null || !view.attached || !view.hasSize) return null;
    return _toStage(view.localToGlobal(Offset.zero) & view.size);
  }

  void _remember() {
    final on = _on;
    if (on == null) return;
    final rect = _drawn(on);
    if (rect == null) return;
    _lastRect = rect;
    _lastClip = _clipOf(on);
  }

  @override
  void dispose() {
    _appear.dispose();
    _leave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keeps his last place fresh, in case his spot leaves before it can
    // be measured.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _remember();
    });
    final on = _on;
    final leaving = _leaving;
    final shift = on?._shift;
    return _StageScope(
      stage: this,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // A scroll moves him with his spot; note where he ends up.
          NotificationListener<ScrollEndNotification>(
            onNotification: (_) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _remember();
              });
              return false;
            },
            child: widget.child,
          ),
          if (leaving != null)
            Positioned.fill(
              key: const ValueKey('leaving'),
              child: IgnorePointer(
                child: ClipRect(
                  clipper: _FixedClip(leaving.clip),
                  child: Stack(
                    children: [
                      Positioned.fromRect(
                        rect: leaving.rect,
                        child: AnimatedBuilder(
                          animation: _leave,
                          builder: (context, rabi) => MascotPop.vanish(
                            _leave.value,
                            rabi!,
                            scale: leaving.scale,
                            opacity: leaving.opacity,
                          ),
                          child: _rabi(leaving.look, leaving.key),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (on != null)
            Positioned.fill(
              key: const ValueKey('on'),
              child: IgnorePointer(
                child: ClipRect(
                  clipper: _StageClip(this, on),
                  child: Stack(
                    children: [
                      // Linked, he stands on his spot. In the one frame
                      // where his page is rebuilt before he can vanish, he
                      // holds his last place rather than blinking out.
                      Positioned(
                        left: _lastRect?.left ?? 0,
                        top: _lastRect?.top ?? 0,
                        child: AnimatedBuilder(
                          animation: Listenable.merge(
                              [_appear, if (shift != null) shift]),
                          builder: (context, rabi) =>
                              CompositedTransformFollower(
                            link: on._link,
                            showWhenUnlinked: _lastRect != null,
                            // Holds him where his page will come to rest.
                            offset: -on._slide(),
                            child: MascotPop.appear(_appear.value, rabi!),
                          ),
                          child: _rabi(on.widget, _rabiKey),
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

  Widget _rabi(MascotSpot look, GlobalKey key) {
    return DentraMascot(
      key: key,
      mood: look.mood,
      aim: look.aim,
      size: look.size,
      mirrored: look.mirrored,
      stage: look.glow,
      busy: look.busy,
      awake: true,
    );
  }
}

/// Clips Rabi to the scrolling area his spot is in.
class _StageClip extends CustomClipper<Rect> {
  _StageClip(this.stage, this.spot);

  final _MascotStageState stage;
  final _MascotSpotState spot;

  @override
  Rect getClip(Size size) {
    final all = Offset.zero & size;
    return stage._clipOf(spot)?.intersect(all) ?? all;
  }

  @override
  bool shouldReclip(_StageClip old) => true;
}

/// Keeps Rabi clipped as he was while he vanishes.
class _FixedClip extends CustomClipper<Rect> {
  const _FixedClip(this.clip);

  final Rect? clip;

  @override
  Rect getClip(Size size) {
    final all = Offset.zero & size;
    return clip?.intersect(all) ?? all;
  }

  @override
  bool shouldReclip(_FixedClip old) => old.clip != clip;
}

/// Where Rabi stands on a page, and how. Under a [MascotStage] this only
/// holds his place and the stage's one Rabi pops up on it; without a stage
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

  /// False while the page this spot is on is leaving.
  bool _current = true;

  /// The page this spot is on, and how far it is slid.
  Element? _scene;
  Animation<Offset>? _shift;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scene = context.dependOnInheritedWidgetOfExactType<MascotScene>();
    final current = scene?.current ?? true;
    _shift = scene?.shift;
    _scene = scene == null
        ? null
        : context.getElementForInheritedWidgetOfExactType<MascotScene>();
    final stage =
        context.getInheritedWidgetOfExactType<_StageScope>()?.stage;
    if (stage != _stage) {
      _current = current;
      _stage?._remove(this);
      _stage = stage?.._add(this);
    } else if (current != _current) {
      _current = current;
      _stage?._changed();
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

  /// How far this spot's page is still sliding in, in pixels.
  Offset _slide() {
    final shift = _shift;
    final page = mounted && _placed ? _scene?.findRenderObject() : null;
    if (shift == null || page is! RenderBox || !page.hasSize) {
      return Offset.zero;
    }
    final f = shift.value;
    return Offset(f.dx * page.size.width, f.dy * page.size.height);
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
