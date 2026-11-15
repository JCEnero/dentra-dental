import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../dental_explorer/geometry/mesh.dart';
import '../data/models/captured_image.dart';
import '../rendering/device_model.dart';
import '../rendering/device_renderer.dart';
import 'scan_motion.dart';
import 'scan_theme.dart';

/// The top of the start page: the DENTRA device floating over a glass stage,
/// its head breaking out above the card, with the headline beside it. The
/// device flashes nine times and a bar counts the photos. Still under reduced
/// motion.
class ScanHero extends StatefulWidget {
  const ScanHero({
    super.key,
    this.height = 300,
    this.source = CaptureSource.phoneCamera,
  });

  /// Height of the stage. The device scales with it.
  final double height;

  /// What this scan will capture with, named in the facts by the headline.
  final CaptureSource source;

  @override
  State<ScanHero> createState() => _ScanHeroState();
}

class _ScanHeroState extends State<ScanHero>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((elapsed) {
    _seconds.value = elapsed.inMicroseconds / 1e6;
  });
  final _seconds = ValueNotifier<double>(0);
  bool _still = false;

  /// How far the device rises above the top of the card, into the header.
  static const double _rise = 56;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = ScanMotion.reduced(context);
    if (_still) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Very large text gets its own room under the device, not beside it, and
    // the device stays inside the card, clear of the bigger page title.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.25;
    final rise = stacked ? 0.0 : _rise;

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final copy = _HeroCopy(
        width: width,
        source: widget.source,
        seconds: _seconds,
        still: _still,
        stacked: stacked,
      );

      return Stack(
        clipBehavior: Clip.none,
        children: [
          GlassCard(
            width: width,
            borderRadius: const BorderRadius.all(Radius.circular(30)),
            borderWidth: 1.4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: widget.height,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _StagePainter(
                              rise: rise,
                              centered: stacked,
                            ),
                          ),
                        ),
                      ),
                      if (!stacked)
                        Positioned(
                          left: 20,
                          top: 20,
                          bottom: 18,
                          width: width * 0.66,
                          child: copy,
                        ),
                    ],
                  ),
                ),
                if (stacked)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    child: copy,
                  ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: -rise,
            height: widget.height + rise,
            child: IgnorePointer(
              child: Semantics(
                image: true,
                label: 'The Dentra intraoral camera: a handheld wand with a '
                    'lens and a ring of lights in its round tip, and Capture '
                    'and Light buttons on its handle.',
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _DevicePainter(
                      seconds: _seconds,
                      still: _still,
                      centered: stacked,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// The nine-photo story, in seconds from the start of a loop.
abstract class HeroStory {
  static const int photos = 9;
  static const double firstPhoto = 1.0;
  static const double between = 0.9;

  /// All nine are in: the bar stays full for a moment.
  static const double complete = firstPhoto + between * (photos - 1) + 0.5;

  /// The bar empties, one dash at a time.
  static const double clear = complete + 2.2;
  static const double loop = clear + 1.2;

  /// A still picture for reduced motion: all nine in.
  static const double restful = complete + 1;

  static double takenAt(int i) => firstPhoto + between * i;

  static int taken(double t) {
    var n = 0;
    for (var i = 0; i < photos; i++) {
      if (t >= takenAt(i)) n++;
    }
    return n;
  }

  /// How full dash [i] of the bar is, 0-1.
  static double filled(int i, double t) {
    final inn = ((t - takenAt(i)) / 0.22).clamp(0.0, 1.0);
    final out = ((t - (clear + i * 0.05)) / 0.3).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(inn) * (1 - out);
  }

  /// The white LEDs firing for each photo, 0-1.
  static double flash(double t) {
    var f = 0.0;
    for (var i = 0; i < photos; i++) {
      final since = t - takenAt(i);
      if (since >= 0 && since < 0.42) f = math.max(f, 1 - since / 0.42);
    }
    return f;
  }
}

// ── How the device is posed ───────────────────────────────────────

const double _restYaw = -0.46;
const double _restPitch = 0.42;
const double _roll = -0.36;
const double _distance = 320;

/// The device on a canvas of [size]: as big as the height allows, standing
/// clear of the headline, and set to the right unless [centered].
///
/// In the resting pose it reaches these many millimetres from its origin, as
/// seen on screen, perspective included.
DevicePose _heroPose(
  Size size, {
  required bool centered,
  double yaw = _restYaw,
  double pitch = _restPitch,
  double bob = 0,
}) {
  const up = 84.0, down = 71.5, right = 39.0, left = 35.6;
  const marginY = 7.0, marginRight = 16.0;
  // The facts beside the device end about here.
  const copyEdge = 168.0;

  final byHeight = (size.height - marginY * 2) / (up + down);
  final byWidth = centered
      ? byHeight
      : (size.width - copyEdge - marginRight) / (right + left);
  final millimetre = math.min(byHeight, byWidth);
  return DevicePose(
    yaw: yaw,
    pitch: pitch,
    roll: _roll,
    distance: _distance,
    focal: millimetre * _distance,
    center: Offset(
      centered
          ? size.width / 2 + (left - right) / 2 * millimetre
          : size.width - marginRight - right * millimetre,
      size.height - marginY - down * millimetre + bob,
    ),
  );
}

final _deviceRenderer = DeviceRenderer(DeviceModel.instance);

// ── The stage behind the device ───────────────────────────────────

/// Light pooled on the glass, and the device's soft shadow. Painted once and
/// kept by its boundary, so the blur costs nothing per frame.
class _StagePainter extends CustomPainter {
  const _StagePainter({required this.rise, required this.centered});

  final double rise;
  final bool centered;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final deviceCanvas = Size(size.width, size.height + rise);
    final pose = _heroPose(deviceCanvas, centered: centered);
    final head = pose.project(const Vec3(0, DeviceModel.headY, 0));

    final pool = Rect.fromCircle(
      center: Offset(size.width, size.height),
      radius: size.height * 0.95,
    );
    canvas.drawRect(
      pool,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.g1.withValues(alpha: 0.2),
          AppColors.g1.withValues(alpha: 0),
        ]).createShader(pool),
    );
    final light = Rect.fromCircle(
      center: head.translate(-10, 18 - rise),
      radius: size.height * 0.72,
    );
    canvas.drawRect(
      light,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.white.withValues(alpha: 0.95),
          AppColors.white.withValues(alpha: 0),
        ]).createShader(light),
    );

    canvas.translate(0, -rise);
    final outline = _deviceRenderer.outline(pose);
    canvas.drawPath(
      outline.shift(const Offset(12, 16)),
      Paint()
        ..color = const Color(0xFF17807D).withValues(alpha: 0.24)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
    );
  }

  @override
  bool shouldRepaint(_StagePainter old) =>
      old.rise != rise || old.centered != centered;
}

