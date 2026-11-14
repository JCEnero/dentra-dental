import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/constants/app_colors.dart';
import '../../dental_explorer/data/tooth_catalog.dart';
import '../../dental_explorer/geometry/dentition_builder.dart';
import '../../dental_explorer/geometry/mesh.dart' show Vec3;
import '../../dental_explorer/geometry/tooth_geometry.dart' show MeshDetail;
import '../../dental_explorer/rendering/dentition_renderer.dart';
import '../../dental_explorer/rendering/orbit_camera.dart';
import '../../scan/data/scan_outcomes.dart' show MouthArea;
import '../../scan/rendering/device_model.dart';
import '../../scan/rendering/device_renderer.dart';
import '../../scan/rendering/scan_scene.dart' show fitPose;
import '../../scan/widgets/report/report_style.dart' show ReportColors;
import '../../scan/widgets/visuals/dental_arch_painter.dart';

/// The picture above the welcome slides: one scene that follows the swipe.
///
/// The DENTRA camera turns slowly in front of a glass orb on the first
/// slide. On the second, 3D teeth of white glass in teal glass gums take its
/// place: each area of the mouth lights up in turn and its photo flies into a
/// glass phone. The phone takes the stage on the third, where its screen marks two
/// areas of the mouth, and on the last it shows a line of past scans with
/// the camera standing beside it.
///
/// Everything is placed from the page position, so a half-finished swipe
/// shows the scene halfway between two slides. Each slide's own motion
/// starts as that slide arrives. Holds still under reduced motion.
///
/// It fills the whole screen and lays the scene out between [top] and
/// [bottom], so its soft light fades out on its own instead of stopping at
/// an edge.
class WelcomeStage extends StatefulWidget {
  const WelcomeStage({
    super.key,
    required this.pageController,
    required this.labelStyle,
    required this.top,
    required this.bottom,
    this.semanticLabel,
  });

  final PageController pageController;

  /// The band of the screen the scene is laid out in.
  final double top;
  final double bottom;

  /// For the one line of words on the stage, the floating note on the
  /// third slide.
  final TextStyle labelStyle;

  /// What the stage shows on the current slide, for screen readers.
  final String? semanticLabel;

  /// The slides the scene is laid out for.
  static const int slideCount = 4;

  @override
  State<WelcomeStage> createState() => _WelcomeStageState();
}

class _WelcomeStageState extends State<WelcomeStage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((elapsed) {
    _clock.value = elapsed.inMicroseconds / 1e6;
  });
  final _clock = ValueNotifier<double>(0);

  final _timeline = _Timeline(WelcomeStage.slideCount);
  bool _still = false;

  /// The 3D teeth, once built. Built in the background while the first
  /// slide shows, so they are ready by the second.
  _TeethScene? _teeth;

  @override
  void initState() {
    super.initState();
    widget.pageController.addListener(_onPage);
    compute(_buildTeeth, null).then((model) {
      if (mounted) setState(() => _teeth = _TeethScene(model));
    }, onError: (Object _) {
      // The flat map of the mouth stands in.
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_still) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(WelcomeStage old) {
    super.didUpdateWidget(old);
    if (old.pageController != widget.pageController) {
      old.pageController.removeListener(_onPage);
      widget.pageController.addListener(_onPage);
    }
  }

  /// A slide arrives once the swipe is past halfway toward it.
  void _onPage() {
    final c = widget.pageController;
    if (!c.hasClients || !c.position.haveDimensions) return;
    final nearest =
        (c.page ?? 0).round().clamp(0, WelcomeStage.slideCount - 1).toInt();
    _timeline.arrive(nearest, _clock.value);
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_onPage);
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _StagePainter(
            controller: widget.pageController,
            clock: _clock,
            timeline: _timeline,
            still: _still,
            labelStyle: widget.labelStyle,
            teeth: _teeth,
            top: widget.top,
            bottom: widget.bottom,
          ),
        ),
      ),
    );
  }
}

/// When each slide's own motion started. The current slide runs from its
/// arrival; the one just left holds where it was, so it fades out without a
/// jump, and picks up from there if the swipe comes straight back. Any other
/// slide waits at its start.
class _Timeline {
  _Timeline(int count)
      : _arrivals = List.filled(count, 0),
        _reached = List.filled(count, 0);

  final List<double> _arrivals;
  final List<double> _reached;
  int _current = 0;
  int _previous = -1;

  void arrive(int slide, double now) {
    if (slide == _current) return;
    _reached[_current] = now - _arrivals[_current];
    _arrivals[slide] = slide == _previous ? now - _reached[slide] : now;
    _previous = _current;
    _current = slide;
  }

  /// Seconds into slide [i]'s motion at [now].
  double local(int i, double now) {
    if (i == _current) return now - _arrivals[i];
    if (i == _previous) return _reached[i];
    return 0;
  }
}

// ── Holds ─────────────────────────────────────────────────────────────

/// Where the camera stands and how it's turned: its centre and length as
/// fractions of the scene's box, then its yaw, pitch and roll (see
/// [DevicePose]). Pitch stays positive, tip toward the viewer, which the
/// renderer's draw order needs.
class _DeviceHold {
  const _DeviceHold({
    required this.x,
    required this.y,
    required this.length,
    required this.yaw,
    required this.pitch,
    required this.roll,
    this.opacity = 1,
    this.sway = 0.07,
  });

  final double x, y, length, yaw, pitch, roll, opacity;

  /// How far it turns back and forth while resting.
  final double sway;

  static _DeviceHold lerp(_DeviceHold a, _DeviceHold b, double t) =>
      _DeviceHold(
        x: ui.lerpDouble(a.x, b.x, t)!,
        y: ui.lerpDouble(a.y, b.y, t)!,
        length: ui.lerpDouble(a.length, b.length, t)!,
        yaw: ui.lerpDouble(a.yaw, b.yaw, t)!,
        pitch: ui.lerpDouble(a.pitch, b.pitch, t)!,
        roll: ui.lerpDouble(a.roll, b.roll, t)!,
        opacity: ui.lerpDouble(a.opacity, b.opacity, t)!,
        sway: ui.lerpDouble(a.sway, b.sway, t)!,
      );

  /// Upright and large, turning slowly to show its sides.
  static const meet = _DeviceHold(
      x: 0.5,
      y: 0.5,
      length: 0.84,
      yaw: -0.4,
      pitch: 0.26,
      roll: -0.14,
      sway: 0.26);

