import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/scan_regions.dart';
import 'scan_motion.dart';
import 'scan_theme.dart';

/// One loop of the card, in seconds: a step plays its icon, light runs down the
/// line to the next one, and once all are charged they hold, then clear.
abstract class HowItWorksFlow {
  static const int steps = 4;
  static const double dwell = 1.7;
  static const double travel = 0.55;
  static const double hold = 1.5;
  static const double fade = 0.5;
  static const double loop = steps * dwell + (steps - 1) * travel + hold;

  /// A still picture for reduced motion: every step charged.
  static const double restful = startOfLast + dwell + 0.1;

  static const double startOfLast = (steps - 1) * (dwell + travel);

  static double startOf(int step) => step * (dwell + travel);

  /// How far step [step]'s icon has played, 0-1.
  static double played(int step, double s) =>
      ((s - startOf(step)) / dwell).clamp(0.0, 1.0);

  /// How far the light has run down the line below step [step], 0-1.
  static double run(int step, double s) =>
      ((s - startOf(step) - dwell) / travel).clamp(0.0, 1.0);

  /// Everything fading back before the next loop: 1 is fully charged, 0 clear.
  static double charge(double s) =>
      1 - ((s - (loop - fade)) / fade).clamp(0.0, 1.0);

  /// The step in play, or null once all of them have finished.
  static int? activeAt(double s) {
    for (var i = steps - 1; i >= 0; i--) {
      if (s >= startOf(i)) {
        return i == steps - 1 && s >= startOf(i) + dwell ? null : i;
      }
    }
    return null;
  }
}

enum _Glyph { connect, capture, analyze, act }

/// A scan in four words. Every step is always readable; the motion only adds to
/// them. Still under reduced motion.
class HowItWorksCard extends StatefulWidget {
  const HowItWorksCard({super.key});

  @override
  State<HowItWorksCard> createState() => _HowItWorksCardState();
}

