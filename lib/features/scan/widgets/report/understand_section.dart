import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../scan_motion.dart';
import 'report_style.dart';

/// How decay grows, one tooth at each stage. Tap a stage to read about it. The
/// check can't say which stage a sign is at, and the page says so.
class DecayStages extends StatefulWidget {
  const DecayStages({super.key});

  @override
  State<DecayStages> createState() => _DecayStagesState();
}

class _DecayStagesState extends State<DecayStages> {
  static const _stages = [
    (
      'Weak spot',
      'Enamel loses minerals and can look chalky white. At this stage it can '
          'often be reversed with fluoride and less sugar.',
    ),
    (
      'In the enamel',
      'A small hole starts in the hard outer layer. It usually doesn\'t hurt, '
          'so it\'s easy to miss. A dentist may watch it or fill it.',
    ),
    (
      'Into dentin',
      'Decay spreads faster in the softer layer below. Teeth can start to '
          'feel sensitive, and it usually needs a filling.',
    ),
    (
      'At the nerve',
      'Decay reaches the center of the tooth and can cause pain or infection. '
          'It may need a root canal or other treatment.',
    ),
  ];

  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final (name, text) = _stages[_selected];
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.lightLavender,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, stage) in _stages.indexed)
                Expanded(
                  child: _StageTile(
                    index: i,
                    name: stage.$1,
                    text: stage.$2,
                    selected: i == _selected,
                    onTap: () => setState(() => _selected = i),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: AnimatedSize(
              duration: ScanMotion.of(context, ScanMotion.medium),
              curve: ScanMotion.curve,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(child: Text(name, style: reportCardTitle)),
                  const SizedBox(height: 2),
                  ExcludeSemantics(child: Text(text, style: reportBody)),
                  const SizedBox(height: 8),
                  Text(
                    'This check can\'t tell which stage a sign is at. '
                    'A dentist can.',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageTile extends StatelessWidget {
  const _StageTile({
    required this.index,
    required this.name,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String name;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Stage ${index + 1}, $name. $text',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: ScanMotion.of(context, ScanMotion.fast),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: AppColors.white.withValues(alpha: selected ? 0.9 : 0),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: 44,
                  height: 58,
                  child: CustomPaint(painter: ToothStagePainter(index)),
                ),
                const SizedBox(height: 5),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    height: 1.15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.navy : AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tooth cut in half: enamel, dentin and the pulp in its middle, with decay
/// going further in at each stage.
class ToothStagePainter extends CustomPainter {
  const ToothStagePainter(this.stage);

  final int stage;

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
    canvas.scale(size.width / 44, size.height / 58);
    final tooth = _tooth();
    canvas.drawPath(tooth, Paint()..color = AppColors.white);
    canvas.drawPath(_dentin(), Paint()..color = AppColors.lavender);
    canvas.drawPath(_pulp(), Paint()..color = AppColors.cardSolid);
    canvas.drawPath(
      tooth,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.g2.withValues(alpha: 0.55),
    );

    final decay = Paint()..color = ReportColors.strong;
    switch (stage) {
      case 0:
        // A chalky patch on the surface, not yet a hole.
        canvas.drawOval(
          const Rect.fromLTWH(26, 2.6, 8, 3),
          Paint()..color = AppColors.secondaryText.withValues(alpha: 0.5),
        );
      case 1:
        canvas.drawPath(
          Path()
            ..moveTo(26, 3)
            ..lineTo(33, 3.2)
            ..lineTo(30, 8.2)
            ..lineTo(28, 8.2)
            ..close(),
          decay,
        );
      case 2:
        canvas.drawPath(
          Path()
            ..moveTo(25.5, 3)
            ..lineTo(33.5, 3.2)
            ..lineTo(31.5, 9.5)
            ..cubicTo(32.5, 12, 31, 15, 29, 15.5)
            ..cubicTo(27, 15, 25.5, 12, 26.5, 9.5)
            ..close(),
          decay,
        );
      default:
        canvas.drawPath(
          Path()
            ..moveTo(25, 3)
            ..lineTo(34, 3.2)
            ..lineTo(32, 10)
            ..cubicTo(33, 15, 30, 21, 26, 22)
            ..cubicTo(24, 20, 24, 14, 26, 10)
            ..close(),
          decay,
        );
    }
  }

  @override
  bool shouldRepaint(ToothStagePainter old) => old.stage != stage;
}

/// What the check reads today and what it doesn't, side by side, so a clear
/// result isn't taken for more than it is, then what can fool it. Worded from
/// what it really got wrong on photos dentists had looked at.
class WhatItReads extends StatelessWidget {
  const WhatItReads({super.key});

  @override
  Widget build(BuildContext context) {
    Widget column(String title, String body) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: reportCardTitle),
              const SizedBox(height: 3),
              Text(body, style: reportBody),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              column(
                'This check reads',
                'Visible signs of decay on the outer and chewing surfaces, from '
                    'your color photos.',
              ),
              VerticalDivider(width: 25, thickness: 1, color: ReportColors.rule),
              column(
                'It can\'t read yet',
                'Plaque, tartar, gums, inner sides, and decay hidden between '
                    'teeth.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Divider(height: 1, thickness: 1, color: ReportColors.rule),
        const SizedBox(height: 12),
        Text('What can look like decay', style: reportCardTitle),
        const SizedBox(height: 3),
        Text(
          'Stained grooves, white or brown mottling, old fillings and shadows '
          'can all look similar in a photo. A dentist can tell them apart.',
          style: reportBody,
        ),
        const SizedBox(height: 10),
        Text(
          'Tested on photos of 10 to 24 year olds that dentists marked, so '
          'results on your photos may differ.',
          style: reportNote,
        ),
      ],
    );
  }
}