  /// Gone off the left edge, making way for the teeth.
  static const exitLeft = _DeviceHold(
      x: -0.34,
      y: 0.56,
      length: 0.74,
      yaw: -0.3,
      pitch: 0.3,
      roll: -0.9,
      opacity: 0);

  /// Waiting off the right edge for the last slide.
  static const enterRight = _DeviceHold(
      x: 1.32,
      y: 0.6,
      length: 0.6,
      yaw: -0.55,
      pitch: 0.26,
      roll: 0.36,
      opacity: 0);

  /// Beside the phone, leaning toward it.
  static const track = _DeviceHold(
      x: 0.83, y: 0.58, length: 0.62, yaw: -0.55, pitch: 0.26, roll: 0.2);

  /// The hold for page position [p], 0 to 3.
  static _DeviceHold at(double p) {
    // Leaves within the first two thirds of the swipe, so it is gone
    // before the teeth fill its place.
    if (p <= 1) return lerp(meet, exitLeft, _ease(p / 0.7));
    if (p <= 2) return exitLeft;
    return lerp(enterRight, track, _ease(p - 2));
  }
}

/// Where the 3D teeth sit: centre as fractions of the box, a scale, and how
/// much they show.
class _TeethHold {
  const _TeethHold({
    required this.x,
    required this.y,
    this.scale = 1,
    this.opacity = 1,
  });

  final double x, y, scale, opacity;

  static _TeethHold lerp(_TeethHold a, _TeethHold b, double t) => _TeethHold(
        x: ui.lerpDouble(a.x, b.x, t)!,
        y: ui.lerpDouble(a.y, b.y, t)!,
        scale: ui.lerpDouble(a.scale, b.scale, t)!,
        opacity: ui.lerpDouble(a.opacity, b.opacity, t)!,
      );

  static const hidden = _TeethHold(x: 0.3, y: 0.52, scale: 0.72, opacity: 0);
  static const capture = _TeethHold(x: 0.3, y: 0.52);
  static const exit = _TeethHold(x: -0.12, y: 0.52, scale: 0.86, opacity: 0);

  static _TeethHold at(double p) {
    // Grow in once the camera has mostly gone.
    if (p <= 1) return lerp(hidden, capture, _ease((p - 0.3) / 0.7));
    if (p <= 2) return lerp(capture, exit, _ease(p - 1));
    return exit;
  }
}

/// Where the phone sits: centre and height as fractions of the box.
class _PhoneHold {
  const _PhoneHold({
    required this.x,
    required this.y,
    required this.height,
    this.opacity = 1,
  });

  final double x, y, height, opacity;

  static _PhoneHold lerp(_PhoneHold a, _PhoneHold b, double t) => _PhoneHold(
        x: ui.lerpDouble(a.x, b.x, t)!,
        y: ui.lerpDouble(a.y, b.y, t)!,
        height: ui.lerpDouble(a.height, b.height, t)!,
        opacity: ui.lerpDouble(a.opacity, b.opacity, t)!,
      );

  static const hidden = _PhoneHold(x: 1.3, y: 0.52, height: 0.84, opacity: 0);
  static const capture = _PhoneHold(x: 0.755, y: 0.5, height: 0.84);
  static const check = _PhoneHold(x: 0.52, y: 0.5, height: 0.9);
  static const track = _PhoneHold(x: 0.39, y: 0.5, height: 0.88);

  static _PhoneHold at(double p) {
    if (p <= 1) return lerp(hidden, capture, _ease(p));
    if (p <= 2) return lerp(capture, check, _ease(p - 1));
    return lerp(check, track, _ease(p - 2));
  }
}

double _ease(double t) => Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));

/// [v] mapped from [a]..[b] to 0..1, clamped.
double _span(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0);

/// How much of slide [i] shows at page position [p], 0 to 1.
double _weight(double p, int i) => (1 - (p - i).abs()).clamp(0.0, 1.0);

// ── The phone's layout ────────────────────────────────────────────────

/// The phone's parts, worked out from its outline.
class _Phone {
  _Phone(this.rect);

  final Rect rect;

  double get w => rect.width;
  double get radius => w * 0.17;
  RRect get body => RRect.fromRectAndRadius(rect, Radius.circular(radius));
  double get inset => w * 0.045;
  RRect get screen => RRect.fromRectAndRadius(
      rect.deflate(inset), Radius.circular(radius - inset));

  /// Where a screen's content goes, under the camera island.
  Rect get content => Rect.fromLTRB(rect.left + w * 0.11, rect.top + w * 0.21,
      rect.right - w * 0.11, rect.bottom - w * 0.13);

  /// Below the screen's header lines.
  double get bodyTop => content.top + w * 0.2;

  /// One of the six photo tiles on the capture screen, two across.
  Rect tile(int i) {
    final c = content;
    final gap = c.width * 0.07;
    final tw = (c.width - gap) / 2;
    final th = tw * 0.84;
    return Rect.fromLTWH(
      c.left + (i % 2) * (tw + gap),
      bodyTop + (i ~/ 2) * (th + gap),
      tw,
      th,
    );
  }

  /// The mouth map on the check screen.
  Rect get map {
    final c = content;
    // The map's canvas has a margin round the teeth, so it may reach a
    // little past the content's edges.
    final mw = c.width * 1.08;
    return Rect.fromLTWH(c.center.dx - mw / 2, bodyTop, mw,
        mw * kMouthMapCanvas.height / kMouthMapCanvas.width);
  }
}

// ── The teeth ─────────────────────────────────────────────────────────

/// Top-level so it can run in the background.
DentitionModel _buildTeeth(Object? _) => buildDentition(MeshDetail.low);

