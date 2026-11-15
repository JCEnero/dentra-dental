import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/constants/app_colors.dart';
import 'mascot_rig.g.dart';

/// What Rabi, the DENTRA mascot, is doing. Every mood is the same render,
/// posed live from its own parts (`mascot_rig.g.dart`), so he stays one
/// character.
enum MascotMood {
  /// Smiling and waving: hello, and friendly empty pages.
  wave,

  /// An arm held out toward what matters next (see [MascotAim]).
  point,

  /// Hand on chin while something is worked out.
  think,

  /// Both arms up and a happy squint: it worked.
  cheer,

  /// Ears down and a small frown: something went wrong, try again.
  worried,

  /// Ears turning and eyes moving from side to side: looking for something.
  watch,

  /// Rocking on his feet with the odd glance aside: waiting on someone else.
  wait,

  /// Eyes shut: not looking, e.g. while a password is typed.
  hush,
}

/// Where the arm goes when Rabi points.
enum MascotAim { up, side, down }

/// Rabi in a [mood], alive: he breathes, blinks and glances about, waves
/// with his arm, turns his ears when he listens. Changing [mood] moves him
/// from one pose to the next rather than swapping pictures.
///
/// By default he moves for a few seconds after appearing or changing mood,
/// then rests, so a quiet page stays quiet; while [busy] or [awake] he keeps
/// going. He is decoration for screen readers (the words beside him carry
/// the meaning) and holds still when the device asks for reduced motion.
class DentraMascot extends StatefulWidget {
  const DentraMascot({
    super.key,
    this.mood = MascotMood.wave,
    this.size = 112,
    this.mirrored = false,
    this.stage = false,
    this.busy = false,
    this.awake = false,
    this.aim = MascotAim.side,
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

  /// Keeps him moving for as long as he is on screen, for guides where he
  /// leads the page.
  final bool awake;

  /// Where he points, in [MascotMood.point].
  final MascotAim aim;

  @override
  State<DentraMascot> createState() => _DentraMascotState();
}

class _DentraMascotState extends State<DentraMascot>
    with SingleTickerProviderStateMixin {
  /// Seconds since he appeared, while he is moving.
  final ValueNotifier<double> _clock = ValueNotifier(0);
  late final Ticker _ticker = createTicker(_tick);
  Duration _offset = Duration.zero;

  /// How long he idles before resting, unless busy or awake.
  static const double _restAfter = 9;

  /// How long one pose takes to become the next.
  static const double _blendFor = 0.45;

  bool _still = false;
  bool _warmed = false;

  /// The pose he is leaving, and when he left it.
  _Pose _from = const _Pose();
  _Mouth _fromMouth = _Mouth.smile;
  double _since = -_blendFor;

  /// When this spell of idling began.
  double _awakeFrom = 0;

  ImageStream? _stream;
  ImageInfo? _sheet;
  late final ImageStreamListener _listener = ImageStreamListener(
    (info, _) {
      if (!mounted) {
        info.dispose();
        return;
      }
      setState(() {
        _sheet?.dispose();
        _sheet = info;
      });
    },
    onError: (_, __) {},
  );

  bool get _lively => widget.busy || widget.awake;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!_warmed || still != _still) {
      _still = still;
      _warmed = true;
      _wake();
    }
    _resolve();
  }

  @override
  void didUpdateWidget(DentraMascot old) {
    super.didUpdateWidget(old);
    if (old.size != widget.size) _resolve();
    if (old.mood != widget.mood || old.aim != widget.aim) {
      // Starts from wherever he is right now, mid-move included.
      final now = _clock.value;
      _from = _still ? _target(widget) : _poseAt(now, old);
      _fromMouth = _mouthOf(old.mood);
      // Holding still, he is in the new pose at once.
      _since = _still ? now - _blendFor : now;
      _wake(afresh: true);
    } else if (old.busy != widget.busy || old.awake != widget.awake) {
      _wake();
    }
  }

