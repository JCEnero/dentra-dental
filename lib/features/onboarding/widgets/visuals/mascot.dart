import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../onboarding_palette.dart';

/// DENTRA's tooth-rabbit mascot, drawn as a rigged vector character.
///
/// Ears, arms, eyes, eyelids, mouth and feet are separate layers posed by a
/// [MascotRig], so each slide can animate it (waving, blinking, hopping,
/// following things with its eyes). Shading matches the other onboarding
/// illustrations: key light from the upper left, ambient occlusion where
/// parts meet, and a mint rim light from the turquoise backdrop.
class Mascot extends StatelessWidget {
  const Mascot({super.key, required this.width, required this.rig});

  final double width;
  final MascotRig rig;

  /// Design space the character is drawn in.
  static const Size designSize = Size(200, 280);

  /// Where the feet meet the floor, in design units.
  static const Offset feet = Offset(104, 275);

  /// The box a mascot of [width] occupies when its feet stand on [floor].
  static Rect rectStandingAt(Offset floor, double width) {
    final s = width / designSize.width;
    return Rect.fromLTWH(
      floor.dx - feet.dx * s,
      floor.dy - feet.dy * s,
      width,
      designSize.height * s,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, width * designSize.height / designSize.width),
      painter: _MascotPainter(rig),
    );
  }
}

/// One frame of the mascot's pose. Angles are radians (clockwise positive),
/// lengths are design units.
@immutable
class MascotRig {
  const MascotRig({
    this.lift = 0,
    this.squash = 0,
    this.tilt = 0,
    this.earLeft = 0,
    this.earRight = 0,
    this.armLeft = -0.38,
    this.armRight = 2.9,
    this.gaze = Offset.zero,
    this.blink = 0,
    this.happy = 0,
    this.mouth = 1,
  });

  /// Height above the floor (hops).
  final double lift;

  /// Positive flattens (landing), negative stretches (airborne).
  final double squash;

  /// Whole-body lean around the feet.
  final double tilt;

  /// Ear sway added to each ear's resting angle.
  final double earLeft;
  final double earRight;

  /// Absolute arm angles: 0 points straight up, pi straight down.
  final double armLeft;
  final double armRight;

  /// Where the eyes look, each axis in -1..1.
  final Offset gaze;

  /// 0 open, 1 closed.
  final double blink;

  /// Smiling squint from the lower lids, 0..1.
  final double happy;

  /// Mouth opening, 1 is the reference smile.
  final double mouth;

  /// Slide 1: waves hello for half the loop, then glances at the sparkles.
  factory MascotRig.wave(double t) {
    final waving = _window(t, 0.0, 0.52);
    final swing = _osc(t, 7) * 0.32 * waving;
    final glance = _window(t, 0.58, 0.88);
    return MascotRig(
      squash: _osc(t, 2) * 0.018,
      tilt: 0.03 * _osc(t, 1) - swing * 0.08,
      earLeft: 0.06 * _osc(t, 2, -0.15) - swing * 0.22,
      earRight: 0.05 * _osc(t, 2, -0.3) + swing * 0.08,
      armLeft: -0.42 + swing,
      armRight: 2.9 + 0.05 * _osc(t, 2),
      gaze: Offset.lerp(
        const Offset(-0.1, 0.1),
        const Offset(0.8, -0.7),
        glance,
      )!,
      blink: _blip(t, 0.54) + _blip(t, 0.94),
      mouth: 1 + waving * 0.06,
    );
  }

  /// Slide 2: leans toward the imaging device, eyes on the lens, ear twitch.
  factory MascotRig.curious(double t) {
    final twitch = _blip(t, 0.32, length: 0.05);
    final hello = _window(t, 0.45, 0.8);
    return MascotRig(
      squash: _osc(t, 2) * 0.014,
      tilt: -0.06 + _osc(t, 1) * 0.025,
      earLeft: -0.06 + _osc(t, 1) * 0.05 - twitch * 0.28,
      earRight: 0.04 + _osc(t, 2, 0.3) * 0.05,
      armLeft: -0.85 + _osc(t, 6) * 0.22 * hello,
      armRight: 2.9,
      gaze: Offset(-0.85 + _osc(t, 1) * 0.1, -0.8),
      blink: _blip(t, 0.86),
      mouth: 0.9,
    );
  }