/// The 3D teeth and what drawing them needs: a renderer, a style changed
/// every frame, which area each tooth is in, and each area's middle.
class _TeethScene {
  _TeethScene(this.model)
      : renderer = DentitionRenderer(model),
        ownerArea = [
          for (var o = 0; o < 32; o++) MouthArea.of(ToothCatalog.byIndex(o)),
        ] {
    // Teeth in clear, pale teal glass gums, with only the tops of the
    // roots glowing faintly through them.
    style.rootReveal = 0;
    for (final gum in const [kUpperGumOwner, kLowerGumOwner]) {
      style
        ..alpha[gum] = _gumAlpha
        // Toward the palette's light mint, so the glass reads pale.
        ..tintR[gum] = 0.7
        ..tintG[gum] = 0.93
        ..tintB[gum] = 0.91
        ..tint[gum] = 0.35
        ..lift[gum] = 0.3;
    }
    for (final area in MouthArea.values) {
      var sum = const Vec3(0, 0, 0);
      var n = 0;
      for (var o = 0; o < 32; o++) {
        if (ownerArea[o] != area) continue;
        sum = sum + model.anchors[o].crownCenter;
        n++;
      }
      areaCenters[area] = sum * (1 / n);
    }
  }

  final DentitionModel model;
  final DentitionRenderer renderer;
  final SceneStyle style = SceneStyle();
  final List<MouthArea> ownerArea;
  final Map<MouthArea, Vec3> areaCenters = {};

  Size? _fittedFor;
  CameraPose? _fitted;

  /// A camera that fits the teeth and gums in [size], framed at [_teethYaw]
  /// and turned to [yaw].
  CameraPose pose(Size size, double yaw) {
    if (_fittedFor != size || _fitted == null) {
      final crowns = fitPose(model,
          yaw: _teethYaw,
          pitch: 0.16,
          size: size,
          // Teeth and gums both, so the gums never reach the edge.
          include: (o) => true,
          fill: 0.86);
      _fitted = crowns;
      _fittedFor = size;
    }
    return _fitted!.copyWith(yaw: yaw);
  }

  /// Where [p] lands on screen, for a camera [pose] in a box of [size].
  static Offset project(CameraPose pose, Size size, Vec3 p) {
    final r = pose.rotation;
    final x = p.x - pose.target.x,
        y = p.y - pose.target.y,
        z = p.z - pose.target.z;
    final vx = r[0] * x + r[1] * y + r[2] * z;
    final vy = r[3] * x + r[4] * y + r[5] * z;
    final vz = r[6] * x + r[7] * y + r[8] * z;
    final k = DentitionRenderer.focalLength(size) / (pose.distance - vz);
    return Offset(size.width / 2 + vx * k, size.height / 2 - vy * k);
  }
}

// The teeth are white glass: see-through at rest, a little clearer once an
// area's photo is taken.
const double _teethAlpha = 0.4;
const double _teethTakenAlpha = 0.62;

/// The gums are clear glass too: the renderer thickens them toward their
/// edges, from about a quarter to a half of this.
const double _gumAlpha = 0.38;

/// How the teeth face: turned toward the phone, seen a little from above.
const double _teethYaw = 0.38;

// ── The painter ───────────────────────────────────────────────────────

final _renderer = DeviceRenderer(DeviceModel.instance);
const double _distance = 320;
const double _deviceLength = DeviceModel.tipY - DeviceModel.baseY;

/// The order photos arrive in, and the area of the mouth each shows.
const _photoAreas = [
  MouthArea.upperRight,
  MouthArea.upperLeft,
  MouthArea.upperFront,
  MouthArea.lowerFront,
  MouthArea.lowerRight,
  MouthArea.lowerLeft,
];

/// The two areas the check screen marks.
const _marked = {
  MouthArea.upperRight: ReportColors.possible,
  MouthArea.lowerLeft: ReportColors.faint,
};

// The capture slide's loop: a photo leaves every [_photoEvery] seconds and
// lands [_flight] later; all six stay a while, then fade and it starts over.
const double _firstPhoto = 0.55;
const double _photoEvery = 0.72;
const double _flight = 0.68;
const double _captureLoop = 7.6;
const double _captureFade = 7.0;

class _StagePainter extends CustomPainter {
  _StagePainter({
    required this.controller,
    required this.clock,
    required this.timeline,
    required this.still,
    required this.labelStyle,
    required this.teeth,
    required this.top,
    required this.bottom,
  }) : super(repaint: Listenable.merge([controller, clock]));

  final PageController controller;
  final ValueNotifier<double> clock;
  final _Timeline timeline;
  final bool still;
  final TextStyle labelStyle;

  /// Null until built; the flat map of the mouth stands in.
  final _TeethScene? teeth;

  /// The band of the screen the scene is laid out in.
  final double top;
  final double bottom;

  double get _page {
    if (controller.hasClients && controller.position.haveDimensions) {
      return (controller.page ?? 0)
          .clamp(0.0, WelcomeStage.slideCount - 1.0)
          .toDouble();
    }
    return controller.initialPage.toDouble();
  }

  /// Seconds since slide [i] arrived. Under reduced motion every slide
  /// shows its finished state.
  double _local(int i) => still ? 6.2 : timeline.local(i, clock.value);

  /// The box the scene is laid out in, within its [band]: as wide as the
  /// band allows, never so tall that the phone outgrows its half.
  static Rect _box(Rect band) {
    final w = math.min(band.width, 560.0);
    final h = math.min(math.min(band.height, 600.0), w * 1.05);
    return Rect.fromCenter(center: band.center, width: w, height: h);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final band =
        Rect.fromLTRB(0, top, size.width, math.min(bottom, size.height));
    if (size.isEmpty || band.height <= 0) return;
    final box = _box(band);
    final p = _page;
    final t = still ? 0.0 : clock.value;

    final device = _DeviceHold.at(p);
    final pose = _pose(device, box, t);
    final phoneHold = _PhoneHold.at(p);
    final phoneH = phoneHold.height * box.height;
    final phone = _Phone(Rect.fromCenter(
      center: Offset(box.left + phoneHold.x * box.width,
          box.top + phoneHold.y * box.height),
      width: phoneH * 0.49,
      height: phoneH,
    ));

    _paintLight(canvas, size, box, p);
    _paintBubbles(canvas, box, p, t);
    _paintOrb(canvas, box, pose, _weight(p, 0), t);

    if (phoneHold.opacity > 0.01) {
      _layer(canvas, phone.rect.inflate(phone.w * 0.4), phoneHold.opacity,
          () => _paintPhone(canvas, phone, p));
    }

    // Where each photo leaves from: its area of the teeth.
    final origins = _paintTeeth(canvas, box, p, t);

    if (device.opacity > 0.01) {
      _layer(canvas, Offset.zero & size, device.opacity,
          () => _paintDevice(canvas, pose, t));
    }

    final capture = _weight(p, 1);
    if (capture > 0.01 && phoneHold.opacity > 0.01 && origins != null) {
      _paintSending(canvas, box, origins, phone, capture);
    }

    final check = _weight(p, 2);
    if (check > 0.01) _paintNote(canvas, box, phone, check, t);
  }

