import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../scan_motion.dart';
import 'report_motion.dart';
import 'report_style.dart';

/// One tooth, cut in half, with decay growing through it. It plays through the
/// stages once when it comes into view; tap a stage to go back to it. The check
/// can't say which stage a sign is at, and the card says so.
class DecayStages extends StatefulWidget {
  const DecayStages({super.key});

  @override
  State<DecayStages> createState() => _DecayStagesState();
}

class _DecayStagesState extends State<DecayStages>
    with SingleTickerProviderStateMixin {
  static const _stages = [
    (
      'Weak spot',
      'Enamel loses minerals and can look chalky white. It can often be '
          'reversed with fluoride and less sugar.',
    ),
    (
      'In the enamel',
      'A small hole starts in the hard outer layer. It usually doesn\'t hurt, '
          'so it\'s easy to miss.',
    ),
    (
      'Into dentin',
      'Decay spreads faster in the softer layer below. Teeth can start to feel '
          'sensitive, and it usually needs a filling.',
    ),
    (
      'At the nerve',
      'Decay reaches the center of the tooth and can cause pain or infection. '
          'It may need a root canal.',
    ),
  ];

  late final AnimationController _c = AnimationController(
    vsync: this,
    upperBound: (_stages.length - 1).toDouble(),
    duration: const Duration(milliseconds: 5200),
  );
  bool _touched = false;

  int get _stage => _c.value.round().clamp(0, _stages.length - 1);

  void _go(int stage) {
    _touched = true;
    _c.animateTo(
      stage.toDouble(),
      duration: ScanMotion.of(context, const Duration(milliseconds: 500)),
      curve: ScanMotion.curve,
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      width: double.infinity,
      tint: AppColors.lightLavender,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: InViewAnimation(
        duration: const Duration(milliseconds: 1),
        builder: (context, t) {
          if (t >= 1 &&
              !_touched &&
              !_c.isAnimating &&
              _c.value == 0 &&
              !ScanMotion.reduced(context)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_touched) _c.forward();
            });
          }
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final (name, text) = _stages[_stage];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 84,
                        height: 108,
                        child: ExcludeSemantics(
                          child: CustomPaint(
                            painter: ToothStagePainter(_c.value),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ExcludeSemantics(
                              child: Text(name, style: reportCardTitle),
                            ),
                            const SizedBox(height: 3),
                            ExcludeSemantics(
                              child: Text(text, style: reportBody),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final (i, stage) in _stages.indexed) ...[
                        if (i > 0) const SizedBox(width: 4),
                        Expanded(
                          child: _StageStep(
                            label: stage.$1,
                            description: stage.$2,
                            index: i,
                            fill: (_c.value + 1 - i).clamp(0.0, 1.0),
                            selected: i == _stage,
                            onTap: () => _go(i),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _StageStep extends StatelessWidget {
  const _StageStep({
    required this.label,
    required this.description,
    required this.index,
    required this.fill,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final int index;
  final double fill;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Stage ${index + 1}, $label. $description',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: AppColors.g2.withValues(alpha: 0.14)),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: fill,
                        child: const ColoredBox(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  height: 1.15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.navy : AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tooth cut in half: enamel, dentin and the pulp in its middle. [stage] runs
/// from 0 to 3, with decay growing smoothly in from the surface.
class ToothStagePainter extends CustomPainter {
  const ToothStagePainter(this.stage);

  final double stage;

  /// The whole tooth in a 44 by 58 box: a crown with two cusps, two roots.
  static Path _tooth() => Path()
    ..moveTo(9, 3)
    ..cubicTo(14, 0.5, 18, 2, 22, 4.5)
    ..cubicTo(26, 2, 30, 0.5, 35, 3)
    ..cubicTo(41, 6, 42, 15, 39, 24)
    ..cubicTo(37.5, 31, 37, 43, 33, 54)
    ..cubicTo(32, 57, 29, 57, 28.5, 54)
    ..cubicTo(27.5, 47, 26.5, 41, 22, 40)
    ..cubicTo(17.5, 41, 16.5, 47, 15.5, 54)
    ..cubicTo(15, 57, 12, 57, 11, 54)
    ..cubicTo(7, 43, 6.5, 31, 5, 24)
    ..cubicTo(2, 15, 3, 6, 9, 3)
    ..close();

  /// Everything under the enamel.
  static Path _dentin() => Path()
    ..moveTo(11, 9)
    ..cubicTo(15, 7, 18, 8, 22, 10)
    ..cubicTo(26, 8, 29, 7, 33, 9)
    ..cubicTo(36.5, 11, 36.5, 17, 34.5, 24)
    ..cubicTo(33, 31, 32.5, 42, 30.5, 49)
    ..cubicTo(29.5, 45, 28, 38, 22, 37)
    ..cubicTo(16, 38, 14.5, 45, 13.5, 49)
    ..cubicTo(11.5, 42, 11, 31, 9.5, 24)
    ..cubicTo(7.5, 17, 7.5, 11, 11, 9)
    ..close();

  static Path _pulp() => Path()
    ..moveTo(16, 19)
    ..cubicTo(19, 17, 25, 17, 28, 19)
    ..cubicTo(29.5, 23, 29, 29, 27.5, 33)
    ..cubicTo(26, 31.5, 24, 31, 22, 31)
    ..cubicTo(20, 31, 18, 31.5, 16.5, 33)
    ..cubicTo(15, 29, 14.5, 23, 16, 19)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 44, size.height / 58);
    canvas.translate((size.width - 44 * s) / 2, (size.height - 58 * s) / 2);
    canvas.scale(s);
    final tooth = _tooth();
    canvas.drawPath(tooth, Paint()..color = AppColors.white);
    canvas.drawPath(_dentin(), Paint()..color = AppColors.lavender);
    canvas.drawPath(_pulp(), Paint()..color = AppColors.cardSolid);

    // At first a chalky patch on the surface, fading as the hole takes over.
    final chalk = (1 - stage).clamp(0.0, 1.0);
    if (chalk > 0) {
      canvas.drawOval(
        const Rect.fromLTWH(25.5, 2.4, 9, 3.4),
        Paint()
          ..color = AppColors.secondaryText.withValues(alpha: 0.42 * chalk),
      );
    }
    // Then a hole, deeper and wider with each stage: into enamel by 1, well
    // into dentin by 2, reaching the pulp by 3.
    final grow = stage.clamp(0.0, 3.0);
    if (grow > 0.05) {
      final depth = 3 + grow * 5.6;
      final half = 1.4 + math.min(grow, 2) * 1.7;
      const cx = 29.5, top = 2.6;
      final bulge = grow > 1 ? (grow - 1) * 1.3 : 0.0;
      canvas.drawPath(
        Path()
          ..moveTo(cx - half, top)
          ..lineTo(cx + half, top + 0.2)
          ..cubicTo(
            cx + half - 0.6 + bulge,
            top + depth * 0.5,
            cx + 1.2 + bulge,
            top + depth * 0.9,
            cx - 1.2,
            top + depth,
          )
          ..cubicTo(
            cx - 2.6 - bulge,
            top + depth * 0.85,
            cx - half + 0.4 - bulge,
            top + depth * 0.45,
            cx - half,
            top,
          )
          ..close(),
        Paint()..color = ReportColors.strong,
      );
    }
    canvas.drawPath(
      tooth,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = AppColors.g2.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(ToothStagePainter old) => old.stage != stage;
}

/// What a result can speak to and what it can't, against a tooth with the
/// surfaces it reads filled in. Nothing here is a score: when a new class is
/// added to the model, move it up a row.
class WhatItReads extends StatelessWidget {
  const WhatItReads({super.key});

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    const rows = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ScopeRow(
          fill: _ScopeFill.solid,
          title: 'Reads',
          text: 'Visible signs of decay on chewing and outer surfaces.',
        ),
        SizedBox(height: 11),
        _ScopeRow(
          fill: _ScopeFill.half,
          title: 'Often misses',
          text: 'Small or early cavities, and decay between teeth or at the '
              'gumline.',
        ),
        SizedBox(height: 11),
        _ScopeRow(
          fill: _ScopeFill.hollow,
          title: 'Can\'t read yet',
          text: 'Plaque, tartar, gums and inner sides.',
        ),
      ],
    );
    return GlassCard(
      width: double.infinity,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            const tooth = ExcludeSemantics(
              child: SizedBox(
                width: 76,
                height: 100,
                child: CustomPaint(painter: _ScopeToothPainter()),
              ),
            );
            if (constraints.maxWidth / scale < 250) return rows;
            return const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tooth,
                SizedBox(width: 14),
                Expanded(child: rows),
              ],
            );
          }),
          const SizedBox(height: 13),
          Divider(height: 1, thickness: 1, color: ReportColors.rule),
          const SizedBox(height: 11),
          const _ScopeNote(
            title: 'Can look like decay',
            text: 'Stained grooves, old fillings and shadows.',
          ),
          const SizedBox(height: 7),
          const _ScopeNote(
            title: 'Confidence',
            text: 'How sure the model is, not how bad a spot is.',
          ),
        ],
      ),
    );
  }
}

enum _ScopeFill { solid, half, hollow }

class _ScopeRow extends StatelessWidget {
  const _ScopeRow({
    required this.fill,
    required this.title,
    required this.text,
  });

  final _ScopeFill fill;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: ExcludeSemantics(
            child: SizedBox.square(
              dimension: 12,
              child: CustomPaint(painter: _ScopeFillPainter(fill)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: reportCardTitle),
              const SizedBox(height: 1),
              Text(text, style: reportBody),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScopeFillPainter extends CustomPainter {
  const _ScopeFillPainter(this.fill);

  final _ScopeFill fill;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    canvas.drawCircle(center, r, Paint()..color = AppColors.white);
    if (fill == _ScopeFill.solid) {
      canvas.drawCircle(center, r, Paint()..color = ReportColors.possible);
    } else if (fill == _ScopeFill.half) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        math.pi / 2,
        math.pi,
        true,
        Paint()..color = ReportColors.possible,
      );
    }
    canvas.drawCircle(
      center,
      r - 0.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = fill == _ScopeFill.hollow
            ? ReportColors.hollowEdge
            : ReportColors.possible,
    );
  }

  @override
  bool shouldRepaint(_ScopeFillPainter old) => old.fill != fill;
}

class _ScopeNote extends StatelessWidget {
  const _ScopeNote({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: reportNote,
        children: [
          TextSpan(
            text: '$title  ',
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          TextSpan(text: text),
        ],
      ),
    );
  }
}

/// The same cut-away tooth as the decay stages, with what the check reads shown
/// on it: the chewing surface and the outer side in teal, while the inner side,
/// the gumline and the root stay pale.
class _ScopeToothPainter extends CustomPainter {
  const _ScopeToothPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 44, size.height / 58);
    canvas.translate((size.width - 44 * s) / 2, (size.height - 58 * s) / 2);
    canvas.scale(s);
    final tooth = ToothStagePainter._tooth();
    canvas.drawPath(tooth, Paint()..color = AppColors.white);
    canvas.save();
    canvas.clipPath(tooth);
    // The chewing surface, then down the outer side as far as the gumline.
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 44, 8.5),
      Paint()..color = ReportColors.possible,
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 8.5, 11, 15.5),
      Paint()..color = ReportColors.possible,
    );
    // Where gum meets tooth.
    canvas.drawRect(
      const Rect.fromLTWH(0, 24, 44, 5),
      Paint()..color = AppColors.lavender.withValues(alpha: 0.9),
    );
    canvas.restore();
    canvas.drawPath(
      ToothStagePainter._dentin(),
      Paint()..color = AppColors.lightLavender,
    );
    canvas.drawPath(
      tooth,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = AppColors.g2.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_ScopeToothPainter old) => false;
}