  /// Slide 3: two celebratory hops with arms up, then a happy sway.
  factory MascotRig.cheer(double t) {
    final hopping = t < 0.5;
    final p = (t * 4) % 1.0;
    final air = hopping && p < 0.55 ? math.sin(p / 0.55 * math.pi) : 0.0;
    final ground =
        hopping && p >= 0.55 ? math.sin((p - 0.55) / 0.45 * math.pi) : 0.0;
    final idle = hopping ? 0.0 : _osc(t, 2) * _window(t, 0.5, 1.0);
    return MascotRig(
      lift: air * 16,
      squash: ground * 0.07 - air * 0.04 + idle * 0.012,
      tilt: idle * 0.05,
      earLeft: -0.08 * ground + 0.1 * air - idle * 0.05,
      earRight: 0.08 * ground - 0.1 * air + idle * 0.05,
      armLeft: -0.62 - air * 0.22 + idle * 0.1,
      armRight: 0.62 + air * 0.22 + idle * 0.1,
      gaze: Offset(-0.15 + idle * 0.2, -0.1),
      happy: 0.55 + air * 0.45,
      mouth: 1.08 + air * 0.12,
    );
  }

  static double _osc(double t, int cycles, [double phase = 0]) =>
      math.sin((t * cycles + phase) * 2 * math.pi);

  static double _smooth(double x) => x * x * (3 - 2 * x);

  /// 0 outside [start, end], easing to 1 inside.
  static double _window(double t, double start, double end) {
    if (t <= start || t >= end) return 0;
    final ramp = (end - start) * 0.2;
    final edge = math.min(t - start, end - t) / ramp;
    return _smooth(edge.clamp(0.0, 1.0));
  }

  /// A short 0→1→0 pulse centred on [at] (blinks, twitches).
  static double _blip(double t, double at, {double length = 0.025}) {
    final d = (t - at).abs() / length;
    return d >= 1 ? 0 : _smooth(1 - d);
  }

  @override
  bool operator ==(Object other) =>
      other is MascotRig &&
      other.lift == lift &&
      other.squash == squash &&
      other.tilt == tilt &&
      other.earLeft == earLeft &&
      other.earRight == earRight &&
      other.armLeft == armLeft &&
      other.armRight == armRight &&
      other.gaze == gaze &&
      other.blink == blink &&
      other.happy == happy &&
      other.mouth == mouth;

  @override
  int get hashCode => Object.hash(lift, squash, tilt, earLeft, earRight,
      armLeft, armRight, gaze, blink, happy, mouth);
}

/// Mascot-specific inks: glossy white vinyl with a cool lavender shade,
/// periwinkle inner ears, grey-blue eyes.
abstract class _Ink {
  static const shade = Color(0xFF6E7398);
  static const enamel = [
    Color(0xFFFFFFFF),
    Color(0xFFFAFAFD),
    Color(0xFFEBECF4),
    Color(0xFFD5D7E6),
  ];
  static const enamelStops = [0.0, 0.35, 0.72, 1.0];
  static const earInner = Color(0xFFC6C9F1);
  static const earInnerDeep = Color(0xFFA6ABE2);
  static const sclera = Color(0xFFEDEEF6);
  static const irisLight = Color(0xFFA9ADC2);
  static const iris = Color(0xFF8A8EA6);
  static const irisDeep = Color(0xFF535770);
  static const pupil = Color(0xFF2E3146);
  static const lid = Color(0xFF262A4A);
  static const mouth = Color(0xFF7A2A39);
  static const mouthDeep = Color(0xFF45141F);
  static const tongue = Color(0xFFF2A0A8);
  static const tongueDeep = Color(0xFFDD7C88);
}

/// A limb or ear attached at [pivot], [length] long and [width] wide.
typedef _Part = ({Offset pivot, double length, double width});

class _MascotPainter extends CustomPainter {
  const _MascotPainter(this.rig);

  final MascotRig rig;

  static const _Part _earL = (pivot: Offset(80, 104), length: 106, width: 64);
  static const _Part _earR = (pivot: Offset(132, 104), length: 96, width: 57);
  static const double _earLRest = -0.33;
  static const double _earRRest = 0.58;
  static const _Part _armL = (pivot: Offset(44, 190), length: 60, width: 36);
  static const _Part _armR = (pivot: Offset(176, 186), length: 60, width: 30);