class _HowItWorksCardState extends State<HowItWorksCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: (HowItWorksFlow.loop * 1000).round(),
    ),
  )..addListener(_syncActive);
  final _active = ValueNotifier<int?>(null);

  double get _seconds => _flow.value * HowItWorksFlow.loop;

  void _syncActive() => _active.value = HowItWorksFlow.activeAt(_seconds);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ScanMotion.reduced(context)) {
      _flow
        ..stop()
        ..value = HowItWorksFlow.restful / HowItWorksFlow.loop;
    } else if (!_flow.isAnimating) {
      _flow.repeat();
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    _active.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        _Glyph.connect,
        'Connect',
        'Switch it on and link it over Wi-Fi.',
      ),
      (
        _Glyph.capture,
        'Capture',
        'Follow the guide through ${scanRegions.length} views. Each capture '
            'takes a color photo and a NIR frame.',
      ),
      (
        _Glyph.analyze,
        'Analyze',
        'We check image quality, then a trained model looks for signs of '
            'tooth decay.',
      ),
      (
        _Glyph.act,
        'Act',
        'Get plain next steps for six areas of your mouth, saved to your '
            'history.',
      ),
    ];
    return GlassCard(
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      padding: const EdgeInsets.fromLTRB(16, 20, 18, 20),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _StepRow(
              index: i,
              glyph: steps[i].$1,
              title: steps[i].$2,
              body: steps[i].$3,
              flow: _flow,
              active: _active,
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.glyph,
    required this.title,
    required this.body,
    required this.flow,
    required this.active,
  });

  final int index;
  final _Glyph glyph;
  final String title;
  final String body;
  final Animation<double> flow;
  final ValueNotifier<int?> active;

  static const double _node = 46;

  bool get _last => index == HowItWorksFlow.steps - 1;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (!_last)
          Positioned(
            left: _node / 2 - 5,
            width: 10,
            top: _node + 3,
            bottom: 3,
            child: RepaintBoundary(
              child: CustomPaint(painter: _LinePainter(flow, index)),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: RepaintBoundary(
                child: SizedBox.square(
                  dimension: _node,
                  child: CustomPaint(painter: _NodePainter(flow, index, glyph)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 3, bottom: _last ? 0 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<int?>(
                      valueListenable: active,
                      builder: (context, current, _) =>
                          AnimatedDefaultTextStyle(
                        duration: ScanMotion.of(context, ScanMotion.medium),
                        curve: ScanMotion.curve,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          height: 1.2,
                          color: current == index
                              ? ScanColors.clearInk
                              : AppColors.navy,
                        ),
                        child: Text(title),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The line between two steps, charging as the light runs down it.
class _LinePainter extends CustomPainter {
  _LinePainter(this.flow, this.step) : super(repaint: flow);

  final Animation<double> flow;
  final int step;

  @override
  void paint(Canvas canvas, Size size) {
    final s = flow.value * HowItWorksFlow.loop;
    final run = Curves.easeInOut.transform(HowItWorksFlow.run(step, s));
    final charge = HowItWorksFlow.charge(s);
    final x = size.width / 2;
    final reach = size.height * run;

    Paint line(double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width;

    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      line(1.2)..color = AppColors.g2.withValues(alpha: 0.18),
    );
    if (reach <= 0 || charge <= 0) return;

    canvas.drawLine(
      Offset(x, 0),
      Offset(x, reach),
      line(2.2)
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.g2.withValues(alpha: charge),
            AppColors.g1.withValues(alpha: charge),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, math.max(reach, 1))),
    );
    if (run < 1) {
      final head = Offset(x, reach);
      canvas.drawCircle(
        head,
        5,
        Paint()..color = AppColors.g1.withValues(alpha: 0.35),
      );
      canvas.drawCircle(head, 2.6, Paint()..color = AppColors.g2);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.flow != flow || old.step != step;
}

/// A step's white disc and button-colored icon. The disc charges when the light
/// reaches it, and the icon plays once.
class _NodePainter extends CustomPainter {
  _NodePainter(this.flow, this.step, this.glyph) : super(repaint: flow);

  final Animation<double> flow;
  final int step;
  final _Glyph glyph;

  static final Path _tooth = Path()
    ..moveTo(7.5, 3.5)
    ..cubicTo(9.5, 3.5, 10.5, 4.6, 12, 4.6)
    ..cubicTo(13.5, 4.6, 14.5, 3.5, 16.5, 3.5)
    ..cubicTo(19.5, 3.5, 20.5, 6, 20.5, 8.5)
    ..cubicTo(20.5, 11, 19.5, 12.5, 19, 15)
    ..cubicTo(18.6, 17.2, 18, 20.5, 16.3, 20.5)
    ..cubicTo(14.6, 20.5, 14.6, 16.5, 12, 16.5)
    ..cubicTo(9.4, 16.5, 9.4, 20.5, 7.7, 20.5)
    ..cubicTo(6, 20.5, 5.4, 17.2, 5, 15)
    ..cubicTo(4.5, 12.5, 3.5, 11, 3.5, 8.5)
    ..cubicTo(3.5, 6, 4.5, 3.5, 7.5, 3.5)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final s = flow.value * HowItWorksFlow.loop;
    final played = HowItWorksFlow.played(step, s);
    final charge = HowItWorksFlow.charge(s);
    // Swells while it plays, and is back at rest before and after.
    final swell = math.sin(math.pi * played);
    final lit = (s >= HowItWorksFlow.startOf(step) ? 1.0 : 0.0) * charge;

    final c = size.center(Offset.zero);
    final radius = size.width / 2 - 2;

    if (swell > 0) {
      final glow = radius * 1.0 + 2;
      canvas.drawCircle(
        c,
        glow,
        Paint()..color = AppColors.g1.withValues(alpha: 0.32 * swell),
      );
    }

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1 + 0.05 * swell);

    canvas.drawCircle(Offset.zero, radius, Paint()..color = AppColors.white);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 + 0.6 * lit
        ..color = Color.lerp(
          AppColors.g2.withValues(alpha: 0.16),
          AppColors.primary,
          lit,
        )!,
    );

    canvas.translate(-12, -12);
    switch (glyph) {
      case _Glyph.connect:
        _connect(canvas, played, swell);
      case _Glyph.capture:
        _capture(canvas, played);
      case _Glyph.analyze:
        _analyze(canvas, played, swell);
      case _Glyph.act:
        _act(canvas, played);
    }
    canvas.restore();
  }

  static Paint _ink([double alpha = 1]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = AppColors.primary.withValues(alpha: alpha);

  /// Wi-Fi arcs, a signal rippling outward through them.
  void _connect(Canvas canvas, double p, double swell) {
    const at = Offset(12, 18.6);
    canvas.drawCircle(at, 1.5, Paint()..color = AppColors.primary);
    const radii = [5.2, 9.6, 14.0];
    for (var k = 0; k < radii.length; k++) {
      final ripple = 0.5 + 0.5 * math.sin(2 * math.pi * (p * 2 - k / 3));
      final alpha = 1 - swell * (1 - (0.2 + 0.8 * ripple));
      canvas.drawArc(
        Rect.fromCircle(center: at, radius: radii[k]),
        -math.pi * 0.77,
        math.pi * 0.54,
        false,
        _ink(alpha),
      );
    }
  }

  /// A lens in a frame: a bright flash for the color photo, then an unseen ring
  /// for the NIR frame.
  void _capture(Canvas canvas, double p) {
    final frame = _ink();
    const a = 3.5, b = 20.5, arm = 4.0;
    for (final (x, y, dx, dy) in const [
      (a, a, 1.0, 1.0),
      (b, a, -1.0, 1.0),
      (a, b, 1.0, -1.0),
      (b, b, -1.0, -1.0),
    ]) {
      canvas.drawLine(Offset(x, y), Offset(x + dx * arm, y), frame);
      canvas.drawLine(Offset(x, y), Offset(x, y + dy * arm), frame);
    }
    const c = Offset(12, 12);
    final photo = ((p - 0.12) / 0.3).clamp(0.0, 1.0);
    if (photo > 0 && photo < 1) {
      canvas.drawCircle(
        c,
        4 + 5 * photo,
        Paint()..color = AppColors.g1.withValues(alpha: 0.7 * (1 - photo)),
      );
    }
    final nir = ((p - 0.52) / 0.32).clamp(0.0, 1.0);
    if (nir > 0 && nir < 1) {
      canvas.drawCircle(c, 4 + 6 * nir, _ink(1 - nir));
    }
    canvas.drawCircle(c, 3.8, _ink());
  }

  /// A tooth, filling as a line passes down it and back.
  void _analyze(Canvas canvas, double p, double swell) {
    final y = 3 + 18 * (0.5 - 0.5 * math.cos(2 * math.pi * p));
    if (swell > 0) {
      canvas.save();
      canvas.clipPath(_tooth);
      canvas.drawRect(
        Rect.fromLTRB(0, 0, 24, y),
        Paint()..color = AppColors.g1.withValues(alpha: 0.55 * swell),
      );
      canvas.restore();
    }
    canvas.drawPath(_tooth, _ink());
    if (swell > 0) {
      canvas.drawLine(Offset(1.5, y), Offset(22.5, y), _ink(swell));
    }
  }

  /// Lines of plain words writing themselves.
  void _act(Canvas canvas, double p) {
    const lines = [(4.5, 7.0, 19.5), (4.5, 12.0, 19.5), (4.5, 17.0, 13.5)];
    final writing = p > 0 && p < 1;
    for (var k = 0; k < lines.length; k++) {
      final (from, y, to) = lines[k];
      if (!writing) {
        canvas.drawLine(Offset(from, y), Offset(to, y), _ink());
        continue;
      }
      canvas.drawLine(Offset(from, y), Offset(to, y), _ink(0.22));
      final f =
          Curves.easeOut.transform(((p - k * 0.2) / 0.45).clamp(0.0, 1.0));
      if (f > 0) {
        canvas.drawLine(
          Offset(from, y),
          Offset(from + (to - from) * f, y),
          _ink(),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_NodePainter old) =>
      old.flow != flow || old.step != step || old.glyph != glyph;
}
