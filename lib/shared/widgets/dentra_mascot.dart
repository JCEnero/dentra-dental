import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// What Rabi, the DENTRA mascot, is doing. Each mood is the same render in
/// a different pose (`assets/images/mascot/`), so he stays one character.
enum MascotMood {
  /// Smiling with a raised hand: hello, and friendly empty pages.
  wave('wave'),

  /// An arm held out toward what matters next.
  point('point'),

  /// Hand on chin while something is under way.
  think('think'),

  /// Both arms up and a happy squint: it worked.
  cheer('cheer'),

  /// Ears down and a small frown: something went wrong, try again.
  worried('worried');

  const MascotMood(this._name);

  final String _name;

  String get asset => 'assets/images/mascot/rabi_$_name.webp';
}

/// Rabi in a [mood], gently alive: he sways when waving, leans the way he
/// points, hops when cheering. Changing [mood] swaps the pose in place.
///
/// He moves for a few seconds after appearing or changing mood, then
/// rests, so a quiet page stays quiet; while [busy] he keeps going. He is
/// decoration for screen readers (the words beside him carry the meaning)
/// and holds still when the device asks for reduced motion.
class DentraMascot extends StatefulWidget {
  const DentraMascot({
    super.key,
    this.mood = MascotMood.wave,
    this.size = 112,
    this.mirrored = false,
    this.stage = false,
    this.busy = false,
  });

  final MascotMood mood;

  /// Width and height of the square he stands in.
  final double size;

  /// Flips him left to right. He points and waves to his left as drawn;
  /// mirrored, toward the right.
  final bool mirrored;

  /// A soft mint glow behind him, for white surfaces.
  final bool stage;

  /// Work is under way: rings ripple out behind him and he keeps moving
  /// until it ends.
  final bool busy;

  /// The pose images are this many pixels square.
  static const int _source = 640;

  @override
  State<DentraMascot> createState() => _DentraMascotState();
}

class _DentraMascotState extends State<DentraMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  /// How many times the idle motion plays before he rests.
  static const int _idleLoops = 3;

  bool _still = false;
  bool _warmed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_warmed || still != _still) {
      _still = still;
      _play();
    }
    if (!_warmed) {
      _warmed = true;
      // Every pose is decoded up front, so a change of mood never blinks.
      for (final mood in MascotMood.values) {
        precacheImage(_image(mood), context, onError: (_, __) {});
      }
    }
  }

  @override
  void didUpdateWidget(DentraMascot old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood || old.busy != widget.busy) _play();
  }

  /// Starts the idle motion over: endless while busy, a few loops if not.
  void _play() {
    if (_still) {
      _loop
        ..stop()
        ..value = 0;
    } else if (widget.busy) {
      _loop.repeat();
    } else {
      // Ends on the loop's last frame, which is his resting pose.
      _loop
        ..value = 0
        ..repeat(count: _idleLoops);
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  ImageProvider _image(MascotMood mood) {
    final px = (widget.size * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(96, DentraMascot._source);
    return ResizeImage(AssetImage(mood.asset), width: px, height: px);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final mood = widget.mood;

    Widget figure = Image(
      image: _image(mood),
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => SizedBox.square(dimension: size),
    );
    if (widget.mirrored) figure = Transform.flip(flipX: true, child: figure);

    // A new pose springs in over the old one.
    final poses = AnimatedSwitcher(
      duration: _still ? Duration.zero : const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.9, end: 1.0).animate(animation),
          alignment: const Alignment(0, 0.9),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(mood), child: figure),
    );

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _loop,
            builder: (context, child) {
              final pose = _still
                  ? _Motion.rest
                  : _Motion.of(mood, _loop.value, widget.mirrored ? 1 : -1);
              return CustomPaint(
                painter: _StagePainter(
                  glow: widget.stage,
                  pulse: widget.busy ? (_still ? -1 : _loop.value) : null,
                  lift: pose.lift,
                ),
                foregroundPainter: _EmotePainter(
                  mood: mood,
                  t: _still ? null : _loop.value,
                  mirrored: widget.mirrored,
                ),
                child: Transform.translate(
                  offset: Offset(pose.dx * size, pose.dy * size),
                  child: Transform.rotate(
                    angle: pose.angle,
                    // He pivots on his feet.
                    alignment: const Alignment(0, 0.94),
                    child: Transform.scale(
                      scaleX: pose.sx,
                      scaleY: pose.sy,
                      alignment: const Alignment(0, 0.94),
                      child: child,
                    ),
                  ),
                ),
              );
            },
            // A little room underfoot for his shadow.
            child: Padding(
              padding: EdgeInsets.only(bottom: size * 0.04),
              child: poses,
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the idle loop has moved him, as fractions of his size.
class _Motion {
  const _Motion({
    this.dx = 0,
    this.dy = 0,
    this.angle = 0,
    this.sx = 1,
    this.sy = 1,
    this.lift = 0,
  });

  final double dx;
  final double dy;
  final double angle;
  final double sx;
  final double sy;

  /// 0 on the ground → 1 at the top of a hop, for his shadow.
  final double lift;

  static const rest = _Motion();

  /// [t] loops 0 → 1; [dir] is the side he points to (-1 left, 1 right).
  static _Motion of(MascotMood mood, double t, int dir) {
    final turn = t * 2 * math.pi;
    final sway = math.sin(turn);
    switch (mood) {
      case MascotMood.wave:
        return _Motion(angle: 0.05 * sway, dy: 0.01 * math.sin(turn * 2));
      case MascotMood.point:
        // Two soft nudges toward the thing, then back.
        final nudge = math.pow(math.sin(turn), 2).toDouble();
        return _Motion(dx: dir * 0.03 * nudge, angle: dir * 0.04 * nudge);
      case MascotMood.think:
        return _Motion(angle: 0.035 * sway, dy: 0.008 * math.sin(turn * 2));
      case MascotMood.cheer:
        // Two hops, then a breath before the next pair.
        final hop = t < 0.5 ? math.sin(turn * 2).abs() : 0.0;
        final breath = t < 0.5 ? 0.0 : math.sin((t - 0.5) * 2 * math.pi);
        return _Motion(
          dy: -0.07 * hop - 0.008 * breath,
          sx: 1.02 - 0.04 * hop,
          sy: 0.98 + 0.05 * hop,
          lift: hop,
        );
      case MascotMood.worried:
        return _Motion(angle: 0.028 * sway, dy: 0.006 * (1 + sway));
    }
  }
}

/// Behind him: the optional mint glow, the ripple while busy, and the soft
/// shadow under his feet.
class _StagePainter extends CustomPainter {
  const _StagePainter({
    required this.glow,
    required this.pulse,
    required this.lift,
  });

  final bool glow;

  /// 0 → 1 while rippling, -1 for one still ring, null for none.
  final double? pulse;
  final double lift;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(size.width / 2, s * 0.56);

    if (glow) {
      final rect = Rect.fromCircle(center: center, radius: s * 0.5);
      canvas.drawCircle(
        center,
        s * 0.5,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.mintGreen.withValues(alpha: 0.55),
              AppColors.mintGreen.withValues(alpha: 0.28),
              AppColors.mintGreen.withValues(alpha: 0),
            ],
            stops: const [0, 0.62, 1],
          ).createShader(rect),
      );
    }

    final p = pulse;
    if (p != null) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, s * 0.016);
      if (p < 0) {
        canvas.drawCircle(
          center,
          s * 0.44,
          ring..color = AppColors.g1.withValues(alpha: 0.35),
        );
      } else {
        for (final t in [p * 2 % 1, (p * 2 + 0.5) % 1]) {
          canvas.drawCircle(
            center,
            s * (0.3 + 0.22 * t),
            ring..color = AppColors.g1.withValues(alpha: 0.6 * (1 - t)),
          );
        }
      }
    }

    // Smaller and fainter while he is in the air.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, s * 0.955),
        width: s * 0.46 * (1 - 0.25 * lift),
        height: s * 0.05,
      ),
      Paint()
        ..color = AppColors.navy.withValues(alpha: 0.10 * (1 - 0.4 * lift))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.018),
    );
  }

  @override
  bool shouldRepaint(_StagePainter old) =>
      old.glow != glow || old.pulse != pulse || old.lift != lift;
}