  /// Starts him moving (again); he rests by himself when nothing is busy.
  void _wake({bool afresh = false}) {
    if (_still) {
      _ticker.stop();
      return;
    }
    if (afresh || !_ticker.isActive || _lively) _awakeFrom = _clock.value;
    if (!_ticker.isActive) {
      _offset = Duration(microseconds: (_clock.value * 1e6).round());
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    _clock.value = (_offset + elapsed).inMicroseconds / 1e6;
    if (_lively) {
      _awakeFrom = _clock.value;
    } else if (_clock.value - _awakeFrom >= _restAfter) {
      _ticker.stop();
    }
  }

  /// The sprite sheet, decoded no larger than he is shown.
  void _resolve() {
    final px = widget.size * MediaQuery.devicePixelRatioOf(context);
    final scale = px > 420
        ? 1.0
        : px > 260
            ? 0.75
            : px > 140
                ? 0.5
                : 0.3;
    const ImageProvider asset = AssetImage(MascotRig.asset);
    final ImageProvider provider = scale == 1.0
        ? asset
        : ResizeImage(
            asset,
            width: (MascotRig.sheetSize.width * scale).round(),
          );
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _stream?.removeListener(_listener);
    _sheet?.dispose();
    _clock.dispose();
    super.dispose();
  }

  // ── Posing ────────────────────────────────────────────────────────

  static _Pose _target(DentraMascot w) => _Pose.of(w.mood, w.aim);

  static _Mouth _mouthOf(MascotMood mood) => switch (mood) {
        MascotMood.think => _Mouth.hmm,
        MascotMood.worried => _Mouth.frown,
        MascotMood.watch => _Mouth.oh,
        MascotMood.wait || MascotMood.hush => _Mouth.calm,
        MascotMood.wave || MascotMood.point || MascotMood.cheer => _Mouth.smile,
      };

  /// 0 → 1 as the last change of mood settles.
  double _blend(double t) =>
      Curves.easeOutCubic.transform(((t - _since) / _blendFor).clamp(0.0, 1.0));

  /// How much he is idling: fades out just before he rests.
  double _life(double t) {
    if (_still) return 0;
    if (_lively) return 1;
    final left = _restAfter - (t - _awakeFrom);
    return Curves.easeInOut.transform(left.clamp(0.0, 1.0));
  }

  /// Where every part of him is at [t], for the widget [w].
  _Pose _poseAt(double t, DentraMascot w) {
    final settled = _Pose.lerp(_from, _target(w), _blend(t));
    final life = _life(t);
    if (life == 0) return settled;
    return settled.moved(
      _Idle.of(w.mood, t - _since, t),
      life,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: RepaintBoundary(
          child: CustomPaint(painter: _RabiPainter(this, _clock)),
        ),
      ),
    );
  }

  // ── Painting ──────────────────────────────────────────────────────

  void _paint(Canvas canvas, Size box) {
    final s = box.shortestSide;
    final t = _clock.value;
    final pose = _poseAt(t, widget);
    final life = _life(t);
    final mouthBlend = _blend(t);

    _paintStage(canvas, box, s, t, pose.lift);

    final sheet = _sheet?.image;
    if (sheet != null) {
      canvas.save();
      if (widget.mirrored) {
        canvas
          ..translate(box.width, 0)
          ..scale(-1, 1);
      }
      // He turns and stretches from his feet.
      final feet = Offset(box.width / 2, s * 0.955);
      canvas
        ..translate(feet.dx + pose.dx * s, feet.dy + pose.dy * s)
        ..rotate(pose.lean)
        ..scale(pose.sx, pose.sy)
        ..translate(-feet.dx, -feet.dy);
      _Figure(
        canvas: canvas,
        sheet: sheet,
        // A little room underfoot for his shadow.
        origin: Offset((box.width - s * 0.96) / 2, 0),
        side: s * 0.96,
      ).paint(
        pose,
        from: _fromMouth,
        to: _mouthOf(widget.mood),
        mouthBlend: mouthBlend,
      );
      canvas.restore();
    }

    _paintEmotes(canvas, box, s, t, life);
  }

  /// Behind him: the optional mint glow, the ripple while busy, and the soft
  /// shadow under his feet.
  void _paintStage(Canvas canvas, Size box, double s, double t, double lift) {
    final center = Offset(box.width / 2, s * 0.56);

    if (widget.stage) {
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

    if (widget.busy) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, s * 0.016);
      if (_still) {
        canvas.drawCircle(
          center,
          s * 0.44,
          ring..color = AppColors.g1.withValues(alpha: 0.35),
        );
      } else {
        final p = t / 3.2;
        for (final phase in [p * 2 % 1, (p * 2 + 0.5) % 1]) {
          canvas.drawCircle(
            center,
            s * (0.3 + 0.22 * phase),
            ring..color = AppColors.g1.withValues(alpha: 0.6 * (1 - phase)),
          );
        }
      }
    }