  /// Runs [draw] at [opacity], on its own layer when it needs one.
  static void _layer(
      Canvas canvas, Rect bounds, double opacity, VoidCallback draw) {
    if (opacity >= 0.995) {
      draw();
      return;
    }
    canvas.saveLayer(
      bounds,
      Paint()..color = Color.fromRGBO(0, 0, 0, opacity.clamp(0.0, 1.0)),
    );
    draw();
    canvas.restore();
  }

  DevicePose _pose(_DeviceHold h, Rect box, double t) {
    final length = h.length * box.height;
    final bob = still ? 0.0 : box.height * 0.012 * math.sin(t * 0.9);
    return DevicePose(
      yaw: h.yaw + (still ? 0 : h.sway * math.sin(t * 0.45)),
      pitch: h.pitch + (still ? 0 : 0.02 * math.sin(t * 0.37)),
      roll: h.roll,
      distance: _distance,
      focal: _distance * length / _deviceLength,
      center:
          Offset(box.left + h.x * box.width, box.top + h.y * box.height + bob),
    );
  }

  // ── Light, bubbles, orb ─────────────────────────────────────────────

  /// Where the stage's light pools on each slide, as fractions of the box.
  static const _lights = [
    Offset(0.5, 0.46),
    Offset(0.5, 0.5),
    Offset(0.52, 0.5),
    Offset(0.5, 0.52),
  ];