// ── The device ────────────────────────────────────────────────────

class _DevicePainter extends CustomPainter {
  _DevicePainter({
    required this.seconds,
    required this.still,
    required this.centered,
  }) : super(repaint: seconds);

  final ValueListenable<double> seconds;
  final bool still;
  final bool centered;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final clock = still ? 0.0 : seconds.value;
    final t = still ? HeroStory.restful : clock % HeroStory.loop;
    final flash = still ? 0.0 : HeroStory.flash(t);

    // A slow drift, enough to show it's solid and never to hide the lens.
    final sway = still ? 0.0 : math.sin(clock * 0.5);
    final yaw = _restYaw + 0.12 * sway;
    final pitch = _restPitch + (still ? 0.0 : 0.024 * math.sin(clock * 0.37));
    final bob = still ? 0.0 : 3 * math.sin(clock * 0.8);
    final pose =
        _heroPose(size, centered: centered, yaw: yaw, pitch: pitch, bob: bob);

    if (flash > 0) {
      final reach = pose.focal / _distance;
      final head = DeviceModel.front(DeviceModel.headY);
      _paintGlow(canvas, pose.project(head.center), reach * 32, flash);
    }

    _deviceRenderer.paint(canvas, pose);
    DeviceRenderer.paintParts(
      canvas,
      pose,
      lit: flash,
      shine: (yaw - _restYaw) / 0.12,
    );
  }

  /// Soft light thrown on the stage behind the head.
  void _paintGlow(Canvas canvas, Offset at, double radius, double flash) {
    final rect = Rect.fromCircle(center: at, radius: radius);
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.g1.withValues(alpha: 0.55 * flash),
          AppColors.g1.withValues(alpha: 0.16 * flash),
          AppColors.g1.withValues(alpha: 0),
        ], stops: const [
          0,
          0.55,
          1
        ]).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_DevicePainter old) =>
      old.seconds != seconds || old.still != still || old.centered != centered;
}