  static const Rect _footL = Rect.fromLTWH(47, 254, 42, 22);
  static const Rect _footR = Rect.fromLTWH(122, 253.5, 40, 21);

  static const Rect _eyeL = Rect.fromLTWH(53, 139, 30, 32);
  static const Rect _eyeR = Rect.fromLTWH(128.5, 143, 27, 30);

  /// Tooth-shaped body: two crown lobes, slightly wider on the right for a
  /// three-quarter feel, and two roots ending inside the feet.
  static final Path _body = Path()
    ..moveTo(30, 142)
    ..cubicTo(29, 112, 40, 92, 60, 86)
    ..cubicTo(78, 81, 96, 88, 106, 95)
    ..cubicTo(116, 88, 136, 81, 154, 85)
    ..cubicTo(178, 91, 190, 112, 189, 142)
    ..cubicTo(188, 168, 183, 186, 179, 200)
    ..cubicTo(173, 220, 166, 240, 160, 252)
    ..cubicTo(156, 262, 134, 262, 129, 252)
    ..cubicTo(124, 240, 120, 224, 106, 222)
    ..cubicTo(93, 224, 89, 240, 84, 252)
    ..cubicTo(79, 262, 58, 262, 54, 252)
    ..cubicTo(49, 236, 44, 214, 40, 198)
    ..cubicTo(35, 180, 31, 162, 30, 142)
    ..close();

  static final Rect _bodyBounds = _body.getBounds();

  /// Shared enamel shader so lids and limbs match the body exactly.
  static Shader _enamel(Rect bounds, {Alignment center = const Alignment(-0.4, -0.55)}) {
    return RadialGradient(
      center: center,
      radius: 1.15,
      colors: _Ink.enamel,
      stops: _Ink.enamelStops,
    ).createShader(bounds);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / Mascot.designSize.width);

    _paintContactShadow(canvas);

    // Whole-body motion pivots at the feet so squash keeps them planted.
    const f = Mascot.feet;
    canvas.translate(f.dx, f.dy - rig.lift);
    canvas.rotate(rig.tilt);
    canvas.scale(1 + rig.squash * 0.6, 1 - rig.squash);
    canvas.translate(-f.dx, -f.dy);

    final earL = _ear(_earL, _earLRest + rig.earLeft, innerShift: 0.07);
    final earR = _ear(_earR, _earRRest + rig.earRight, innerShift: -0.07);
    final armL = _limb(_armL, rig.armLeft, mirror: false);
    final armR = _limb(_armR, rig.armRight, mirror: true);

    // Back to front: far arm, ears, body, face, near arm, feet.
    _paintLimb(canvas, armR);
    _paintEar(canvas, earR);
    _paintEar(canvas, earL);
    _paintEarOcclusion(canvas, earL.outer, earR.outer);
    _paintBody(canvas, armL.outer);
    _paintEye(canvas, _eyeL);
    _paintEye(canvas, _eyeR);
    _paintMouth(canvas);
    _paintLimb(canvas, armL);
    _paintFoot(canvas, _footL);
    _paintFoot(canvas, _footR);