    // Smaller and fainter while he is in the air.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(box.width / 2, s * 0.955),
        width: s * 0.46 * (1 - 0.25 * lift),
        height: s * 0.05,
      ),
      Paint()
        ..color = AppColors.navy.withValues(alpha: 0.10 * (1 - 0.4 * lift))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.018),
    );
  }

  /// In front of him: thought dots while thinking, sparkles while cheering.
  void _paintEmotes(Canvas canvas, Size box, double s, double t, double life) {
    final shown = _blend(t);
    final moving = life > 0;
    Offset at(double x, double y) =>
        Offset((widget.mirrored ? 1 - x : x) * box.width, y * s);

    switch (widget.mood) {
      case MascotMood.think:
        // Three dots drifting up from his head, lighting in turn.
        const spots = [
          (0.86, 0.31, 0.022),
          (0.93, 0.22, 0.03),
          (1.0, 0.11, 0.04)
        ];
        for (var i = 0; i < spots.length; i++) {
          final (x, y, r) = spots[i];
          final phase = (t / 1.6 - i * 0.18) % 1;
          final lit = moving
              ? 0.25 + 0.75 * math.sin(phase * math.pi).clamp(0.0, 1.0)
              : 0.75;
          canvas.drawCircle(
            at(x, y),
            s * r,
            Paint()..color = AppColors.g2.withValues(alpha: 0.75 * lit * shown),
          );
        }
      case MascotMood.cheer:
        final twinkle =
            moving ? 0.6 + 0.4 * math.sin(t / 0.8 * math.pi).abs() : 0.8;
        _sparkle(
            canvas, at(0.07, 0.30), s * 0.075 * twinkle * shown, AppColors.g1);
        _sparkle(canvas, at(0.95, 0.24), s * 0.06 * (1.6 - twinkle) * shown,
            AppColors.g2);
        _sparkle(canvas, at(0.90, 0.74), s * 0.045 * twinkle * shown,
            AppColors.cardSolid);
      case MascotMood.wave ||
            MascotMood.point ||
            MascotMood.worried ||
            MascotMood.watch ||
            MascotMood.wait ||
            MascotMood.hush:
        break;
    }
  }

  /// A four-point star.
  static void _sparkle(Canvas canvas, Offset c, double r, Color color) {
    if (r <= 0) return;
    final path = Path()..moveTo(c.dx, c.dy - r);
    const pinch = 0.28;
    for (var i = 1; i <= 4; i++) {
      final a = -math.pi / 2 + i * math.pi / 2;
      final mid = a - math.pi / 4;
      path
        ..lineTo(
            c.dx + math.cos(mid) * r * pinch, c.dy + math.sin(mid) * r * pinch)
        ..lineTo(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }
}

class _RabiPainter extends CustomPainter {
  _RabiPainter(this.state, Listenable clock) : super(repaint: clock);

  final _DentraMascotState state;

  @override
  void paint(Canvas canvas, Size size) => state._paint(canvas, size);

  // Rebuilt only when something he depends on changed.
  @override
  bool shouldRepaint(_RabiPainter old) => true;
}

/// The small mouths drawn over his painted-out smile.
enum _Mouth { smile, calm, hmm, frown, oh }

/// Where each of his parts is. Turns are in degrees as his render was cut:
/// a positive [arm] lowers the raised arm, positive ear turns lean left.
/// Moves are in render pixels (880 across his square) unless noted.
class _Pose {
  const _Pose({
    this.arm = 0,
    this.armX = 0,
    this.armY = 0,
    this.chin = 0,
    this.chinTurn = 0,
    this.armB = 0,
    this.armBTurn = 18,
    this.earL = 0,
    this.earR = 0,
    this.eyes = 0,
    this.gaze = 0,
    this.brows = 0,
    this.lean = 0,
    this.dx = 0,
    this.dy = 0,
    this.sx = 1,
    this.sy = 1,
    this.lift = 0,
  });

  /// The near arm, behind his body.
  final double arm;
  final double armX;
  final double armY;

  /// 0 → 1: the arm comes round the front, hand to chin.
  final double chin;
  final double chinTurn;

  /// 0 → 1: his second arm is up too.
  final double armB;
  final double armBTurn;
  final double earL;
  final double earR;

  /// 0 open, 1 shut, 2 shut in a smile.
  final double eyes;

  /// -1 looking toward his raised arm, 0 as rendered, 1 the other way.
  final double gaze;

  /// 0 → 1: worried brows.
  final double brows;

  /// His whole body: turn in radians about his feet, moves and stretch as
  /// fractions of his size.
  final double lean;
  final double dx;
  final double dy;
  final double sx;
  final double sy;

  /// 0 on the ground → 1 at the top of a hop, for his shadow.
  final double lift;

  /// His arm hanging at his side.
  static const _down = (arm: 150.0, armX: 40.0, armY: -58.0);

  static _Pose of(MascotMood mood, MascotAim aim) => switch (mood) {
        MascotMood.wave => const _Pose(),
        MascotMood.point => switch (aim) {
            MascotAim.up => const _Pose(arm: 22, armX: 8, armY: -6, gaze: -1),
            MascotAim.side =>
              const _Pose(arm: 50, armX: 16, armY: -10, gaze: -1),
            MascotAim.down =>
              const _Pose(arm: 78, armX: 16, armY: -18, gaze: -1),
          },
        MascotMood.think => _Pose(
            arm: _down.arm,
            armX: _down.armX,
            armY: _down.armY,
            chin: 1,
            earL: 9,
            lean: 0.03,
          ),
        MascotMood.cheer =>
          const _Pose(arm: 14, armX: -2, armY: -22, armB: 1, eyes: 2),
        MascotMood.worried => const _Pose(
            arm: 104,
            armX: 14,
            armY: -26,
            earL: 34,
            earR: -38,
            brows: 1,
          ),
        MascotMood.watch => _Pose(
            arm: _down.arm,
            armX: _down.armX,
            armY: _down.armY,
            earL: -5,
            earR: 5,
          ),
        MascotMood.wait => _Pose(
            arm: _down.arm,
            armX: _down.armX,
            armY: _down.armY,
            earL: 6,
            earR: -6,
          ),
        MascotMood.hush => _Pose(
            arm: _down.arm,
            armX: _down.armX,
            armY: _down.armY,
            earL: 8,
            earR: -8,
            eyes: 1,
          ),
      };

  static double _mix(double a, double b, double t) => a + (b - a) * t;

  static _Pose lerp(_Pose a, _Pose b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    return _Pose(
      arm: _mix(a.arm, b.arm, t),
      armX: _mix(a.armX, b.armX, t),
      armY: _mix(a.armY, b.armY, t),
      chin: _mix(a.chin, b.chin, t),
      chinTurn: _mix(a.chinTurn, b.chinTurn, t),
      armB: _mix(a.armB, b.armB, t),
      armBTurn: _mix(a.armBTurn, b.armBTurn, t),
      earL: _mix(a.earL, b.earL, t),
      earR: _mix(a.earR, b.earR, t),
      eyes: _mix(a.eyes, b.eyes, t),
      gaze: _mix(a.gaze, b.gaze, t),
      brows: _mix(a.brows, b.brows, t),
      lean: _mix(a.lean, b.lean, t),
      dx: _mix(a.dx, b.dx, t),
      dy: _mix(a.dy, b.dy, t),
      sx: _mix(a.sx, b.sx, t),
      sy: _mix(a.sy, b.sy, t),
      lift: _mix(a.lift, b.lift, t),
    );
  }

  /// This pose with an idle [move] laid over it at strength [k].
  _Pose moved(_Idle move, double k) => _Pose(
        arm: arm + move.arm * k,
        armX: armX,
        armY: armY,
        chin: chin,
        chinTurn: chinTurn + move.chinTurn * k,
        armB: armB,
        armBTurn: armBTurn + move.armB * k,
        earL: earL + move.earL * k,
        earR: earR + move.earR * k,
        // A blink closes open eyes; shut ones stay as they are.
        eyes: eyes >= 1 ? eyes : math.min(1.0, eyes + move.lids * k),
        gaze: (gaze + move.gaze * k).clamp(-1.0, 1.0),
        brows: brows,
        lean: lean + move.lean * k,
        dx: dx + move.dx * k,
        dy: dy + move.dy * k,
        sx: sx + move.sx * k,
        sy: sy + move.sy * k,
        lift: move.lift * k,
      );
}

/// What idling adds to a pose at one moment: the small moves that make him
/// look alive.
class _Idle {
  const _Idle({
    this.arm = 0,
    this.chinTurn = 0,
    this.armB = 0,
    this.earL = 0,
    this.earR = 0,
    this.lids = 0,
    this.gaze = 0,
    this.lean = 0,
    this.dx = 0,
    this.dy = 0,
    this.sx = 0,
    this.sy = 0,
    this.lift = 0,
  });

  final double arm;
  final double chinTurn;
  final double armB;
  final double earL;
  final double earR;
  final double lids;
  final double gaze;
  final double lean;
  final double dx;
  final double dy;
  final double sx;
  final double sy;
  final double lift;

  static const _tau = 2 * math.pi;

  static double _wave(double t, double period, [double phase = 0]) =>
      math.sin(_tau * (t / period + phase));

  /// 0 → 1 → 0 between [from] and [to] within each [period], else 0.
  static double _window(double t, double period, double from, double to) {
    final x = (t % period - from) / (to - from);
    if (x <= 0 || x >= 1) return 0;
    return math.sin(x * math.pi);
  }

  /// A blink now and then: one, then a quick pair.
  static double _blink(double clock) {
    const every = 6.4;
    final t = clock % every;
    double one(double at) {
      final x = (t - at) / 0.26;
      if (x <= 0 || x >= 1) return 0;
      if (x < 0.35) return Curves.easeIn.transform(x / 0.35);
      if (x < 0.5) return 1;
      return 1 - Curves.easeOut.transform((x - 0.5) / 0.5);
    }

    return math.max(one(1.5), math.max(one(4.6), one(4.98)));
  }

  /// A glance that holds [side] between [from] and [to] of each [period],
  /// with a half-blink as the eyes move.
  static (double gaze, double lids) _glance(
    double t,
    double period,
    double from,
    double to,
    double side,
  ) {
    final at = t % period;
    const flick = 0.1;
    final inn = ((at - from) / flick).clamp(0.0, 1.0);
    final out = ((to - at) / flick).clamp(0.0, 1.0);
    final held = math.min(inn, out);
    // Lids dip while the eyes are between the two looks.
    final dip = held > 0 && held < 1 ? math.sin(held * math.pi) * 0.45 : 0.0;
    return (side * held, dip);
  }

  /// [t] is seconds in this mood; [clock] never restarts, so breathing and
  /// blinking carry on through a change of mood.
  static _Idle of(MascotMood mood, double t, double clock) {
    final breath = 0.011 * _wave(clock, 3.6);
    final blink = _blink(clock);

    switch (mood) {
      case MascotMood.wave:
        // Two swings of the arm, a rest, and again; the ears follow.
        final swing = _window(t, 3.2, 0.1, 1.9);
        final beat = _wave(t, 0.62);
        return _Idle(
          arm: (12 * beat - 3) * swing,
          earL: 2.4 * _wave(t, 0.62, -0.18) * swing,
          earR: 2.0 * _wave(t, 0.62, -0.26) * swing,
          lean: 0.022 * _wave(clock, 3.6),
          lids: blink,
          sy: breath,
        );
      case MascotMood.point:
        // Two soft nudges toward the thing, then back.
        final nudge = _window(t, 2.4, 0.2, 0.9) + _window(t, 2.4, 0.9, 1.6);
        return _Idle(
          arm: -5 * nudge,
          dx: -0.028 * nudge,
          lean: -0.04 * nudge,
          earR: -3 * nudge,
          lids: blink,
          sy: breath,
        );
      case MascotMood.think:
        // A finger tapping the chin, eyes wandering off and back.
        final (gaze, dip) = _glance(t, 5.2, 2.6, 4.2, 1);
        return _Idle(
          chinTurn:
              2.6 * _window(t, 2.6, 0.5, 0.9) + 2.6 * _window(t, 2.6, 0.9, 1.3),
          earL: 3 * _wave(clock, 3.6),
          lean: 0.016 * _wave(clock, 3.6),
          gaze: gaze,
          lids: math.max(blink, dip),
          sy: breath,
        );
      case MascotMood.cheer:
        // Two hops, then a breath before the next pair. He breathes
        // through the hops too, so the loop has no seam where they start.
        final at = (t % 2.6) / 2.6;
        final hop = at < 0.5 ? math.sin(at * 2 * _tau).abs() : 0.0;
        return _Idle(
          dy: -0.07 * hop,
          sx: 0.02 - 0.04 * hop,
          sy: -0.02 + 0.05 * hop + breath,
          arm: -8 * hop,
          armB: -8 * hop,
          earL: 5 * hop,
          earR: -5 * hop,
          lift: hop,
        );
      case MascotMood.worried:
        return _Idle(
          earL: 1.6 * _wave(t, 0.34) * _window(t, 3.4, 0.4, 1.4),
          earR: -1.6 * _wave(t, 0.34) * _window(t, 3.4, 0.4, 1.4),
          lean: 0.024 * _wave(clock, 3.6),
          dy: 0.005 * (1 + _wave(clock, 3.6)),
          lids: blink,
          sy: breath,
        );
      case MascotMood.watch:
        // Ears turn like little dishes while his eyes sweep the room.
        final (left, dipA) = _glance(t, 4.4, 0.3, 1.5, -1);
        final (right, dipB) = _glance(t, 4.4, 2.4, 3.6, 1);
        return _Idle(
          earL: 8 * _wave(t, 2.2),
          earR: -8 * _wave(t, 2.2, 0.22),
          gaze: left + right,
          lean: 0.03 * _wave(t, 4.4, 0.02),
          dy: -0.008 * _wave(t, 1.1).abs(),
          lids: math.max(blink, math.max(dipA, dipB)),
          sy: breath,
        );
      case MascotMood.wait:
        // Rocking from foot to foot, a look aside, an ear that twitches.
        final (gaze, dip) = _glance(t, 5.6, 3.0, 4.1, -1);
        final twitch = _window(t, 4.2, 1.9, 2.15);
        return _Idle(
          lean: 0.05 * _wave(t, 2.8),
          dx: 0.014 * _wave(t, 2.8),
          arm: 4 * _wave(t, 2.8, 0.2),
          earR: -11 * twitch,
          earL: 2 * _wave(t, 2.8, 0.3),
          gaze: gaze,
          lids: math.max(blink, dip),
          sy: breath,
        );
      case MascotMood.hush:
        return _Idle(
          lean: 0.02 * _wave(clock, 3.6),
          earL: 2 * _wave(clock, 3.6),
          earR: -2 * _wave(clock, 3.6),
          sy: breath,
        );
    }
  }
}

/// Puts Rabi together from the sprite sheet, part by part.
class _Figure {
  _Figure({
    required this.canvas,
    required this.sheet,
    required this.origin,
    required this.side,
  })  : _k = sheet.width / MascotRig.sheetSize.width,
        // Render pixels to screen pixels.
        _u = side / 880;

  final Canvas canvas;
  final ui.Image sheet;

  /// Top left and side of the square he stands in.
  final Offset origin;
  final double side;
  final double _k;
  final double _u;

  // The render's own line colours.
  static const _lid = Color(0xFF34305C);
  static const _lidShade = Color(0xFFB2ACCD);
  static const _lip = Color(0xFF683E48);
  static const _lipShade = Color(0xFFBEB4CD);

  static double _rad(double deg) => -deg * math.pi / 180;

  Offset _at(Offset unit) => origin + unit * side;

  void _draw(MascotPart part, [double alpha = 1]) {
    if (alpha <= 0.004) return;
    final src = Rect.fromLTWH(
      part.src.left * _k,
      part.src.top * _k,
      part.src.width * _k,
      part.src.height * _k,
    );
    final dst = Rect.fromLTWH(
      origin.dx + part.dst.left * side,
      origin.dy + part.dst.top * side,
      part.dst.width * side,
      part.dst.height * side,
    );
    canvas.drawImageRect(
      sheet,
      src,
      dst,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0)),
    );
  }

  /// Draws [part] turned by [deg] about [pivot] and moved by [shift]
  /// (render pixels).
  void _turned(
    MascotPart part,
    Offset pivot,
    double deg, {
    Offset shift = Offset.zero,
    double alpha = 1,
  }) {
    if (alpha <= 0.004) return;
    final p = _at(pivot);
    canvas
      ..save()
      ..translate(p.dx + shift.dx * _u, p.dy + shift.dy * _u)
      ..rotate(_rad(deg))
      ..translate(-p.dx, -p.dy);
    _draw(part, alpha);
    canvas.restore();
  }

  void paint(
    _Pose pose, {
    required _Mouth from,
    required _Mouth to,
    required double mouthBlend,
  }) {
    final chin = pose.chin.clamp(0.0, 1.0);
    final second = pose.armB.clamp(0.0, 1.0);

    // Behind his body: the far arm, or the second raised arm in its place.
    _draw(MascotRig.farArm, 1 - second);
    if (second > 0) {
      final mx = origin.dx + MascotRig.mirrorX * side;
      canvas
        ..save()
        ..translate(mx, 0)
        ..scale(-1, 1)
        ..translate(-mx, 0);
      _turned(
        MascotRig.arm,
        MascotRig.armPivot,
        pose.armBTurn,
        shift: const Offset(0, -24),
        alpha: second,
      );
      canvas.restore();
    }
    _turned(
      MascotRig.arm,
      MascotRig.armPivot,
      pose.arm,
      shift: Offset(pose.armX, pose.armY),
      alpha: 1 - chin,
    );

    // Ears swing about their roots, tucked in a little so no gap opens.
    for (final (part, root, deg) in [
      (MascotRig.earL, MascotRig.earLRoot, pose.earL),
      (MascotRig.earR, MascotRig.earRRoot, pose.earR),
    ]) {
      final tuck = Curves.easeOut.transform((deg.abs() / 12).clamp(0.0, 1.0));
      _turned(part, root, deg, shift: Offset(0, 6 * tuck));
    }

    _draw(MascotRig.body);
    _mouth(from, to, mouthBlend);
    _eyes(pose);
    _brows(pose.brows);

    // In front: the hand that comes up to his chin, and its soft shadow.
    if (chin > 0) {
      _draw(MascotRig.chinShade, chin);
      final reach = Curves.easeOut.transform(chin);
      final p = _at(MascotRig.armPivot);
      canvas
        ..save()
        ..translate(
          p.dx + MascotRig.thinkShift.dx * side * reach,
          p.dy + MascotRig.thinkShift.dy * side * reach,
        )
        ..rotate(MascotRig.thinkTurn * reach + _rad(pose.chinTurn))
        ..translate(-p.dx, -p.dy);
      _draw(MascotRig.armFront, chin);
      canvas.restore();
    }
  }

  // ── Face ──────────────────────────────────────────────────────────

  /// A stroke in the render's line style: a soft pale shade just under a
  /// dark round-capped line. Sizes are render pixels (see [_onFace]).
  void _line(Path path, double width, Color color, Color shade, double alpha) {
    if (alpha <= 0.004) return;
    final under = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width + 5.5
      ..color = shade.withValues(alpha: 0.48 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2);
    canvas
      ..drawPath(path.shift(const Offset(0, 3)), under)
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = width
          ..color = color.withValues(alpha: alpha),
      );
  }

  /// Runs [draw] in the face's own frame: [centre] at the origin, leaning
  /// with the face, one unit per render pixel.
  void _onFace(Offset centre, VoidCallback draw) {
    final c = _at(centre);
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(MascotRig.faceTilt)
      ..scale(_u);
    draw();
    canvas.restore();
  }

  static Path _arc(Offset a, Offset ctrl, Offset b) => Path()
    ..moveTo(a.dx, a.dy)
    ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);

  void _eyes(_Pose pose) {
    final shut = pose.eyes.clamp(0.0, 1.0);
    final smile = (pose.eyes - 1).clamp(0.0, 1.0);
    final away = pose.gaze;

    for (final (eye, turned, centre, half, wide, tall, weight, looks) in [
      (
        MascotRig.eyeL,
        MascotRig.eyeLAway,
        MascotRig.eyeLCentre,
        MascotRig.eyeLHalf,
        78.0,
        40.0,
        11.5,
        // The near eye turns when he looks toward his arm.
        (-away).clamp(0.0, 1.0),
      ),
      (
        MascotRig.eyeR,
        MascotRig.eyeRAway,
        MascotRig.eyeRCentre,
        MascotRig.eyeRHalf,
        70.0,
        36.0,
        10.5,
        away.clamp(0.0, 1.0),
      ),
    ]) {
      final a = half.width * 880;
      final b = half.height * 880;
      // The lid's edge: high above the eye when open, sagging across its
      // lower third when shut.
      final ends = _mix(-0.6 * b, 0.15 * b, shut);
      final dip = _mix(-1.5 * b, 0.85 * b, shut);

      if (shut < 0.98) {
        canvas.save();
        if (shut > 0.01) {
          // Only what is below the lid shows.
          final c = _at(centre);
          canvas
            ..translate(c.dx, c.dy)
            ..rotate(MascotRig.faceTilt)
            ..scale(_u)
            ..clipPath(
              Path()
                ..moveTo(-a * 1.3, ends)
                ..quadraticBezierTo(0, dip, a * 1.3, ends)
                ..lineTo(a * 1.3, b * 1.4)
                ..lineTo(-a * 1.3, b * 1.4)
                ..close(),
            )
            ..scale(1 / _u)
            ..rotate(-MascotRig.faceTilt)
            ..translate(-c.dx, -c.dy);
        }
        _draw(eye);
        _draw(turned, looks);
        canvas.restore();
      }

      // The lash line: follows the lid down, then curls up into a smile.
      final seen = ((shut - 0.5) / 0.35).clamp(0.0, 1.0);
      if (seen > 0) {
        _onFace(centre, () {
          // Kept inside the eye, so a half-lowered lid ends at its corners.
          canvas.clipPath(
            Path()
              ..addOval(Rect.fromCenter(
                center: Offset.zero,
                width: a * 1.8,
                height: b * 1.8,
              )),
          );
          final lash = _arc(
            Offset.lerp(
              Offset(-a * 0.9, ends),
              Offset(-wide / 2, tall * 0.45),
              smile,
            )!,
            Offset.lerp(Offset(0, dip), Offset(0, -tall * 1.15), smile)!,
            Offset.lerp(
              Offset(a * 0.9, ends),
              Offset(wide / 2, tall * 0.45),
              smile,
            )!,
          );
          _line(lash, _mix(8.5, weight, smile), _lid, _lidShade, seen);
        });
      }
    }
  }

  static double _mix(double a, double b, double t) => a + (b - a) * t;

  /// Inner ends lifted, outer ends dropped.
  void _brows(double shown) {
    if (shown <= 0.004) return;
    final shift = origin - const Offset(97, 82) * _u;
    for (final (a, b, width) in const [
      (Offset(372, 476), Offset(438, 456), 9.5),
      (Offset(690, 508), Offset(628, 492), 8.5),
    ]) {
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2 - 5);
      canvas
        ..save()
        ..translate(shift.dx, shift.dy)
        ..scale(_u);
      _line(_arc(a, mid, b), width, _lid, _lidShade, shown);
      canvas.restore();
    }
  }

  void _mouth(_Mouth from, _Mouth to, double blend) {
    // The painted smile shows through unless a drawn mouth covers it.
    final cover = _mix(
      from == _Mouth.smile ? 0 : 1,
      to == _Mouth.smile ? 0 : 1,
      blend,
    );
    _draw(MascotRig.lips, cover);
    if (from != to) _drawMouth(from, 1 - blend);
    _drawMouth(to, from == to ? 1 : blend);
  }

  void _drawMouth(_Mouth mouth, double alpha) {
    if (alpha <= 0.004 || mouth == _Mouth.smile) return;
    _onFace(MascotRig.mouth, () {
      switch (mouth) {
        case _Mouth.smile:
          break;
        case _Mouth.calm:
          _line(
            _arc(const Offset(-25, -3), const Offset(0, 19),
                const Offset(25, -3)),
            8.5,
            _lip,
            _lipShade,
            alpha,
          );
        case _Mouth.hmm:
          _line(
            _arc(const Offset(-6, 4), const Offset(14, 12),
                const Offset(34, -2)),
            8.5,
            _lip,
            _lipShade,
            alpha,
          );
        case _Mouth.frown:
          _line(
            Path()
              ..moveTo(-30, 12)
              ..quadraticBezierTo(-16, -10, 0, 2)
              ..quadraticBezierTo(16, -8, 30, 12),
            8.5,
            _lip,
            _lipShade,
            alpha,
          );
        case _Mouth.oh:
          final rect = Rect.fromCenter(
            center: const Offset(2, 4),
            width: 25,
            height: 29,
          );
          canvas
            ..drawOval(
              rect.inflate(3).shift(const Offset(0, 3)),
              Paint()
                ..color = _lipShade.withValues(alpha: 0.48 * alpha)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2),
            )
            ..drawOval(rect, Paint()..color = _lip.withValues(alpha: alpha));
      }
    });
  }
}