// ── The words beside it ───────────────────────────────────────────

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({
    required this.width,
    required this.source,
    required this.seconds,
    required this.still,
    required this.stacked,
  });

  final double width;
  final CaptureSource source;
  final ValueListenable<double> seconds;
  final bool still;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final (sourceIcon, sourceLabel) = switch (source) {
      CaptureSource.device || CaptureSource.phoneCamera => (
          Icons.wifi_rounded,
          'Wireless NIR device'
        ),
      CaptureSource.photoLibrary => (
          Icons.photo_library_outlined,
          'Your photos'
        ),
    };
    // The longest first, where the device leans furthest from the words.
    final facts = [
      _Fact(sourceIcon, sourceLabel),
      const _Fact(Icons.explore_outlined, 'Guided steps'),
      const _Fact(Icons.schedule_rounded, 'A few minutes'),
    ];

    return Column(
      mainAxisSize: stacked ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          // Always these two lines: a wider font, like the fallback shown
          // before Outfit loads, shrinks to fit instead of wrapping.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Nine photos,\none screening',
              softWrap: false,
              style: GoogleFonts.outfit(
                fontSize: (width * 0.086).clamp(25.0, 34.0),
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                height: 1.08,
                color: AppColors.navy,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ExcludeSemantics(
          child: RepaintBoundary(
            child: CustomPaint(
              size: const Size(_PhotoBarPainter.length, _PhotoBarPainter.thick),
              painter: _PhotoBarPainter(seconds: seconds, still: still),
            ),
          ),
        ),
        if (stacked) const SizedBox(height: 14) else const Spacer(),
        for (final fact in facts) ...[
          fact,
          if (fact != facts.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScanIconDisc(icon, size: 20, iconSize: 12),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.navy.withValues(alpha: 0.78),
            ),
          ),
        ),
      ],
    );
  }
}

/// Nine dashes, one filling with each flash of the device.
class _PhotoBarPainter extends CustomPainter {
  _PhotoBarPainter({required this.seconds, required this.still})
      : super(repaint: seconds);

  final ValueListenable<double> seconds;
  final bool still;

  static const double length = 150;
  static const double thick = 4;
  static const double _gap = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final t = still ? HeroStory.restful : seconds.value % HeroStory.loop;
    final dash =
        (size.width - _gap * (HeroStory.photos - 1)) / HeroStory.photos;
    final radius = Radius.circular(size.height / 2);
    final empty = Paint()..color = AppColors.g2.withValues(alpha: 0.18);
    for (var i = 0; i < HeroStory.photos; i++) {
      final x = i * (dash + _gap);
      final rect = Rect.fromLTWH(x, 0, dash, size.height);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), empty);
      final full = HeroStory.filled(i, t);
      if (full <= 0) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 0, dash * full, size.height),
          radius,
        ),
        Paint()
          ..shader = AppColors.primaryGradient
              .createShader(Offset.zero & Size(size.width, size.height)),
      );
    }
  }

  @override
  bool shouldRepaint(_PhotoBarPainter old) =>
      old.seconds != seconds || old.still != still;
}