/// In front of him: thought dots while thinking, sparkles while cheering.
class _EmotePainter extends CustomPainter {
  const _EmotePainter({
    required this.mood,
    required this.t,
    required this.mirrored,
  });

  final MascotMood mood;

  /// 0 → 1 loop; null holds one finished-looking frame.
  final double? t;
  final bool mirrored;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    Offset at(double x, double y) =>
        Offset((mirrored ? 1 - x : x) * size.width, y * s);

    switch (mood) {
      case MascotMood.think:
        // Three dots drifting up from his head, lighting in turn.
        const spots = [(0.86, 0.31, 0.022), (0.93, 0.22, 0.03), (1.0, 0.11, 0.04)];
        for (var i = 0; i < spots.length; i++) {
          final (x, y, r) = spots[i];
          final phase = t == null ? 1.0 : ((t! * 2 - i * 0.18) % 1);
          final lit = t == null
              ? 0.75
              : 0.25 + 0.75 * math.sin(phase * math.pi).clamp(0.0, 1.0);
          canvas.drawCircle(
            at(x, y),
            s * r,
            Paint()..color = AppColors.g2.withValues(alpha: 0.75 * lit),
          );
        }
      case MascotMood.cheer:
        final twinkle =
            t == null ? 0.8 : 0.6 + 0.4 * math.sin(t! * 4 * math.pi).abs();
        _sparkle(canvas, at(0.07, 0.30), s * 0.075 * twinkle, AppColors.g1);
        _sparkle(
            canvas, at(0.95, 0.24), s * 0.06 * (1.6 - twinkle), AppColors.g2);
        _sparkle(
            canvas, at(0.90, 0.74), s * 0.045 * twinkle, AppColors.cardSolid);
      case MascotMood.wave || MascotMood.point || MascotMood.worried:
        break;
    }
  }

  /// A four-point star.
  static void _sparkle(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()..moveTo(c.dx, c.dy - r);
    const pinch = 0.28;
    for (var i = 1; i <= 4; i++) {
      final a = -math.pi / 2 + i * math.pi / 2;
      final mid = a - math.pi / 4;
      path
        ..lineTo(c.dx + math.cos(mid) * r * pinch,
            c.dy + math.sin(mid) * r * pinch)
        ..lineTo(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_EmotePainter old) =>
      old.mood != mood || old.t != t || old.mirrored != mirrored;
}