    canvas.restore();
  }

  void _paintContactShadow(Canvas canvas) {
    final lifted = (rig.lift / 24).clamp(0.0, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Mascot.feet.translate(0, -2),
        width: 128 * (1 - lifted * 0.35),
        height: 14 * (1 - lifted * 0.3),
      ),
      Paint()
        ..color = OnboardingPalette.shadow.withValues(alpha: 0.42 * (1 - lifted * 0.6))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  // ── Geometry ──────────────────────────────────────────────────

  static Matrix4 _jointTransform(Offset pivot, double angle, {bool mirror = false}) {
    return Matrix4.identity()
      ..translateByDouble(pivot.dx, pivot.dy, 0, 1)
      ..rotateZ(angle)
      ..scaleByDouble(mirror ? -1 : 1, 1, 1, 1);
  }

  /// Spoon-shaped ear pointing up from its base at the origin.
  static Path _earPath(double w, double l) {
    return Path()
      ..moveTo(-0.30 * w, 0)
      ..cubicTo(-0.44 * w, -0.20 * l, -0.54 * w, -0.44 * l, -0.52 * w, -0.64 * l)
      ..cubicTo(-0.50 * w, -0.88 * l, -0.30 * w, -1.0 * l, 0, -1.0 * l)
      ..cubicTo(0.30 * w, -1.0 * l, 0.50 * w, -0.88 * l, 0.52 * w, -0.64 * l)
      ..cubicTo(0.54 * w, -0.44 * l, 0.44 * w, -0.20 * l, 0.30 * w, 0)
      ..close();
  }

  ({Path outer, Path inner}) _ear(_Part part, double angle,
      {required double innerShift}) {
    final m = _jointTransform(part.pivot, angle).storage;
    final w = part.width;
    final l = part.length;
    final inner = _earPath(w * 0.6, l * 0.74)
        .shift(Offset(w * innerShift, -l * 0.15));
    return (outer: _earPath(w, l).transform(m), inner: inner.transform(m));
  }

  /// Mitten hand pointing up from the shoulder, thumb on the +x side.
  static Path _mittenPath(double w, double l) {
    return Path()
      ..moveTo(-0.34 * w, 0)
      ..cubicTo(-0.48 * w, -0.35 * l, -0.56 * w, -0.74 * l, -0.36 * w, -0.94 * l)
      ..cubicTo(-0.16 * w, -1.05 * l, 0.12 * w, -1.0 * l, 0.17 * w, -0.86 * l)
      ..cubicTo(0.26 * w, -0.93 * l, 0.50 * w, -0.86 * l, 0.47 * w, -0.69 * l)
      ..cubicTo(0.45 * w, -0.57 * l, 0.31 * w, -0.56 * l, 0.30 * w, -0.50 * l)
      ..cubicTo(0.34 * w, -0.30 * l, 0.40 * w, -0.12 * l, 0.34 * w, 0)
      ..cubicTo(0.30 * w, 0.16 * l, -0.30 * w, 0.16 * l, -0.34 * w, 0)
      ..close();
  }

  ({Path outer, Path groove}) _limb(_Part part, double angle,
      {required bool mirror}) {
    final m = _jointTransform(part.pivot, angle, mirror: mirror).storage;
    final w = part.width;
    final l = part.length;
    final groove = Path()
      ..moveTo(0.17 * w, -0.86 * l)
      ..quadraticBezierTo(0.20 * w, -0.66 * l, 0.30 * w, -0.52 * l);
    return (
      outer: _mittenPath(w, l).transform(m),
      groove: groove.transform(m),
    );
  }

  // ── Layers ────────────────────────────────────────────────────

  /// Glossy vinyl fill with edge falloff and a mint rim, shared by every
  /// white part so they read as one material.
  void _paintVinyl(Canvas canvas, Path path, {double depth = 1}) {
    final bounds = path.getBounds();
    canvas.drawPath(path, Paint()..shader = _enamel(bounds));

    canvas.save();
    canvas.clipPath(path);
    // Rounded volume: a soft band inside the edges facing away from the
    // key light.
    canvas.drawPath(
      path.shift(Offset(-5 * depth, -6 * depth)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22 * depth
        ..color = _Ink.shade.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * depth),
    );
    // Bounce light from the turquoise surroundings.
    canvas.drawPath(
      path.shift(Offset(-1.6 * depth, -2 * depth)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5 * depth
        ..color = AppColors.mintGreen.withValues(alpha: 0.75)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * depth),
    );
    canvas.restore();
  }

  void _paintOutline(Canvas canvas, Path path) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = _Ink.shade.withValues(alpha: 0.10),
    );
  }

  void _paintEar(Canvas canvas, ({Path outer, Path inner}) ear) {
    _paintVinyl(canvas, ear.outer, depth: 0.6);

    final bounds = ear.inner.getBounds();
    canvas.save();
    canvas.clipPath(ear.outer);
    canvas.drawPath(
      ear.inner,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_Ink.earInner, _Ink.earInnerDeep],
        ).createShader(bounds),
    );
    canvas.save();
    canvas.clipPath(ear.inner);
    // The outer rim overhangs the inner ear and shades its upper edge.
    canvas.drawPath(
      ear.inner.shift(const Offset(2.5, 3.5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = _Ink.shade.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // Soft sheen down the middle of the inner ear.
    canvas.drawOval(
      Rect.fromCenter(
        center: bounds.center.translate(-bounds.width * 0.08, bounds.height * 0.05),
        width: bounds.width * 0.35,
        height: bounds.height * 0.55,
      ),
      Paint()
        ..color = AppColors.white.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.restore();
    canvas.restore();

    _paintOutline(canvas, ear.outer);
  }

  /// Where the ears tuck behind the head they fall into its shadow.
  void _paintEarOcclusion(Canvas canvas, Path earL, Path earR) {
    canvas.save();
    canvas.clipPath(Path.combine(PathOperation.union, earL, earR));
    canvas.drawPath(
      _body,
      Paint()
        ..color = _Ink.shade.withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.restore();
  }

  void _paintBody(Canvas canvas, Path nearArm) {
    _paintVinyl(canvas, _body);

    canvas.save();
    canvas.clipPath(_body);

    // Contact shading from the raised arm and the feet.
    final occlusion = Paint()
      ..color = _Ink.shade.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(nearArm.shift(const Offset(4, 4)), occlusion);
    canvas.drawOval(_footL.shift(const Offset(0, -4)), occlusion);
    canvas.drawOval(_footR.shift(const Offset(0, -4)), occlusion);

    // Shadow under the arch between the roots.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(106, 236), width: 34, height: 34),
      Paint()
        ..color = _Ink.shade.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Specular highlights on the crown lobes and the lit flank.
    final spec = Paint()
      ..color = AppColors.white.withValues(alpha: 0.95)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    _drawRotatedOval(canvas, const Offset(68, 97), 32, 12, -0.32, spec);
    _drawRotatedOval(
      canvas,
      const Offset(146, 94),
      22,
      8,
      0.2,
      spec..color = AppColors.white.withValues(alpha: 0.7),
    );
    _drawRotatedOval(
      canvas,
      const Offset(41, 160),
      7,
      40,
      0.05,
      Paint()
        ..color = AppColors.white.withValues(alpha: 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();

    _paintOutline(canvas, _body);
  }

  void _paintEye(Canvas canvas, Rect eye) {
    final c = eye.center;
    final w = eye.width;
    final h = eye.height;

    // The eye sits in a soft socket with a lit lower bevel; both soften as
    // the lids close so a blink leaves no ring behind.
    final open = (1 - rig.blink) * (1 - rig.happy * 0.5);
    canvas.drawOval(
      eye.inflate(1.5).shift(const Offset(0, -0.6)),
      Paint()
        ..color = _Ink.shade.withValues(alpha: 0.28 * open)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
    );
    canvas.drawOval(
      eye.shift(const Offset(0.4, 1.8)),
      Paint()
        ..color = AppColors.white.withValues(alpha: open)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(eye));
    canvas.drawOval(eye, Paint()..color = _Ink.sclera);

    final irisR = w * 0.45;
    final irisC = c.translate(
      rig.gaze.dx.clamp(-1.0, 1.0) * w * 0.13,
      rig.gaze.dy.clamp(-1.0, 1.0) * h * 0.1 + h * 0.03,
    );
    final irisRect = Rect.fromCircle(center: irisC, radius: irisR);
    canvas.drawCircle(
      irisC,
      irisR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.2, 0.5),
          radius: 0.9,
          colors: [_Ink.irisLight, _Ink.iris, _Ink.irisDeep],
          stops: [0.0, 0.5, 1.0],
        ).createShader(irisRect),
    );
    canvas.drawCircle(
      irisC.translate(0, -irisR * 0.05),
      irisR * 0.5,
      Paint()
        ..color = _Ink.pupil.withValues(alpha: 0.9)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, irisR * 0.08),
    );

    // Shadow cast by the upper lid.
    canvas.drawRect(
      Rect.fromLTRB(eye.left, eye.top, eye.right, eye.top + h * 0.4),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _Ink.lid.withValues(alpha: 0.45),
            _Ink.lid.withValues(alpha: 0.0),
          ],
        ).createShader(eye),
    );

    // Big glossy catch-light and a small bounce light.
    _drawRotatedOval(
      canvas,
      irisC.translate(irisR * 0.34, -irisR * 0.4),
      irisR * 0.7,
      irisR * 0.52,
      -0.4,
      Paint()..color = AppColors.white.withValues(alpha: 0.95),
    );
    canvas.drawCircle(
      irisC.translate(-irisR * 0.42, irisR * 0.45),
      irisR * 0.13,
      Paint()..color = AppColors.white.withValues(alpha: 0.75),
    );

    canvas.restore();

    // Lids use the body's own shader so they melt into the face. They reach
    // just past the eye so no anti-aliased rim of the eye shows through.
    if (rig.blink > 0 || rig.happy > 0) {
      final lid = Paint()..shader = _enamel(_bodyBounds);
      final cover = eye.inflate(0.6);
      canvas.save();
      canvas.clipPath(Path()..addOval(cover));
      if (rig.blink > 0) {
        final lidLineY = c.dy - (h / 2) * (1 - 2 * rig.blink);
        canvas.drawRect(
          Rect.fromLTRB(cover.left, cover.top, cover.right, lidLineY),
          lid,
        );
      }
      if (rig.happy > 0) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(c.dx, eye.bottom + h * 0.5 - rig.happy * h * 0.42),
            width: w * 1.6,
            height: h * 1.1,
          ),
          lid,
        );
      }
      canvas.restore();
    }

    // Upper lid line. Scaling it through the centre turns it into a closed,
    // smiling curve at the bottom of a blink.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1, 1 - 2 * rig.blink);
    canvas.drawArc(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      math.pi * 1.06,
      math.pi * 0.88,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..color = _Ink.lid,
    );
    canvas.restore();
  }

  void _paintMouth(Canvas canvas) {
    const top = 172.0;
    final bottom = top + 22 * rig.mouth;
    final depth = bottom - top;
    final mouth = Path()
      ..moveTo(88, top)
      ..quadraticBezierTo(105, top + 2.5, 122, top - 0.5)
      ..cubicTo(123.5, top + depth * 0.6, 115, bottom, 105, bottom)
      ..cubicTo(95, bottom, 86, top + depth * 0.6, 88, top)
      ..close();
    final bounds = mouth.getBounds();

    // Recess and the lit lower lip.
    canvas.drawPath(
      mouth.shift(const Offset(0, -0.6)),
      Paint()
        ..color = _Ink.shade.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );
    canvas.drawPath(
      mouth.shift(const Offset(0, 1.8)),
      Paint()
        ..color = AppColors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
    canvas.drawPath(
      mouth,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_Ink.mouthDeep, _Ink.mouth],
        ).createShader(bounds),
    );

    canvas.save();
    canvas.clipPath(mouth);
    final tongue = Rect.fromCenter(
      center: Offset(105.5, bottom - depth * 0.12),
      width: 25,
      height: depth * 0.62,
    );
    canvas.drawOval(
      tongue,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.4),
          colors: [_Ink.tongue, _Ink.tongueDeep],
        ).createShader(tongue),
    );
    // Two buck teeth.
    for (final x in const [97.4, 105.2]) {
      final tooth = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, top - 1, 7.4, 11.5),
        bottomLeft: const Radius.circular(2.4),
        bottomRight: const Radius.circular(2.4),
      );
      canvas.drawRRect(
        tooth,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.white, Color(0xFFE6E7F0)],
          ).createShader(tooth.outerRect),
      );
    }
    // Inner top shadow under the upper lip.
    canvas.drawRect(
      Rect.fromLTRB(bounds.left, top - 2, bounds.right, top + 3),
      Paint()
        ..color = _Ink.mouthDeep.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.restore();
  }

  void _paintLimb(Canvas canvas, ({Path outer, Path groove}) limb) {
    _paintVinyl(canvas, limb.outer, depth: 0.55);
    canvas.drawPath(
      limb.groove,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = _Ink.shade.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
    );
    _paintOutline(canvas, limb.outer);
  }

  void _paintFoot(Canvas canvas, Rect foot) {
    final path = Path()..addOval(foot);
    _paintVinyl(canvas, path, depth: 0.4);
    canvas.drawOval(
      Rect.fromCenter(
        center: foot.topLeft.translate(foot.width * 0.35, foot.height * 0.3),
        width: foot.width * 0.38,
        height: foot.height * 0.22,
      ),
      Paint()
        ..color = AppColors.white.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );
    _paintOutline(canvas, path);
  }

  static void _drawRotatedOval(Canvas canvas, Offset c, double w, double h,
      double angle, Paint paint) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MascotPainter old) => old.rig != rig;
}