  /// A soft white light behind the scene, brighter than the page, so the
  /// glass reads against it, with a breath of mint low down.
  void _paintLight(Canvas canvas, Size size, Rect box, double p) {
    final i = p.floor().clamp(0, _lights.length - 2);
    final at = Offset.lerp(_lights[i], _lights[i + 1], p - i)!;
    final center =
        Offset(box.left + at.dx * box.width, box.top + at.dy * box.height);
    final r = box.height * 0.7;
    final light = Rect.fromCircle(center: center, radius: r);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.white.withValues(alpha: 0.88),
          AppColors.white.withValues(alpha: 0.42),
          AppColors.white.withValues(alpha: 0),
        ], stops: const [
          0,
          0.45,
          1
        ]).createShader(light),
    );
    final mint = Rect.fromCircle(
      center: center + Offset(box.width * 0.18, box.height * 0.36),
      radius: box.height * 0.5,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.g1.withValues(alpha: 0.14),
          AppColors.g1.withValues(alpha: 0),
        ]).createShader(mint),
    );
  }

  /// Small glass beads drifting at different depths, trailing the swipe.
  static const _beads = [
    (0.1, 0.16, 0.034, 0.7),
    (0.9, 0.12, 0.024, 1.0),
    (0.06, 0.8, 0.02, 1.3),
    (0.93, 0.76, 0.04, 0.55),
    (0.66, 0.04, 0.016, 1.1),
  ];

  void _paintBubbles(Canvas canvas, Rect box, double p, double t) {
    for (var i = 0; i < _beads.length; i++) {
      final (x, y, r, depth) = _beads[i];
      final c = Offset(
        box.left + x * box.width - p * box.width * 0.05 * depth,
        box.top +
            y * box.height +
            box.height * 0.012 * math.sin(t * 0.5 + i * 1.7),
      );
      _glassBead(canvas, c, r * box.height);
    }
  }

  static void _glassBead(Canvas canvas, Offset c, double r) {
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [
            AppColors.white.withValues(alpha: 0.95),
            AppColors.white.withValues(alpha: 0.35),
            AppColors.lavender.withValues(alpha: 0.3),
          ],
          stops: const [0, 0.6, 1],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.white.withValues(alpha: 0.9),
    );
  }

  /// A large glass orb behind the camera on the first slide, and the soft
  /// shadow it floats over.
  void _paintOrb(
      Canvas canvas, Rect box, DevicePose pose, double weight, double t) {
    if (weight <= 0.01) return;
    final c = Offset(box.left + 0.5 * box.width, box.top + 0.47 * box.height);
    final r = box.height * 0.36;
    GlassOrb.paint(canvas, c, r, opacity: weight);

    // Contact shadow beneath the base, tighter as it bobs down.
    final base = pose.project(const Vec3(0, DeviceModel.baseY, 0));
    final lift = still ? 0.5 : 0.5 + 0.5 * math.sin(t * 0.9);
    final floor = Offset(base.dx, base.dy + box.height * 0.045);
    canvas.drawOval(
      Rect.fromCenter(
        center: floor,
        width: box.height * (0.2 + 0.03 * lift),
        height: box.height * 0.032,
      ),
      Paint()
        ..color =
            AppColors.g2.withValues(alpha: 0.2 * weight * (1.1 - lift * 0.3))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, box.height * 0.018),
    );
  }

  // ── The camera ──────────────────────────────────────────────────────

  void _paintDevice(Canvas canvas, DevicePose pose, double t) {
    // A soft teal shadow cast down and to the right.
    canvas.drawPath(
      _renderer
          .outline(pose)
          .shift(Offset(pose.focal * 0.03, pose.focal * 0.045)),
      Paint()
        ..color = const Color(0xFF17807D).withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    _renderer.paint(canvas, pose);
    // The white lights glow faintly, as if on.
    DeviceRenderer.paintParts(
      canvas,
      pose,
      lit: still ? 0.3 : 0.3 + 0.12 * math.sin(t * 1.4),
      shine: still ? 0.0 : math.sin(t * 0.45),
    );
  }

  // ── The teeth ───────────────────────────────────────────────────────

  /// The 3D teeth on the second slide. Each area glows teal as its photo is
  /// taken, then stays a little clearer white until the loop starts over. Returns
  /// where each photo leaves from, in [_photoAreas] order, or null when
  /// the teeth are out of sight.
  List<Offset>? _paintTeeth(Canvas canvas, Rect box, double p, double t) {
    final hold = _TeethHold.at(p);
    if (hold.opacity <= 0.01) return null;
    final rect = Rect.fromCenter(
      center:
          Offset(box.left + hold.x * box.width, box.top + hold.y * box.height),
      width: box.width * 0.5,
      height: box.height * 0.8,
    );
    final scene = teeth;
    final local = _local(1);
    final loop = local < 0 ? 0.0 : local % _captureLoop;
    final reset = 1 - _span(loop, _captureFade, _captureFade + 0.45);

    // A breath of mint behind them, so the white glass reads against it.
    final pool = Rect.fromCenter(
        center: rect.center, width: rect.width * 1.3, height: rect.height);
    canvas.drawOval(
      pool,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.g1.withValues(alpha: 0.22 * hold.opacity),
          AppColors.g1.withValues(alpha: 0),
        ]).createShader(pool),
    );

    late List<Offset> origins;
    _layer(canvas, rect.inflate(rect.width * 0.3), hold.opacity, () {
      canvas
        ..save()
        ..translate(rect.center.dx, rect.center.dy)
        ..scale(hold.scale)
        ..translate(-rect.center.dx, -rect.center.dy);
      if (scene == null) {
        _paintFlatTeeth(canvas, rect);
        origins = [for (final _ in _photoAreas) rect.center];
      } else {
        final yaw = _teethYaw + (still ? 0 : 0.2 * math.sin(t * 0.4));
        final pose = scene.pose(rect.size, yaw);
        final style = scene.style;
        for (var o = 0; o < 32; o++) {
          final k = _photoAreas.indexOf(scene.ownerArea[o]);
          final leaves = _firstPhoto + k * _photoEvery;
          final taken =
              still ? 1.0 : _span(loop, leaves - 0.05, leaves + 0.3) * reset;
          // A teal glow that swells as the area is scanned and fades as its
          // photo leaves.
          final scan = still
              ? 0.0
              : (1 - ((loop - leaves + 0.12) / 0.4).abs()).clamp(0.0, 1.0);
          style
            ..alpha[o] = ui.lerpDouble(_teethAlpha, _teethTakenAlpha, taken)!
            ..tintR[o] = 1
            ..tintG[o] = 1
            ..tintB[o] = 1
            ..tint[o] = 0.82
            ..lift[o] = 0.4
            ..glow[o] = scan;
        }
        canvas
          ..save()
          ..translate(rect.left, rect.top);
        scene.renderer.paint(canvas, rect.size, pose, style);
        canvas.restore();
        Offset scaled(Offset q) => rect.center + (q - rect.center) * hold.scale;
        origins = [
          for (final area in _photoAreas)
            scaled(rect.topLeft +
                _TeethScene.project(pose, rect.size, scene.areaCenters[area]!)),
        ];
      }
      canvas.restore();
    });
    return origins;
  }

  /// The flat map of the mouth, white on mint, while the 3D teeth are built.
  static void _paintFlatTeeth(Canvas canvas, Rect rect) {
    final w = math.min(rect.width,
        rect.height * kMouthMapCanvas.width / kMouthMapCanvas.height);
    final map = Rect.fromCenter(
        center: rect.center,
        width: w,
        height: w * kMouthMapCanvas.height / kMouthMapCanvas.width);
    canvas
      ..save()
      ..translate(map.left, map.top);
    MouthMapPainter({
      for (final a in MouthArea.values)
        a: MouthMapStyle(
          fill: AppColors.white.withValues(alpha: 0.8),
          outline: AppColors.g1,
        ),
    }).paint(canvas, map.size);
    canvas.restore();
  }

  // ── Photos on their way to the phone ────────────────────────────────

  /// Each photo flying along an arc from its area of the teeth into its
  /// tile on the phone.
  void _paintSending(Canvas canvas, Rect box, List<Offset> origins,
      _Phone phone, double weight) {
    if (still) return;
    final local = _local(1);
    if (local < 0) return;
    final loop = local % _captureLoop;
    for (var k = 0; k < _photoAreas.length; k++) {
      final f = _span(loop, _firstPhoto + k * _photoEvery,
          _firstPhoto + k * _photoEvery + _flight);
      if (f <= 0 || f >= 1) continue;
      final e = Curves.easeInOutCubic.transform(f);
      final from = origins[k];
      final tile = phone.tile(k);
      final lifted = Offset((from.dx + tile.center.dx) / 2,
          math.min(from.dy, tile.center.dy) - box.height * 0.16);
      final at = _bezier(from, lifted, tile.center, e);
      final scale = ui.lerpDouble(0.3, 1.0, e)!;
      final rect = Rect.fromCenter(
          center: at, width: tile.width * scale, height: tile.height * scale);
      final alpha = weight * _span(f, 0, 0.18);
      _layer(canvas, rect.inflate(20), alpha, () {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.shift(const Offset(0, 6)),
              Radius.circular(rect.width * 0.16)),
          Paint()
            ..color = AppColors.g2.withValues(alpha: 0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        _paintPhoto(canvas, rect, _photoAreas[k]);
      });
    }
  }

  static Offset _bezier(Offset a, Offset c, Offset b, double t) {
    final u = 1 - t;
    return a * (u * u) + c * (2 * u * t) + b * (t * t);
  }

  // ── The phone ───────────────────────────────────────────────────────

  void _paintPhone(Canvas canvas, _Phone phone, double p) {
    final r = phone.rect;
    final w = phone.w;

    // A soft teal shadow, then frosted white glass with a bright rim.
    canvas.drawRRect(
      phone.body.shift(Offset(0, r.height * 0.04)),
      Paint()
        ..color = AppColors.g2.withValues(alpha: 0.2)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.14),
    );
    canvas.drawRRect(
      phone.body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.white.withValues(alpha: 0.96),
            const Color(0xFFE6F6F4).withValues(alpha: 0.9),
          ],
        ).createShader(r),
    );
    canvas.drawRRect(
      phone.body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.g2.withValues(alpha: 0.14),
    );
    canvas.drawRRect(
      phone.body.deflate(1.2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.white,
    );

    final screen = phone.screen;
    canvas.drawRRect(
      screen,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8FDFC), Color(0xFFE7F6F4)],
        ).createShader(screen.outerRect),
    );
    canvas.drawRRect(
      screen,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = AppColors.g2.withValues(alpha: 0.1),
    );

    canvas.save();
    canvas.clipRRect(screen);
    // A glassy reflection across the top corner.
    final glare = Path()
      ..moveTo(screen.left, screen.top)
      ..lineTo(screen.left + w * 0.62, screen.top)
      ..lineTo(screen.left, screen.top + r.height * 0.36)
      ..close();
    canvas.drawPath(
      glare,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.white.withValues(alpha: 0.7),
            AppColors.white.withValues(alpha: 0),
          ],
        ).createShader(glare.getBounds()),
    );

    final screens = [
      (1, _paintCaptureScreen),
      (2, _paintCheckScreen),
      (3, _paintTrackScreen),
    ];
    for (final (i, draw) in screens) {
      // The capture screen stays up while the phone slides in.
      final weight = i == 1 && p < 1 ? 1.0 : _weight(p, i);
      if (weight <= 0.01) continue;
      _layer(canvas, screen.outerRect, weight, () => draw(canvas, phone));
    }
    canvas.restore();

    // The camera island and the home bar.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(r.center.dx, screen.top + w * 0.075),
          width: w * 0.27,
          height: w * 0.07,
        ),
        const Radius.circular(99),
      ),
      Paint()..color = AppColors.navy.withValues(alpha: 0.88),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(r.center.dx, screen.bottom - w * 0.045),
          width: w * 0.3,
          height: w * 0.022,
        ),
        const Radius.circular(99),
      ),
      Paint()..color = AppColors.navy.withValues(alpha: 0.22),
    );
  }

  /// Two quiet lines standing in for a screen's title.
  static void _header(
      Canvas canvas, _Phone phone, double first, double second) {
    final c = phone.content;
    final w = phone.w;
    _bar(canvas, Offset(c.left, c.top), c.width * first, w * 0.045,
        AppColors.navy.withValues(alpha: 0.6));
    _bar(canvas, Offset(c.left, c.top + w * 0.085), c.width * second, w * 0.034,
        AppColors.g2.withValues(alpha: 0.24));
  }

  static void _bar(
      Canvas canvas, Offset at, double width, double height, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(at.dx, at.dy, width, height),
        Radius.circular(height / 2),
      ),
      Paint()..color = color,
    );
  }

  /// Photos filling a grid as they arrive, a line filling under them and
  /// the button that would check them.
  void _paintCaptureScreen(Canvas canvas, _Phone phone) {
    _header(canvas, phone, 0.44, 0.28);
    final local = _local(1);
    final loop = local < 0 ? 0.0 : local % _captureLoop;
    final fade = 1 - _span(loop, _captureFade, _captureFade + 0.45);
    var landed = 0.0;

    for (var k = 0; k < _photoAreas.length; k++) {
      final tile = phone.tile(k);
      final rr =
          RRect.fromRectAndRadius(tile, Radius.circular(tile.width * 0.16));
      // An empty slot waiting for its photo.
      canvas.drawRRect(
        rr,
        Paint()..color = AppColors.white.withValues(alpha: 0.7),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.g2.withValues(alpha: 0.16),
      );
      final lands = _firstPhoto + k * _photoEvery + _flight;
      final pop = still ? 1.0 : _span(loop, lands, lands + 0.32);
      if (pop <= 0 || fade <= 0) continue;
      landed += pop;
      final s = Curves.easeOutBack.transform(pop);
      final shown = Rect.fromCenter(
          center: tile.center, width: tile.width * s, height: tile.height * s);
      _layer(canvas, tile.inflate(6), fade,
          () => _paintPhoto(canvas, shown, _photoAreas[k]));
    }

    // Progress, under the grid.
    final c = phone.content;
    final last = phone.tile(_photoAreas.length - 1);
    final track = Rect.fromLTWH(
        c.left, last.bottom + phone.w * 0.09, c.width, phone.w * 0.028);
    final done = (landed / _photoAreas.length) * fade;
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, Radius.circular(track.height)),
      Paint()..color = AppColors.g2.withValues(alpha: 0.12),
    );
    if (done > 0) {
      final fill = Rect.fromLTWH(
          track.left, track.top, track.width * done, track.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(fill, Radius.circular(track.height)),
        Paint()
          ..shader = const LinearGradient(colors: [AppColors.g1, AppColors.g2])
              .createShader(track),
      );
    }

    // The button the photos lead to, brighter once all six are in.
    final button = Rect.fromLTWH(
        c.left, c.bottom - phone.w * 0.13, c.width, phone.w * 0.13);
    final ready = done >= 0.999 ? 1.0 : 0.45;
    canvas.drawRRect(
      RRect.fromRectAndRadius(button, Radius.circular(button.height / 2)),
      Paint()
        ..shader = LinearGradient(colors: [
          AppColors.cardSolid.withValues(alpha: ready),
          AppColors.g2.withValues(alpha: ready),
        ]).createShader(button),
    );
    _bar(
      canvas,
      Offset(button.center.dx - button.width * 0.18,
          button.center.dy - phone.w * 0.014),
      button.width * 0.36,
      phone.w * 0.028,
      AppColors.white.withValues(alpha: 0.9),
    );
  }

  /// The map of the mouth: a band of light sweeps down it once, and the two
  /// areas it passes over light up in teal and keep a slow pulse.
  void _paintCheckScreen(Canvas canvas, _Phone phone) {
    _header(canvas, phone, 0.5, 0.32);
    final local = _local(2);
    final map = phone.map;
    final scale = map.width / kMouthMapCanvas.width;
    final sweep = still ? 1.0 : _span(local, 0.35, 1.95);
    final lineY = map.top + map.height * Curves.easeInOut.transform(sweep);

    final styles = <MouthArea, MouthMapStyle>{};
    for (final area in MouthArea.values) {
      final flagged = _marked[area];
      final centerY =
          map.top + MouthMapPainter.areaBounds[area]!.center.dy * scale;
      final reveal = flagged == null
          ? 0.0
          : still
              ? 1.0
              : _span(lineY, centerY - 4, centerY + map.height * 0.12);
      styles[area] = MouthMapStyle(
        fill: Color.lerp(
            ReportColors.clear, flagged ?? ReportColors.clear, reveal)!,
        outline: Color.lerp(
            AppColors.g2.withValues(alpha: 0.5), AppColors.white, reveal)!,
        selected: reveal >= 0.999,
      );
    }
    canvas.save();
    canvas.translate(map.left, map.top);
    MouthMapPainter(styles).paint(canvas, Size(map.width, map.height));
    canvas.restore();

    // Slow rings round each marked area once the sweep has passed.
    if (sweep >= 1) {
      final since = still ? 0.6 : local - 1.95;
      for (final area in _marked.keys) {
        final b = MouthMapPainter.areaBounds[area]!;
        final c = map.topLeft + b.center * scale;
        final base = b.longestSide / 2 * scale;
        final k = (since / 2.2) % 1;
        canvas.drawCircle(
          c,
          base + phone.w * 0.02 + phone.w * 0.08 * k,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = AppColors.g1.withValues(alpha: 0.7 * (1 - k)),
        );
      }
    }

    // The band of light.
    if (sweep > 0 && sweep < 1) {
      final band = Rect.fromLTRB(
          map.left - 4, lineY - phone.w * 0.12, map.right + 4, lineY);
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.g1.withValues(alpha: 0),
              AppColors.g1.withValues(alpha: 0.26),
            ],
          ).createShader(band),
      );
      canvas.drawLine(
        Offset(map.left - 2, lineY),
        Offset(map.right + 2, lineY),
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = AppColors.g2.withValues(alpha: 0.85),
      );
    }

    // One line per marked area, under the map.
    final c = phone.content;
    for (var i = 0; i < _marked.length; i++) {
      final show = still ? 1.0 : _span(local, 1.9 + i * 0.15, 2.3 + i * 0.15);
      if (show <= 0) continue;
      final y = map.bottom + phone.w * (0.1 + i * 0.13);
      final color = _marked.values.elementAt(i);
      _layer(canvas, Rect.fromLTWH(c.left - 4, y - 8, c.width + 8, 24), show,
          () {
        canvas.drawCircle(Offset(c.left + phone.w * 0.03, y + phone.w * 0.02),
            phone.w * 0.026, Paint()..color = color);
        _bar(
            canvas,
            Offset(c.left + phone.w * 0.09, y),
            c.width * (0.62 - i * 0.14),
            phone.w * 0.04,
            AppColors.navy.withValues(alpha: 0.42));
      });
    }
  }

  /// A rising line of past scans in a glass panel, and three saved scans
  /// sliding in under it.
  void _paintTrackScreen(Canvas canvas, _Phone phone) {
    _header(canvas, phone, 0.36, 0.24);
    final local = _local(3);
    final c = phone.content;
    final w = phone.w;

    final panel = Rect.fromLTWH(c.left, phone.bodyTop, c.width, c.width * 0.74);
    final rr = RRect.fromRectAndRadius(panel, Radius.circular(w * 0.07));
    canvas.drawRRect(
        rr, Paint()..color = AppColors.white.withValues(alpha: 0.78));
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.g2.withValues(alpha: 0.12),
    );

    // Faint guide lines.
    final plot = panel.deflate(w * 0.06);
    for (var i = 1; i < 3; i++) {
      final y = plot.top + plot.height * i / 3;
      canvas.drawLine(
        Offset(plot.left, y),
        Offset(plot.right, y),
        Paint()
          ..strokeWidth = 1
          ..color = AppColors.g2.withValues(alpha: 0.08),
      );
    }

    const values = [0.34, 0.42, 0.4, 0.56, 0.62, 0.8];
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(plot.left + plot.width * i / (values.length - 1),
            plot.bottom - plot.height * values[i]),
    ];
    final line = _smooth(points);
    final draw = still ? 1.0 : _span(local, 0.3, 1.7);
    if (draw > 0) {
      final metric = line.computeMetrics().first;
      final shown = metric.extractPath(0, metric.length * draw);
      final tip = metric.getTangentForOffset(metric.length * draw)!.position;
      final area = Path.from(shown)
        ..lineTo(tip.dx, plot.bottom)
        ..lineTo(plot.left, plot.bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.g1.withValues(alpha: 0.3),
              AppColors.g1.withValues(alpha: 0),
            ],
          ).createShader(plot),
      );
      canvas.drawPath(
        shown,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.018
          ..strokeCap = StrokeCap.round
          ..shader = const LinearGradient(colors: [AppColors.g1, AppColors.g2])
              .createShader(plot),
      );
      for (var i = 0; i < points.length; i++) {
        final reached = i / (points.length - 1) <= draw + 0.001;
        if (!reached) continue;
        final last = i == points.length - 1;
        final dot = w * (last ? 0.03 : 0.02);
        if (last && !still) {
          final k = ((local - 1.7) / 1.8) % 1;
          if (local > 1.7) {
            canvas.drawCircle(
              points[i],
              dot + w * 0.07 * k,
              Paint()..color = AppColors.g1.withValues(alpha: 0.3 * (1 - k)),
            );
          }
        }
        canvas.drawCircle(points[i], dot, Paint()..color = AppColors.white);
        canvas.drawCircle(
          points[i],
          dot,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.012
            ..color = AppColors.g2,
        );
      }
    }

    // Saved scans, each with a small map of the mouth.
    final rowH = w * 0.15;
    for (var i = 0; i < 3; i++) {
      final show = still ? 1.0 : _span(local, 0.55 + i * 0.14, 0.95 + i * 0.14);
      if (show <= 0) continue;
      final top = panel.bottom + w * 0.07 + i * (rowH + w * 0.045);
      if (top + rowH > c.bottom + w * 0.04) break;
      final row = Rect.fromLTWH(
          c.left + (1 - Curves.easeOutCubic.transform(show)) * w * 0.25,
          top,
          c.width,
          rowH);
      _layer(canvas, row.inflate(4), show, () {
        final rrow = RRect.fromRectAndRadius(row, Radius.circular(rowH * 0.32));
        canvas.drawRRect(
            rrow, Paint()..color = AppColors.white.withValues(alpha: 0.72));
        canvas.drawRRect(
          rrow,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = AppColors.g2.withValues(alpha: 0.1),
        );
        final thumb = Rect.fromCircle(
            center: Offset(row.left + rowH * 0.5, row.center.dy),
            radius: rowH * 0.34);
        canvas.drawCircle(thumb.center, thumb.width / 2,
            Paint()..color = AppColors.lightLavender);
        canvas.save();
        canvas.clipPath(Path()..addOval(thumb));
        final mapRect = Rect.fromCenter(
          center: thumb.center,
          width: thumb.width * 0.86,
          height: thumb.width *
              0.86 *
              kMouthMapCanvas.height /
              kMouthMapCanvas.width,
        );
        canvas.translate(mapRect.left, mapRect.top);
        canvas.scale(mapRect.width / kMouthMapCanvas.width);
        canvas.drawPicture(_mouthPicture);
        canvas.restore();
        _bar(
            canvas,
            Offset(row.left + rowH * 1.02, row.center.dy - w * 0.04),
            row.width * (0.42 - i * 0.06),
            w * 0.034,
            AppColors.navy.withValues(alpha: 0.5));
        _bar(canvas, Offset(row.left + rowH * 1.02, row.center.dy + w * 0.012),
            row.width * 0.28, w * 0.026, AppColors.g2.withValues(alpha: 0.22));
        canvas.drawCircle(
          Offset(row.right - rowH * 0.42, row.center.dy),
          w * 0.018,
          Paint()
            ..color =
                i == 0 ? AppColors.g2 : AppColors.g1.withValues(alpha: 0.6),
        );
      });
    }
  }

  /// A smooth curve through [points] (Catmull-Rom as cubic Béziers).
  static Path _smooth(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[math.max(i - 1, 0)];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = points[math.min(i + 2, points.length - 1)];
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  // ── Photos ──────────────────────────────────────────────────────────

  /// The whole mouth map, white teeth on clear, drawn once and reused.
  static final ui.Picture _mouthPicture = () {
    final recorder = ui.PictureRecorder();
    MouthMapPainter({
      for (final a in MouthArea.values)
        a: MouthMapStyle(
          fill: AppColors.white,
          outline: AppColors.g2.withValues(alpha: 0.45),
        ),
    }).paint(Canvas(recorder), kMouthMapCanvas);
    return recorder.endRecording();
  }();

  /// A "photo" of one area of the mouth: its teeth, close up, on mint.
  static void _paintPhoto(Canvas canvas, Rect rect, MouthArea area) {
    final rr =
        RRect.fromRectAndRadius(rect, Radius.circular(rect.width * 0.16));
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.lightLavender, AppColors.lavender],
        ).createShader(rect),
    );
    // A little of the neighbouring teeth, so each reads as part of a mouth.
    final b = MouthMapPainter.areaBounds[area]!.inflate(24);
    final s = math.max(rect.width / b.width, rect.height / b.height);
    canvas.translate(
        rect.center.dx - b.center.dx * s, rect.center.dy - b.center.dy * s);
    canvas.scale(s);
    canvas.drawPicture(_mouthPicture);
    canvas.restore();
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.white,
    );
  }

  // ── The note beside the phone on the third slide ────────────────────

  void _paintNote(
      Canvas canvas, Rect box, _Phone phone, double weight, double t) {
    final local = _local(2);
    final pop = still ? 1.0 : _span(local, 2.0, 2.45);
    if (pop <= 0) return;
    final s = Curves.easeOutBack.transform(pop);

    final words = TextPainter(
      text: TextSpan(text: '2 areas to watch', style: labelStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final disc = words.height + 12;
    const padH = 10.0, padV = 8.0;
    final width = padH + disc + 8 + words.width + padH + 4;
    final height = disc + padV * 2;

    // Over the phone's lower left edge, under the lines it sums up, kept
    // inside the stage.
    final bob = still ? 0.0 : 3 * math.sin(t * 1.1);
    final left = (phone.rect.left - width * 0.36)
        .clamp(box.left + 6, box.right - width - 6)
        .toDouble();
    final top = phone.rect.top + phone.w * 1.66 + bob;
    final card = Rect.fromLTWH(left, top, width, height);

    canvas.save();
    canvas.translate(card.center.dx, card.center.dy);
    canvas.scale(s);
    canvas.translate(-card.center.dx, -card.center.dy);
    _layer(canvas, card.inflate(30), weight * pop.clamp(0.0, 1.0), () {
      final rr = RRect.fromRectAndRadius(card, Radius.circular(height * 0.38));
      // Clear glass: a faint shadow, a thin wash of white with the page
      // showing through, and a bright rim.
      canvas.drawRRect(
        rr.shift(const Offset(0, 6)),
        Paint()
          ..color = AppColors.g2.withValues(alpha: 0.07)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.white.withValues(alpha: 0.55),
              AppColors.lightLavender.withValues(alpha: 0.3),
            ],
          ).createShader(card),
      );
      canvas.drawRRect(
        rr.deflate(0.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = AppColors.white.withValues(alpha: 0.85),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = AppColors.g2.withValues(alpha: 0.1),
      );
      final dc = Offset(card.left + padH + disc / 2, card.center.dy);
      canvas.drawCircle(dc, disc / 2,
          Paint()..color = AppColors.white.withValues(alpha: 0.6));
      const icon = Icons.visibility_rounded;
      final glyph = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: disc * 0.56,
            color: AppColors.primary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      glyph.paint(canvas, dc - Offset(glyph.width / 2, glyph.height / 2));
      words.paint(canvas,
          Offset(dc.dx + disc / 2 + 8, card.center.dy - words.height / 2));
    });
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StagePainter old) =>
      old.controller != controller ||
      old.clock != clock ||
      old.timeline != timeline ||
      old.still != still ||
      old.labelStyle != labelStyle ||
      old.teeth != teeth ||
      old.top != top ||
      old.bottom != bottom;
}

/// A large sphere of frosted glass: white at the top left fading toward
/// clear, a bright rim and a faint inner ring.
abstract class GlassOrb {
  static void paint(Canvas canvas, Offset c, double r, {double opacity = 1}) {
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.white.withValues(alpha: 0.7 * opacity),
            AppColors.white.withValues(alpha: 0.22 * opacity),
            AppColors.lavender.withValues(alpha: 0.28 * opacity),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.white.withValues(alpha: 0.95 * opacity),
    );
    canvas.drawCircle(
      c,
      r * 0.86,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.g2.withValues(alpha: 0.07 * opacity),
    );
    // A soft highlight near the top, like light on curved glass.
    final hi = Rect.fromCenter(
      center: c + Offset(-r * 0.32, -r * 0.55),
      width: r * 0.9,
      height: r * 0.4,
    );
    canvas.drawOval(
      hi,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.white.withValues(alpha: 0.75 * opacity),
          AppColors.white.withValues(alpha: 0),
        ]).createShader(hi),
    );
  }
}
